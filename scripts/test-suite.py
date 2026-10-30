#!/usr/bin/env python3
"""Stage 1–2 regression suite. Full native UI run by default; --headless is explicitly partial."""
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
                'management/save-succeeds-once', 'management/new-detail-exact-fields',
                'management/reopened-database-exact-fields', 'management/copy-exact-prompt',
                'management/return-edits-does-not-save', 'management/new-prompt-routes-exactly'}
    captures = [c for c in checks if str(c.get('name', '')).startswith('capture/')]
    return (report.get('passed') is True and len(checks) >= 82 and len(captures) == 15
            and required <= names and all(c.get('passed') is True for c in checks))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true', help='Only Swift and Python tests; not full acceptance')
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output = ROOT / 'artifacts/tests' / stamp
    output.mkdir(parents=True)
    result = {'startedAt':stamp, 'scope':'headless-partial' if args.headless else 'stage1-stage2-full', 'steps':[], 'passed':False}
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
