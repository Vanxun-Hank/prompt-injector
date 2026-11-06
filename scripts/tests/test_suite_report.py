import base64
import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('suite', Path(__file__).parents[1] / 'test-suite.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)


class SuiteReportTests(unittest.TestCase):
    build = {'buildID': 'test-build', 'sourceFingerprint': 'test-source'}

    def report(self, captures=False):
        names = suite.REQUIRED_BEHAVIOR | (suite.REQUIRED_CAPTURES if captures else set())
        return {**self.build, 'sessionID': 'test-session', 'passed': True, 'capturesEnabled': captures,
                'checks': [{'name': name, 'passed': True} for name in sorted(names)]}

    def testTierArgumentsKeepExistingEntrypoints(self):
        self.assertEqual(suite.parse_tier([]), 'full')
        self.assertEqual(suite.parse_tier(['--headless']), 'merge')
        for tier in ('fast', 'merge', 'desktop', 'visual'):
            self.assertEqual(suite.parse_tier(['--tier', tier]), tier)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            suite.parse_tier(['--headless', '--tier', 'desktop'])

    def testDesktopNeedsBehaviorEvidenceWithoutScreenshots(self):
        with tempfile.TemporaryDirectory() as directory:
            ui = Path(directory)
            report = self.report()
            self.assertTrue(suite.validate_ui_report(report, self.build, ui, captures=False))
            for name in ('management/save-failure-keeps-input', 'categories/sixth-statistics',
                         'experience/checkbox-does-not-discuss', 'v7/unified-workbench',
                         'workbench/continue-after-save', 'workbench/reopen-pending-addition'):
                with self.subTest(name=name):
                    self.assertIn(name, suite.REQUIRED_BEHAVIOR)
                    missing = [c for c in report['checks'] if c['name'] != name]
                    self.assertFalse(suite.validate_ui_report({**report, 'checks': missing}, self.build, ui, captures=False))
            self.assertFalse(suite.validate_ui_report(self.report(True), self.build, ui, captures=False))

    def testFailedOrDuplicateChecksAndStaleBuildFail(self):
        with tempfile.TemporaryDirectory() as directory:
            ui = Path(directory)
            report = self.report()
            self.assertFalse(suite.validate_ui_report({**report, 'checks': report['checks'] * 2}, self.build, ui, captures=False))
            for field in self.build:
                with self.subTest(field=field):
                    self.assertFalse(suite.validate_ui_report({**report, field: 'stale'}, self.build, ui, captures=False))
            report['checks'][0]['passed'] = False
            self.assertFalse(suite.validate_ui_report(report, self.build, ui, captures=False))

    def testVisualNeedsEachNamedCaptureAndPng(self):
        with tempfile.TemporaryDirectory() as directory:
            ui = Path(directory)
            report = self.report(True)
            pixel = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4ZkAAAAASUVORK5CYII=')
            for name in suite.REQUIRED_CAPTURES:
                (ui / (name.split('/', 1)[1] + '.png')).write_bytes(pixel)
            self.assertTrue(suite.validate_ui_report(report, self.build, ui, captures=True))
            capture = 'capture/default-shell'
            self.assertIn(capture, suite.REQUIRED_CAPTURES)
            renamed = [{**c, 'name': 'capture/wrong'} if c['name'] == capture else c for c in report['checks']]
            self.assertFalse(suite.validate_ui_report({**report, 'checks': renamed}, self.build, ui, captures=True))
            png = ui / 'default-shell.png'
            png.unlink()
            self.assertFalse(suite.validate_ui_report(report, self.build, ui, captures=True))
            png.write_bytes(pixel[:8])
            self.assertFalse(suite.validate_ui_report(report, self.build, ui, captures=True))
