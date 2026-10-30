import XCTest
@testable import PromptInjector

final class TargetTextTests: XCTestCase {
    private let hint = "0123456789abcde\n"
    private let start = NSRange(location: 0, length: 0)
    private func resolve(_ value: String, range: NSRange? = NSRange(location: 0, length: 0), marker: Bool = true, bundle: String = "com.openai.codex", role: String = "AXTextArea") -> String? {
        TargetText.resolved(value: value, selection: range, bundleID: bundle, role: role, emptyComposerMarker: marker)
    }
    func testObservedEmptyComposerUsesStructureToExcludeGeneratedHintAndKeepsFullVerification() throws {
        XCTAssertEqual(hint.utf16.count, 16)
        let before = try XCTUnwrap(resolve(hint))
        XCTAssertEqual(before, "")
        for otherHint in ["请输入内容", "😀\n", String(repeating: "hint", count: 20)] { XCTAssertEqual(resolve(otherHint), "") }
        let prompt = "中文😀\n\n```swift\nlet value = 1\n```\n"
        let plan = try XCTUnwrap(InsertionPlan(before: before, range: start, prompt: prompt))
        XCTAssertTrue(plan.matches(prompt))
        XCTAssertFalse(plan.matches(prompt + hint))
        XCTAssertFalse(plan.matches(prompt.replacingOccurrences(of: "\n\n", with: "\n")))
    }
    func testRealTextIdenticalToHintIsPreservedWithoutEmptyMarker() throws {
        let before = try XCTUnwrap(resolve(hint, marker: false))
        XCTAssertEqual(before, hint)
        let plan = try XCTUnwrap(InsertionPlan(before: before, range: start, prompt: "新 Prompt"))
        XCTAssertTrue(plan.matches("新 Prompt" + hint))
        XCTAssertFalse(plan.matches("新 Prompt"))
        let body = "已有😀\n\n正文"
        XCTAssertEqual(resolve(body, range: .init(location: 2, length: 2), marker: false), body)
        XCTAssertEqual(resolve("", marker: false), "")
    }
    func testMarkerDoesNotNormalizeOtherApplicationsOrRolesAndInconsistentSelectionIsRejected() {
        XCTAssertEqual(resolve(hint, bundle: "com.example.editor"), hint)
        XCTAssertEqual(resolve(hint, role: "AXGroup"), hint)
        XCTAssertNil(resolve(hint, range: nil))
        XCTAssertNil(resolve(hint, range: .init(location: 1, length: 0)))
        XCTAssertNil(resolve(hint, range: .init(location: 0, length: 1)))
    }
    func testTypingAfterEmptyCaptureChangesSemanticValueEvenWhenTextEqualsHint() {
        let before = resolve(hint)
        let afterTyping = resolve(hint, marker: false)
        XCTAssertNotEqual(before, afterTyping)
        XCTAssertEqual(afterTyping, hint)
        XCTAssertNotEqual(before, resolve("用户已修改", marker: false))
    }
}
