#!/usr/bin/env python3
"""Run V7 grid, inline editing and unified workbench regressions plus the existing suite.

Uses an isolated review app and fixture databases. Pass --headless for partial checks.
No live DeepSeek requests or real cross-application insertion.
"""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    env = os.environ.copy()
    env.setdefault('PROMPT_INJECTOR_APP_OUTPUT', str(ROOT / 'build/Management-V7-Review/Prompt Injector.app'))
    raise SystemExit(subprocess.call([sys.executable, str(ROOT / 'scripts/test-suite.py'), *sys.argv[1:]], cwd=ROOT, env=env))
