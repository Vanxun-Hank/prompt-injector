#!/usr/bin/env python3
"""Run targeted regression tiers or full macOS acceptance."""
import argparse
import datetime
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Keep broad integration paths in merge while retaining their short regressions in fast.
MERGE_ONLY = (
    'ExperienceTests/testSelectionConfirmationAndPartialSaveStaySeparateForOneFiveAndTwenty',
    'ManagementV7Tests/testUnifiedWorkbenchGeneratesEditsAndPartiallySavesFive',
    'ManagementTests/testMainActorTerminationExitsAfterPendingUsageIsCommitted',
)

REQUIRED_BEHAVIOR = {
    'toggle/visible-hides', 'motion/interrupted-show-remains-visible',
    'copy/actual-pasteboard', 'minimum/plain-return-does-not-insert',
    'page-motion/rapid-navigation-preserves-state',
    'keyboard/command-return-routes-current-prompt', 'keyboard/detail-return-does-not-route-insertion',
    'management/save-failure-keeps-input', 'management/reopen-preserves-fields-and-id',
    'management/cancel-restores-local-draft', 'management/edit-stable-id-without-duplicate',
    'statistics/explicit-success-events-only', 'assets/all-figma-assets-load',
    'management/separate-native-window', 'management/required-fields', 'management/return-edits-does-not-save',
    'management/minimum-detail-loads',
    'statistics/all-columns-fit', 'management/native-window-controls',
    'management/native-close-hides', 'management/native-minimize', 'management/native-zoom',
    'management/native-fullscreen-space', 'management/native-fullscreen-exit',
    'management/regular-application', 'application/branded-icon', 'application/transparent-icon-canvas',
    'keyboard/blocked-command-return-no-route', 'keyboard/recovered-command-return-routes',
    'generation/candidate-is-editable', 'generation/candidate-does-not-overwrite', 'generation/adoption-preserves-original-source',
    'categories/new-name-entire-control-visible', 'categories/sixth-sidebar-preview', 'categories/sixth-launcher-list', 'categories/sixth-launcher-full-prompt', 'categories/sixth-statistics',
    'reading/prompt-only-verbatim', 'reading/original-source-verbatim', 'reading/explanation-only', 'categories/growing-sidebar-scroll',
    'experience/identified-exact-original', 'experience/checkbox-does-not-discuss', 'experience/selection-preserves-prompt-without-chat',
    'experience/reopen-independent-prompts', 'experience/batch-saved-with-sixth-category',
    'experience/saved-immediately-loads-in-launcher', 'experience/deleted-entry-no-longer-loads',
    'experience/empty-prompt-blocks-review', 'experience/manual-paste-skips-generation', 'experience/manual-pair-fit', 'experience/audit-list-stashes-edits', 'experience/audit-list-restores-edits', 'experience/audit-fields-fit-minimum',
    'categories/blank-name-stays-inline', 'management/delete-default-is-cancel', 'experience/confirm-action-visible',
    'v7/grid-default-and-three-columns', 'v7/grid-minimum-two-columns', 'v7/edit-stays-in-preview', 'v7/inline-minimum-fields-fit',
    'v7/unified-workbench', 'v7/all-saved-without-resurrected-input', 'v7/saved-card-immediately-available',
    'v7/partial-save-1', 'v7/partial-save-5', 'v7/partial-save-20', 'v7/completed-one', 'v7/remaining-draft-5', 'v7/remaining-draft-20',
    'v7/input-validation-near-field', 'v7/input-mode-retains-prompt',
    'management/icon-copy-feedback', 'management/copy-all-reading-tabs', 'management/icon-actions-keyboard-focus',
    'management/direct-actions-search', 'management/direct-actions-category',
    'workbench/compact-completion', 'workbench/add-keeps-list-and-focus', 'workbench/view-existing-while-adding',
    'workbench/append-source-visible', 'workbench/context-remove-keeps-current', 'workbench/edited-removal-cancel-keeps-draft',
    'workbench/removal-selects-adjacent', 'workbench/remove-last-empties-detail', 'workbench/continue-from-empty', 'workbench/continue-after-save',
    'workbench/removed-clears-old-save-count',
    'workbench/reopen-pending-addition', 'workbench/reopened-partial-save-keeps-sources',
}

REQUIRED_CAPTURES = {'capture/' + name for name in (
    'minimum-categories', 'minimum-list', 'minimum-detail',
    'default-categories', 'default-shell', 'default-list',
    'default-detail', 'large-categories', 'large-list',
    'large-detail', 'minimum-long-content', 'minimum-permission-error',
    'minimum-target-error', 'management-library', 'management-delete-confirmation',
    'management-comparison', 'management-editor', 'management-original',
    'management-save-error', 'management-reading-original', 'management-reading-explanation',
    'management-inline-editor', 'management-inline-minimum', 'management-statistics',
    'management-grid-minimum', 'management-minimum', 'management-candidate',
    'management-category-create', 'management-new-category', 'management-sixth-statistics',
    'management-categories-scroll', 'experience-new', 'experience-input-error',
    'experience-organize', 'experience-minimum', 'experience-review',
    'experience-review-minimum', 'experience-original', 'workbench-complete',
    'experience-manual', 'experience-manual-minimum', 'workbench-addition-minimum',
    'v7-partial-1', 'v7-partial-5', 'v7-partial-20',
)}


