#!/usr/bin/env python3
"""Launcher and management regression suite; --headless is explicitly partial."""
import argparse
import datetime
import json
import os
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def validate_ui_report(report):
    checks = report.get('checks', [])
    names = {c.get('name') for c in checks}
    required = {'toggle/visible-hides', 'motion/interrupted-show-remains-visible',
                'copy/actual-pasteboard', 'minimum/plain-return-does-not-insert',
                'page-motion/rapid-navigation-preserves-state',
                'keyboard/command-return-routes-current-prompt', 'keyboard/detail-return-does-not-route-insertion',
                'management/save-failure-keeps-input', 'management/reopen-preserves-fields-and-id',
                'management/cancel-restores-local-draft', 'management/edit-stable-id-without-duplicate',
                'statistics/explicit-success-events-only', 'assets/all-figma-assets-load',
                'management/separate-native-window', 'management/required-fields', 'management/return-edits-does-not-save',
                'statistics/all-columns-fit', 'management/native-window-controls',
                'management/native-close-hides', 'management/native-minimize', 'management/native-zoom',
                'management/native-fullscreen-space', 'management/native-fullscreen-exit',
                'management/regular-application', 'application/branded-icon', 'application/transparent-icon-canvas',
                'keyboard/blocked-command-return-no-route', 'keyboard/recovered-command-return-routes',
                'capture/management-library', 'capture/management-editor', 'capture/management-original',
                'capture/management-save-error', 'capture/management-statistics', 'capture/management-minimum',
                'generation/candidate-is-editable', 'generation/candidate-does-not-overwrite', 'generation/adoption-preserves-original-source',
                'categories/new-name-entire-control-visible', 'categories/sixth-sidebar-preview', 'categories/sixth-launcher-list', 'categories/sixth-launcher-full-prompt', 'categories/sixth-statistics',
                'reading/prompt-only-verbatim', 'reading/original-source-verbatim', 'reading/explanation-only', 'categories/growing-sidebar-scroll',
                'capture/management-reading-original', 'capture/management-reading-explanation', 'capture/management-categories-scroll',
                'experience/identified-exact-original', 'experience/checkbox-does-not-discuss', 'experience/selection-preserves-prompt-without-chat',
                'experience/reopen-independent-prompts', 'experience/batch-saved-with-sixth-category',
                'experience/saved-immediately-loads-in-launcher', 'experience/deleted-entry-no-longer-loads',
                'experience/empty-prompt-blocks-review', 'experience/manual-paste-skips-generation', 'experience/manual-pair-fit', 'experience/audit-list-stashes-edits', 'experience/audit-list-restores-edits', 'experience/audit-fields-fit-minimum',
                'capture/experience-review-minimum', 'capture/experience-new', 'capture/experience-manual', 'capture/experience-manual-minimum', 'capture/experience-organize', 'capture/experience-minimum', 'capture/experience-review', 'capture/experience-original',
                'capture/management-candidate', 'capture/management-new-category', 'capture/management-sixth-statistics',
                'capture/management-delete-confirmation', 'capture/management-comparison', 'capture/management-category-create',
                'categories/blank-name-stays-inline', 'management/delete-default-is-cancel', 'experience/confirm-action-visible',
                'v7/grid-default-and-three-columns', 'v7/grid-minimum-two-columns', 'v7/edit-stays-in-preview', 'v7/inline-minimum-fields-fit',
                'v7/unified-workbench', 'v7/all-saved-without-resurrected-input', 'v7/saved-card-immediately-available',
                'v7/partial-save-1', 'v7/partial-save-5', 'v7/partial-save-20', 'v7/completed-one', 'v7/remaining-draft-5', 'v7/remaining-draft-20',
                'capture/management-inline-editor', 'capture/management-inline-minimum', 'capture/management-grid-minimum',
                'capture/v7-partial-1', 'capture/v7-partial-5', 'capture/v7-partial-20',
                'v7/input-validation-near-field', 'v7/input-mode-retains-prompt', 'capture/experience-input-error',
                'management/icon-copy-feedback', 'management/copy-all-reading-tabs', 'management/icon-actions-keyboard-focus',
                'management/direct-actions-search', 'management/direct-actions-category',
                'workbench/compact-completion', 'workbench/add-keeps-list-and-focus', 'workbench/view-existing-while-adding',
                'workbench/append-source-visible', 'workbench/context-remove-keeps-current', 'workbench/edited-removal-cancel-keeps-draft',
                'workbench/removal-selects-adjacent', 'workbench/remove-last-empties-detail', 'workbench/continue-from-empty', 'workbench/continue-after-save',
                'workbench/removed-clears-old-save-count', 'capture/workbench-complete', 'capture/workbench-addition-minimum'}
    captures = [c for c in checks if str(c.get('name', '')).startswith('capture/')]
    return (report.get('passed') is True and len(checks) >= 85 and len(captures) == 45
            and required <= names and all(c.get('passed') is True for c in checks))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true', help='Only Swift and Python tests; not full acceptance')
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output = ROOT / 'artifacts/tests' / stamp
    output.mkdir(parents=True)
    result = {'startedAt':stamp, 'scope':'headless-partial' if args.headless else 'native-ui-full', 'steps':[], 'passed':False}
    def save():
        (output/'summary.json').write_text(json.dumps(result, indent=2)+'\n')
    def run(name, command, timeout=180):
        print(f'Running {name}…', flush=True)
        with (output/f'{name}.log').open('w') as log:
            completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        result['steps'].append({'name':name, 'exitCode':completed.returncode})
        save()
        if completed.returncode:
            raise RuntimeError(f'{name} failed; see {output/name}.log')
    try:
        run('swift', ['swift','test'])
        run('python', [sys.executable,'-m','unittest','discover','-s','scripts/tests'])
        if not args.headless:
            state = subprocess.check_output(['ioreg','-n','Root','-d','1'], text=True)
            if '"CGSSessionScreenIsLocked"=Yes' in state:
                raise RuntimeError('Desktop locked: unlock before native checks; no UI pass recorded.')
            run('build', ['bash','scripts/build-app.sh'])
            app = Path(os.environ.get('PROMPT_INJECTOR_APP_OUTPUT', str(Path.home()/'Library/Application Support/Prompt Injector/Build/Prompt Injector.app')))
            build = json.loads((ROOT/'build/build-info.json').read_text())
            info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
            if info['PIBuildID'] != build['buildID'] or info['PISourceFingerprint'] != build['sourceFingerprint']:
                raise RuntimeError('Packaged build identity mismatch')
            result['build'] = build
            ui = output/'ui'
            run('native-ui', [str(app/'Contents/MacOS/PromptInjector'),'--verify-ui','--qa-output',str(ui)], timeout=120)
            report = json.loads((ui/'report.json').read_text())
            if not validate_ui_report(report) or report.get('buildID') != build['buildID'] or report.get('sourceFingerprint') != build['sourceFingerprint']:
                raise RuntimeError('Native checks failed or report is incomplete/stale')
            for check in report['checks']:
                if check['name'].startswith('capture/'):
                    png = ui/(check['name'].split('/',1)[1]+'.png')
                    if not png.is_file() or png.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
                        raise RuntimeError('Capture file missing/invalid')
            result['nativeChecks'] = len(report['checks'])
            result['uiSessionID'] = report['sessionID']
            # Preserve per-run evidence; update the familiar UI directory only after all checks pass.
            (ROOT/'artifacts/ui').mkdir(parents=True, exist_ok=True)
            for path in ui.iterdir():
                if path.suffix in {'.png','.json'}: shutil.copy2(path, ROOT/'artifacts/ui'/path.name)
        result['passed'] = True
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        result['error'] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        result['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()
        print(f'Report: {output / "summary.json"}', flush=True)
    return 0 if result['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
