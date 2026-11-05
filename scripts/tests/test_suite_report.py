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
        names += ['management/save-failure-keeps-input','management/reopen-preserves-fields-and-id',
                  'management/cancel-restores-local-draft','management/edit-stable-id-without-duplicate',
                  'statistics/explicit-success-events-only','assets/all-figma-assets-load']
        names += ['statistics/all-columns-fit','management/native-window-controls',
                  'management/separate-native-window','management/required-fields','management/return-edits-does-not-save',
                  'management/native-close-hides','management/native-minimize','management/native-zoom',
                  'management/native-fullscreen-space','management/native-fullscreen-exit',
                  'management/regular-application','application/branded-icon','application/transparent-icon-canvas',
                  'keyboard/blocked-command-return-no-route','keyboard/recovered-command-return-routes']
        names += ['capture/management-'+n for n in ['library','editor','original','save-error','statistics','minimum','candidate','new-category','sixth-statistics','reading-original','reading-explanation','categories-scroll','delete-confirmation','comparison','category-create']]
        names += ['categories/blank-name-stays-inline', 'management/delete-default-is-cancel', 'experience/confirm-action-visible']
        names += ['v7/'+n for n in ['grid-default-and-three-columns','grid-minimum-two-columns','edit-stays-in-preview','inline-minimum-fields-fit','unified-workbench','all-saved-without-resurrected-input','saved-card-immediately-available','partial-save-1','partial-save-5','partial-save-20','completed-one','remaining-draft-5','remaining-draft-20']]
        names += ['capture/management-inline-editor','capture/management-inline-minimum','capture/management-grid-minimum','capture/v7-partial-1','capture/v7-partial-5','capture/v7-partial-20']
        names += ['v7/input-validation-near-field', 'v7/input-mode-retains-prompt', 'capture/experience-input-error']
        names += ['generation/candidate-is-editable', 'generation/candidate-does-not-overwrite', 'generation/adoption-preserves-original-source',
                  'categories/new-name-entire-control-visible', 'categories/sixth-sidebar-preview', 'categories/sixth-launcher-list', 'categories/sixth-launcher-full-prompt', 'categories/sixth-statistics']
        names += ['reading/prompt-only-verbatim', 'reading/original-source-verbatim', 'reading/explanation-only', 'categories/growing-sidebar-scroll']
        names += ['experience/empty-prompt-blocks-review', 'experience/manual-paste-skips-generation', 'experience/manual-pair-fit', 'experience/audit-list-stashes-edits', 'experience/audit-list-restores-edits', 'experience/audit-fields-fit-minimum', 'experience/identified-exact-original', 'experience/checkbox-does-not-discuss', 'experience/selection-preserves-prompt-without-chat',
                  'experience/reopen-independent-prompts', 'experience/batch-saved-with-sixth-category',
                  'experience/saved-immediately-loads-in-launcher', 'experience/deleted-entry-no-longer-loads']
        names += ['capture/experience-'+n for n in ['organize','minimum','review','original','new','manual','manual-minimum','review-minimum']]
        names += ['management/'+n for n in ['icon-copy-feedback','copy-all-reading-tabs','icon-actions-keyboard-focus','direct-actions-search','direct-actions-category']]
        names += ['workbench/'+n for n in ['compact-completion','add-keeps-list-and-focus','view-existing-while-adding','append-source-visible','context-remove-keeps-current','edited-removal-cancel-keeps-draft','removal-selects-adjacent','remove-last-empties-detail','continue-from-empty','continue-after-save']]
        names += ['workbench/removed-clears-old-save-count','capture/workbench-complete','capture/workbench-addition-minimum']
        names += [f'check/{i}' for i in range(90-len(names))]
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
    def testMissingManagementEvidenceCannotReuseOldLauncherPass(self):
        report=self.valid_report()
        report['checks']=[c for c in report['checks'] if c['name']!='management/save-failure-keeps-input']
        self.assertFalse(suite.validate_ui_report(report))

    def testMissingGenerationEvidenceCannotReuseOldManagementPass(self):
        report=self.valid_report()
        report['checks']=[c for c in report['checks'] if c['name']!='categories/sixth-statistics']
        self.assertFalse(suite.validate_ui_report(report))

    def testMissingExperienceChecksCannotReuseEarlierUIPass(self):
        report = self.valid_report()
        self.assertTrue(suite.validate_ui_report(report))
        report['checks'] = [c for c in report['checks'] if c['name'] != 'experience/checkbox-does-not-discuss']
        self.assertFalse(suite.validate_ui_report(report))

    def testMissingV7EvidenceCannotReuseEarlierManagementPass(self):
        report = self.valid_report()
        report['checks'] = [c for c in report['checks'] if c['name'] != 'v7/unified-workbench']
        self.assertFalse(suite.validate_ui_report(report))

    def testMissingContinuationEvidenceCannotReuseEarlierWorkbenchPass(self):
        report = self.valid_report()
        report['checks'] = [c for c in report['checks'] if c['name'] != 'workbench/continue-after-save']
        self.assertFalse(suite.validate_ui_report(report))