def validate_ui_report(report, build, ui, *, captures):
    checks = report.get('checks', [])
    names = {c.get('name') for c in checks}
    captured = {name for name in names if isinstance(name, str) and name.startswith('capture/')}
    if (report.get('passed') is not True or report.get('capturesEnabled') is not captures
            or not report.get('sessionID')
            or any(report.get(key) != build[key] for key in ('buildID', 'sourceFingerprint'))
            or len(names) != len(checks) or not REQUIRED_BEHAVIOR <= names
            or any(not c.get('name') or c.get('passed') is not True for c in checks)
            or captured != (REQUIRED_CAPTURES if captures else set())):
        return False
    for name in captured:
        png = ui / (name.split('/', 1)[1] + '.png')
        if not png.is_file():
            return False
        with png.open('rb') as file:
            header = file.read(33)
            if len(header) != 33 or header[:16] != b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR':
                return False
            file.seek(-12, os.SEEK_END)
            if file.read() != b'\x00\x00\x00\x00IEND\xaeB\x60\x82':
                return False
    return True


def parse_tier(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--tier', choices=('fast', 'merge', 'desktop', 'visual'),
                      help='Without a tier, run merge plus native behavior and screenshots')
    mode.add_argument('--headless', action='store_true', help='Alias for merge; partial acceptance')
    args = parser.parse_args(argv)
    return 'merge' if args.headless else (args.tier or 'full')


def main():
    tier = parse_tier()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output = ROOT / 'artifacts/tests' / stamp
    output.mkdir(parents=True)
    scope = {'fast': 'fast-partial', 'merge': 'headless-partial', 'desktop': 'native-behavior',
             'visual': 'native-visual', 'full': 'native-ui-full'}
    result = {'startedAt': stamp, 'tier': tier, 'scope': scope[tier], 'steps': [], 'passed': False}
    started = time.monotonic()

    def save():
        (output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')

    def run(name, command, *, timeout=180, env=None, check=True):
        print(f'Running {name}…', flush=True)
        step_start = time.monotonic()
        log_path = output / f'{name}.log'
        with log_path.open('w') as log:
            completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, env=env)
        result['steps'].append({'name': name, 'exitCode': completed.returncode,
                                'elapsedSeconds': round(time.monotonic() - step_start, 3)})
        save()
        if check and completed.returncode:
            raise RuntimeError(f'{name} failed; see {log_path}')
        return completed.returncode

    try:
        if tier in ('fast', 'merge', 'full'):
            command = ['swift', 'test']
            if tier == 'fast':
                command += ['--skip', '(?:' + '|'.join(MERGE_ONLY) + ')$']
            run('swift', command)
            swift_log = (output / 'swift.log').read_text()
            build_time = re.search(r'Build complete! \(([\d.]+)s\)', swift_log)
            tests = re.findall(r'Executed (\d+) tests?, with (\d+) failures? .* in ([\d.]+) \(', swift_log)
            if not tests or int(tests[-1][0]) == 0:
                raise RuntimeError('Swift tests did not report executed XCTest cases')
            count, failures, seconds = tests[-1]
            result['swiftTests'] = {'count': int(count), 'failures': int(failures), 'seconds': float(seconds)}
            if build_time:
                result['swiftBuildSeconds'] = float(build_time[1])
            run('python', [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts/tests'])
        if tier in ('desktop', 'visual', 'full'):
            state = subprocess.check_output(['ioreg', '-n', 'Root', '-d', '1'], text=True)
            if '"CGSSessionScreenIsLocked"=Yes' in state:
                raise RuntimeError('Desktop locked: unlock before native checks; no UI pass recorded.')
            env = os.environ.copy()
            build_dir = output / 'build'
            app = Path(env.setdefault('PROMPT_INJECTOR_APP_OUTPUT', str(build_dir / 'Prompt Injector.app')))
            installed = Path.home() / 'Library/Application Support/Prompt Injector/Build/Prompt Injector.app'
            if app.resolve() in {installed.resolve(), Path('/Applications/Prompt Injector.app').resolve()}:
                raise RuntimeError('Native tests require an isolated app output')
            env['PROMPT_INJECTOR_BUILD_DIR'] = str(build_dir)
            run('build', ['bash', 'scripts/build-app.sh'], env=env)
            build = json.loads((build_dir / 'build-info.json').read_text())
            info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
            if info['PIBuildID'] != build['buildID'] or info['PISourceFingerprint'] != build['sourceFingerprint']:
                raise RuntimeError('Packaged build identity mismatch')
            result['build'] = build
            ui = output / 'ui'
            captures = tier != 'desktop'
            command = [str(app / 'Contents/MacOS/PromptInjector'), '--verify-ui', '--qa-output', str(ui)]
            if not captures:
                command.append('--qa-no-captures')
            exit_code = run('native-ui', command, timeout=120, check=False)
            report = json.loads((ui / 'report.json').read_text())
            result['nativeChecks'] = len(report['checks'])
            result['uiSessionID'] = report['sessionID']
            result['captureAttempts'] = {c['name']: c.get('attempts', 1) for c in report['checks']
                                         if c['name'].startswith('capture/')}
            result['failedNativeChecks'] = [c['name'] for c in report['checks'] if c.get('passed') is not True]
            if exit_code or not validate_ui_report(report, build, ui, captures=captures):
                raise RuntimeError('Native checks failed or report is incomplete/stale')
            if captures:
                # Keep the latest complete visual evidence separate from desktop-only runs.
                (ROOT / 'artifacts/ui').mkdir(parents=True, exist_ok=True)
                for path in ui.iterdir():
                    if path.suffix in {'.png', '.json'}:
                        shutil.copy2(path, ROOT / 'artifacts/ui' / path.name)
        result['passed'] = True
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        result['error'] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        result['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result['elapsedSeconds'] = round(time.monotonic() - started, 3)
        save()
        print(f'Report: {output / "summary.json"}', flush=True)
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
