import XCTest
import AppKit
@testable import PromptInjector

final class InsertionTests: XCTestCase {
    func testUTF16SelectionPreservesTextAroundEmoji() throws {
        let before = "前🙂后"
        let plan = try XCTUnwrap(InsertionPlan(before: before, range: NSRange(location: 1, length: 2), prompt: "第一行\n第二行"))
        XCTAssertEqual(plan.expected, "前第一行\n第二行后")
        XCTAssertTrue(plan.matches("前第一行\r\n第二行后"))
        XCTAssertFalse(plan.matches("前第一行\n第二行后\n"))
        XCTAssertFalse(plan.matches("前第一行\n第二行后前第一行\n第二行后"))
    }
    func testInvalidSelectionAndUnchangedInputAreNotSuccess() throws {
        XCTAssertNil(InsertionPlan(before: "🙂", range: NSRange(location: 1, length: 1), prompt: "x"))
        XCTAssertNil(InsertionPlan(before: "", range: NSRange(location: NSNotFound, length: 0), prompt: "x"))
        XCTAssertNil(InsertionPlan(before: "x", range: NSRange(location: 1, length: Int.max), prompt: "x"))
        let plan = try XCTUnwrap(InsertionPlan(before: "", range: NSRange(location: 0, length: 0), prompt: "多行\nPrompt"))
        XCTAssertFalse(plan.matches(""))
        XCTAssertTrue(plan.matches("多行\nPrompt"))
    }
    @MainActor func testClipboardRestoresMultipleItemsAndTypes() throws {
        let pb = NSPasteboard(name: .init("PromptInjector.test.\(UUID())"))
        defer { pb.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("previous", forType: .string)
        first.setData(Data([1, 2, 3]), forType: .init("com.promptinjector.test"))
        let second = NSPasteboardItem(); second.setString("second", forType: .string)
        pb.writeObjects([first, second])
        let transaction = try PasteboardTransaction(text: "Prompt", pasteboard: pb)
        XCTAssertEqual(pb.string(forType: .string), "Prompt")
        XCTAssertTrue(transaction.restoreIfOwned())
        XCTAssertEqual(pb.pasteboardItems?.count, 2)
        XCTAssertEqual(pb.pasteboardItems?.first?.data(forType: .init("com.promptinjector.test")), Data([1, 2, 3]))
        XCTAssertEqual(pb.pasteboardItems?.first?.string(forType: .string), "previous")
        XCTAssertEqual(pb.pasteboardItems?.last?.string(forType: .string), "second")
    }
    @MainActor func testClipboardDoesNotOverwriteNewUserCopy() throws {
        let pb = NSPasteboard(name: .init("PromptInjector.test.\(UUID())"))
        defer { pb.releaseGlobally() }
        pb.setString("previous", forType: .string)
        let transaction = try PasteboardTransaction(text: "Prompt", pasteboard: pb)
        pb.clearContents(); pb.setString("user copied later", forType: .string)
        XCTAssertFalse(transaction.restoreIfOwned())
        XCTAssertEqual(pb.string(forType: .string), "user copied later")
    }
}
