import XCTest
import AppKit
@testable import PromptInjector

final class ManagementInteractionTests: XCTestCase {
    @MainActor func testClearingPromptKeepsReviewRowsAndStableSelectionUntilCorrection() throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repository = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        let manager = ManagementWindowController(library: PromptLibrary(repository: repository))
        var session = ExperienceSession(); session.raw = "原文A\n原文B"
        session.items = ["A", "B"].map { name in
            ExperienceItem(title: name, original: "原文" + name,
                candidate: GeneratedPrompt(title: name, summary: "适用条件", explanation: "保留方法", prompt: "执行" + name, categoryID: "coding", newCategoryName: nil))
        }
        session.currentID = session.items[0].id; manager.presentExperience(session)
        manager.experience?.organize()
        let editor = try XCTUnwrap(manager.root.editor)
        editor.promptText.text.string = ""; editor.textDidChange(Notification(name: NSText.didChangeNotification, object: editor.promptText.text))
        XCTAssertEqual(manager.experience?.reviewItems.map(\.id), session.items.map(\.id))
        editor.reviewList.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        XCTAssertEqual(manager.root.editor?.id, session.items[1].id)
        manager.root.editor?.reviewList.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertEqual(manager.root.editor?.id, session.items[0].id)
        XCTAssertEqual(manager.root.editor?.promptText.text.string, "")
        manager.confirmExperienceReview()
        XCTAssertTrue(manager.experience?.session.confirmed.isEmpty == true)
        XCTAssertFalse(try XCTUnwrap(manager.root.editor).promptError.isHidden)
        manager.window?.orderOut(nil)
    }

    @MainActor func testCategoryCreationRejectsBlankAndUsesNormalizedExistingID() throws {
        _ = NSApplication.shared
        let categories = PromptCategory.initial
        var selectedID: String?, newName: String?, calls = 0
        let chooser = CategoryPopover(categories: categories, selected: "coding") { id, name in
            calls += 1; selectedID = id; newName = name
        }
        chooser.showCreate(name: " \n "); chooser.create()
        XCTAssertEqual(calls, 0); XCTAssertFalse(chooser.errorLabel.stringValue.isEmpty)
        chooser.nameField.stringValue = "  编码  "; chooser.create()
        XCTAssertEqual(calls, 1); XCTAssertEqual(selectedID, "coding"); XCTAssertNil(newName)
        chooser.showCreate(name: " 验证与约定 "); chooser.create()
        XCTAssertEqual(calls, 2); XCTAssertNil(selectedID); XCTAssertEqual(newName, "验证与约定")
        XCTAssertEqual(chooser.popover.behavior, .transient)
    }

    @MainActor func testComparisonHighlightsUnicodeChangeAndDoesNotMutateEitherVersion() {
        let old = "仅当😀可复现时，先测试。", new = "仅当😀可复现时，先写失败测试。"
        let range = PromptComparisonView.changedRange(current: old, proposed: new)
        XCTAssertEqual((new as NSString).substring(with: range), "写失败")
        let view = PromptComparisonView(current: old, proposed: new)
        XCTAssertEqual(view.current.text.string, old); XCTAssertEqual(view.proposed.text.string, new)
        XCTAssertFalse(view.current.text.isEditable); XCTAssertFalse(view.proposed.text.isEditable)
        XCTAssertEqual(PromptComparisonView.changedRange(current: new, proposed: new).length, 0)
        XCTAssertEqual(PromptComparisonView.changedRange(current: new, proposed: "").length, 0)
    }

    func testOldExperienceDraftDoesNotTreatBatchCheckboxAsApproval() throws {
        var session = ExperienceSession(); session.input = "作者原文"; session.raw = session.input
        session.items = [.init(title: "旧草稿", original: session.raw, selected: true)]
        session.currentID = session.items[0].id
        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(ExperienceSession.self, from: data)
        XCTAssertEqual(restored.selected.count, 1); XCTAssertTrue(restored.confirmed.isEmpty)
        XCTAssertNil(restored.items[0].suggestion); XCTAssertEqual(restored.remaining.items.count, 1)
    }
}
