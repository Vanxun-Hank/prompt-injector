import XCTest
import AppKit
import CSQLite
@testable import PromptInjector

final class GenerationTests: XCTestCase {
    let candidate = GeneratedPrompt(title: "先复现再修复", summary: "修复能复现的问题时使用", explanation: "先用失败测试固定问题，再做最小修复；仅适用于能复现的问题。", prompt: "若问题能复现，先写最小失败测试，确认失败后修复，并重跑测试。", categoryID: "debugging", newCategoryName: nil)
    func entry(_ id: String = UUID().uuidString) -> PromptEntry {
        .init(id: id, categoryID: "coding", title: "手工标题", summary: "手工简述", originalExperience: "能复现的 bug，先写失败测试，再做最小修复。\n保留条件😀", source: "用户粘贴 https://example.com/method", explanation: "手工解释", prompt: "手工 Prompt")
    }
    func testStructuredOutputRejectsMissingExtraUnknownAndAmbiguousFields() throws {
        let data = try JSONEncoder().encode(candidate)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["newCategoryName"] = NSNull()
        func decode() throws -> GeneratedPrompt { try GeneratedPrompt.decode(JSONSerialization.data(withJSONObject: json), categories: PromptCategory.initial) }
        XCTAssertEqual(try decode(), candidate)
        json["source"] = "虚构来源"; XCTAssertThrowsError(try decode()); json.removeValue(forKey: "source")
        json["categoryID"] = "unknown"; XCTAssertThrowsError(try decode())
        json["categoryID"] = "debugging"; json["newCategoryName"] = "另一分类"; XCTAssertThrowsError(try decode())
        json["categoryID"] = NSNull(); XCTAssertEqual(try decode().newCategoryName, "另一分类")
        json["prompt"] = "  "; XCTAssertThrowsError(try decode())
        json.removeValue(forKey: "prompt"); XCTAssertThrowsError(try decode())
    }
    @MainActor func testCandidateRequiresAdoptionAndNeverChangesExperienceOrSource() throws {
        let value = entry(), editor = PromptEditorView(draft: EditorDraft(entry: value, original: value), categories: PromptCategory.initial)
        editor.receiveCandidate(candidate)
        XCTAssertEqual(editor.value, value)
        editor.titleField.stringValue = "生成后继续手改"
        XCTAssertEqual(editor.candidate, candidate)
        editor.candidateEditor.fields[0].text.string = "候选内手改标题"
        XCTAssertEqual(editor.value.title, "生成后继续手改")
        XCTAssertEqual(editor.draft.candidate?.title, "候选内手改标题")
        var failure = false; editor.onFailure = { _ in failure = true }
        editor.candidateEditor.fields[3].text.string = ""
        editor.adoptCandidate()
        XCTAssertTrue(failure); XCTAssertEqual(editor.value.title, "生成后继续手改")
        editor.candidateEditor.fields[3].text.string = candidate.prompt
        editor.adoptCandidate()
        XCTAssertEqual(editor.value.title, "候选内手改标题")
        XCTAssertEqual(editor.value.prompt, candidate.prompt)
        XCTAssertEqual(editor.value.originalExperience, value.originalExperience)
        XCTAssertEqual(editor.value.source, value.source)
        XCTAssertNil(editor.candidate)
    }
    @MainActor func testMinimumEditorKeepsGenerationAndKeychainActionsVisible() {
        let editor = PromptEditorView(draft: EditorDraft(entry: entry(), original: nil), categories: PromptCategory.initial)
        editor.frame = NSRect(x: 0, y: 0, width: 820, height: 456)
        editor.layoutSubtreeIfNeeded()
        for button in [editor.generateButton, editor.configureButton] {
            XCTAssertTrue(editor.info.bounds.contains(button.convert(button.bounds, to: editor.info)))
            XCTAssertTrue(button.superview === editor.info)
        }
        editor.addCategory(); editor.layoutSubtreeIfNeeded()
        if let box = editor.newCategoryField.superview, let scroll = editor.newCategoryField.enclosingScrollView, let doc = scroll.documentView {
            XCTAssertTrue(scroll.documentVisibleRect.contains(box.convert(box.bounds, to: doc)))
        } else { XCTFail("New category name is not in the metadata scroll view") }
        for button in [editor.generateButton, editor.configureButton] {
            XCTAssertTrue(editor.info.bounds.contains(button.convert(button.bounds, to: editor.info)))
        }
    }
    func testSixthCategoryDeduplicatesPersistsEditsUsageAndDraftWithoutChangingLegacyIDs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite3")
        let repo = SQLitePromptRepository(url: url)
        let old = try XCTUnwrap(repo.entry(id: "coding-small-steps", category: "coding"))
        try repo.recordUsage(old, kind: .insert, date: Date())
        let created = try repo.saveDraft(EditorDraft(entry: entry(), original: nil, newCategoryName: "  学习  "))
        XCTAssertEqual(try repo.categories().count, 6)
        XCTAssertEqual(try repo.categories().prefix(5).map(\.id), PromptCategory.initial.map(\.id))
        XCTAssertEqual(try repo.summaries(in: created.categoryID).first?.id, created.id)
        XCTAssertEqual(try repo.categories().last?.symbol, "folder")
        let duplicate = try repo.saveDraft(EditorDraft(entry: entry(), original: nil, newCategoryName: "学习"))
        XCTAssertEqual(created.categoryID, duplicate.categoryID)
        let moved = created.inCategory("review")
        try repo.save(moved, replacing: created)
        let restored = moved.inCategory(duplicate.categoryID)
        try repo.save(restored, replacing: moved)
        try repo.create(entry().inCategory(created.categoryID), operationID: UUID())
        try repo.recordUsage(restored, kind: .copy, date: Date())
        let draft = EditorDraft(entry: entry(), original: nil, newCategoryName: "待确认分类", candidate: candidate)
        try repo.storeDraft(draft)
        let reopened = SQLitePromptRepository(url: url)
        XCTAssertEqual(try reopened.categories().count, 6)
        XCTAssertEqual(try reopened.entry(id: created.id, category: created.categoryID), restored)
        XCTAssertEqual(try reopened.editorDraft(), draft)
        let summary = UsageSummary(records: try reopened.usage(since: nil))
        XCTAssertEqual(summary.total, 2); XCTAssertEqual(summary.categoryCounts[created.categoryID], 1)
        XCTAssertEqual(try reopened.entry(id: old.id, category: old.categoryID), old)
        XCTAssertEqual(try PromptCategory.normalizedName("Ａgent"), "Ａgent")
        XCTAssertEqual(PromptCategory.nameKey("Ａgent"), PromptCategory.nameKey("agent"))
    }
    func testCategoryAndPromptRollbackTogetherAndKeepCandidateDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite3"), repo = SQLitePromptRepository(url: url)
        _ = try repo.categories()
        let draft = EditorDraft(entry: entry(), original: nil, newCategoryName: "新分类", candidate: candidate)
        try repo.storeDraft(draft)
        var db: OpaquePointer?; XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK); defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TRIGGER fail_save BEFORE INSERT ON prompts BEGIN SELECT RAISE(ABORT,'test'); END", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try repo.saveDraft(draft))
        XCTAssertEqual(try repo.categories().count, 5)
        XCTAssertEqual(try repo.editorDraft(), draft)
        XCTAssertThrowsError(try PromptCategory.normalizedName(" \n"))
        XCTAssertThrowsError(try PromptCategory.normalizedName("分类\0"))
    }
}
