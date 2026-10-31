import XCTest
@testable import PromptInjector

final class PasteCapabilityTests: XCTestCase {
    func testEmptyComposerMarkerRequiresExactRootAndParagraphClasses() {
        XCTAssertTrue(TargetCapabilities.hasEmptyComposerMarker(rootClasses: ["ProseMirror"], descendantClasses: [["placeholder"]]))
        XCTAssertFalse(TargetCapabilities.hasEmptyComposerMarker(rootClasses: nil, descendantClasses: [["placeholder"]]))
        XCTAssertFalse(TargetCapabilities.hasEmptyComposerMarker(rootClasses: ["ProseMirror-other"], descendantClasses: [["placeholder"]]))
        XCTAssertFalse(TargetCapabilities.hasEmptyComposerMarker(rootClasses: ["ProseMirror"], descendantClasses: [["placeholder-token"]]))
        XCTAssertFalse(TargetCapabilities.hasEmptyComposerMarker(rootClasses: ["ProseMirror"], descendantClasses: [[]]))
    }
    func testObservedCodexGroupCanPasteWithoutAXSetters() {
        let target = TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false, method: .paste)
        XCTAssertTrue(target.supportsInsertion)
    }
    func testPasteDoesNotRelaxSecureDisabledOrExplicitReadOnlyTargets() {
        for target in [
            TargetCapabilities(role: "AXGroup", isSecure: true, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false, method: .paste),
            TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false, isEnabled: false, method: .paste),
            TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false, isEditable: false, method: .paste),
            TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: false, selectionWritable: false, valueWritable: false, method: .paste),
            TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: false, selectionReadable: true, selectionWritable: false, valueWritable: false, method: .paste),
            TargetCapabilities(role: "AXButton", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false, method: .paste)
        ] { XCTAssertFalse(target.supportsInsertion) }
    }
    func testNonTextControlsRemainRejectedEvenWithWritableValue() {
        for role in ["AXButton", "AXCheckBox", "AXRadioButton", "AXSlider", "AXPopUpButton", "AXMenuItem"] {
            for method in [InsertionMethod.paste, .accessibility] {
                let target = TargetCapabilities(role: role, isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: true, valueWritable: true, method: method)
                XCTAssertFalse(target.supportsInsertion, role)
            }
        }
    }
    func testOtherApplicationsDoNotGetCodexPasteException() {
        XCTAssertEqual(InsertionMethod.forApplication("com.google.Chrome"), .accessibility)
        XCTAssertFalse(TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false).supportsInsertion)
    }
}
