import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('suite', Path(__file__).parents[1]/'test-suite.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)

class SuiteReportTests(unittest.TestCase):
    def valid_report(self):
        names = ['toggle/visible-hides','motion/interrupted-show-remains-visible','copy/actual-pasteboard',
                 'minimum/plain-return-does-not-insert','page-motion/rapid-navigation-preserves-state',
                 'keyboard/command-return-routes-current-prompt','keyboard/detail-return-does-not-route-insertion']
        names += [f'capture/{i}' for i in range(13)]
        names += [f'check/{i}' for i in range(67-len(names))]
        return {'passed':True,'checks':[{'name':n,'passed':True} for n in names]}
    def testFailingAnimationCannotBeHiddenByTopLevelPassedFlag(self):
        report=self.valid_report()
        self.assertTrue(suite.validate_ui_report(report))
        report['checks'][1]['passed']=False
        self.assertFalse(suite.validate_ui_report(report))
    def testMissingCapturesOrEmptyReportNeverCountAsPass(self):
        self.assertFalse(suite.validate_ui_report({'passed':True,'checks':[]}))
        report=self.valid_report();report['checks']=[c for c in report['checks'] if not c['name'].startswith('capture/')]
        self.assertFalse(suite.validate_ui_report(report))
