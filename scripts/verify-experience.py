#!/usr/bin/env python3
"""Verify the experience workflow in isolated data; live API calls require --live-api."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true', help='Partial: skip native windows and screenshots')
    parser.add_argument('--live-api', action='store_true', help='Also use the existing Keychain key for paid DeepSeek calls with public samples')
    parser.add_argument('--source-url', help='With --live-api, also test Fetch for this public URL; site access may fail')
    args = parser.parse_args()
    if args.source_url and not args.live_api:
        parser.error('--source-url requires --live-api')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output = ROOT / 'artifacts/experience-verification' / stamp
    output.mkdir(parents=True)
    env = os.environ.copy()
    app = Path(env.setdefault('PROMPT_INJECTOR_APP_OUTPUT', str(ROOT / 'build/Experience-Review/Prompt Injector.app')))
    report = {'passed': False, 'scope': 'headless-partial' if args.headless else 'native-ui-full',
              'liveAPIRequested': args.live_api, 'linkRequested': bool(args.source_url), 'formalLibraryChanged': False}
    try:
        command = [sys.executable, str(ROOT / 'scripts/test-suite.py')]
        if args.headless:
            command.append('--headless')
        suite_report = None
        with (output / 'regression.log').open('w') as log:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
                if line.startswith('Report: '):
                    suite_report = Path(line[len('Report: '):].strip())
            code = process.wait()
        if code or suite_report is None:
            raise RuntimeError('Regression failed; see regression.log')
        baseline = json.loads(suite_report.read_text())
        if baseline.get('passed') is not True:
            raise RuntimeError('Regression report did not pass')
        report['regressionReport'] = str(suite_report)
        report['build'] = baseline.get('build')
        if args.live_api:
            if args.headless:
                subprocess.run(['bash', 'scripts/build-app.sh'], cwd=ROOT, env=env, check=True, stdout=subprocess.DEVNULL)
            live = output / 'live'
            command = [str(app / 'Contents/MacOS/PromptInjector'), '--verify-experience', str(live)]
            if args.source_url:
                command += ['--source-url', args.source_url]
            print('Running real DeepSeek verification with isolated data…', flush=True)
            with (output / 'live.log').open('w') as log:
                result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1500)
            report['live'] = json.loads((live / 'report.json').read_text())
            if result.returncode or report['live'].get('passed') is not True:
                raise RuntimeError('Real API verification failed; see live/report.json and live.log')
        report['passed'] = True
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        report['error'] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        path = output / 'report.json'
        path.write_text(json.dumps(report, indent=2) + '\n')
        print(f'Experience report: {path}', flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
