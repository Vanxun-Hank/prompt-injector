import XCTest
import AppKit
import CSQLite
@testable import PromptInjector

final class CreationTests: XCTestCase {
    var directory: URL!
    var repository: SQLitePromptRepository!
    var library: PromptLibrary!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        repository = SQLitePromptRepository(url: directory.appendingPathComponent("library.sqlite3"), seed: { [] })
        library = PromptLibrary(repository: repository)
        _ = try repository.categories()
    }
    override func tearDownWithError() throws {
        library = nil; repository = nil
        try FileManager.default.removeItem(at: directory)
    }
    @MainActor private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Editor operation timed out")
    }
    @MainActor private func editor(in form: ManagementWindowController) async throws -> PromptEditorView {
        form.newEntry()
        try await until { form.root.editor != nil }
        return try XCTUnwrap(form.root.editor)
    }
    @MainActor private func fill(_ editor: PromptEditorView) {
        editor.titleField.stringValue = " 中文😀标题 ' "
        editor.summaryText.text.string = "简述😀"
        editor.originalText.text.string = "经验\n原文"
        editor.sourceField.stringValue = "作者 https://example.com"
        editor.explanationText.text.string = "解释🧑🏽‍💻\n保留"
        editor.promptText.text.string = "\n中文😀\n```swift\nlet value = \"原文\"\n\n```\n"
    }
    @MainActor func testRequiredFieldsPreventWritesAndKeepInput() async throws {
        let form = ManagementWindowController(library: library)
        let editor = try await editor(in: form)
        editor.titleField.stringValue = " \n"; editor.promptText.text.string = "\n\t"
        let before = editor.value
        form.saveEditor()
        XCTAssertFalse(form.isSaving); XCTAssertEqual(editor.value, before)
        XCTAssertTrue(form.root.requiredLabel.stringValue.contains("标题和 Prompt"))
        XCTAssertTrue(try repository.managedSummaries(category: nil, query: "").isEmpty)
        editor.titleField.stringValue = "标题"; form.saveEditor()
        XCTAssertFalse(form.isSaving)
        XCTAssertTrue(try repository.managedSummaries(category: nil, query: "").isEmpty)
    }
    @MainActor func testDuplicateClicksSaveOnceAndNewDraftRequiresExplicitAction() async throws {
        let form = ManagementWindowController(library: library)
        let editor = try await editor(in: form); fill(editor)
        let before = editor.value
        form.saveEditor(); form.saveEditor(); form.newEntry()
        XCTAssertTrue(form.isSaving); XCTAssertFalse(form.root.saveButton.isEnabled)
        XCTAssertFalse(editor.promptText.text.isEditable); XCTAssertFalse(editor.categoryButton.isEnabled)
        try await until { !form.isSaving }
        XCTAssertNil(form.root.editor)
        XCTAssertEqual(try repository.entry(id: before.id, category: before.categoryID), before)
        XCTAssertEqual(try repository.managedSummaries(category: nil, query: "").count, 1)
        form.saveEditor()
        XCTAssertEqual(try repository.managedSummaries(category: nil, query: "").count, 1)
        let next = try await self.editor(in: form)
        XCTAssertNotEqual(next.id, before.id); XCTAssertTrue(next.value.prompt.isEmpty)
    }
    @MainActor func testFailureAndWindowReopenPreserveEveryFieldAndStableIDThenRetry() async throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(directory.appendingPathComponent("library.sqlite3").path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TRIGGER fail_create BEFORE INSERT ON prompts BEGIN SELECT RAISE(ABORT,'test'); END", nil, nil, nil), SQLITE_OK)
        let form = ManagementWindowController(library: library)
        let editor = try await editor(in: form); fill(editor)
        let before = editor.value
        form.saveEditor(); try await until { !form.isSaving }
        XCTAssertEqual(form.root.editor?.value, before)
        XCTAssertEqual(form.root.statusLabel.stringValue, "保存失败")
        XCTAssertTrue(editor.promptText.text.isEditable)
        await withCheckedContinuation { continuation in library.flush { continuation.resume() } }
        form.window?.close()
        let reopened = ManagementWindowController(library: library)
        let restored = try await self.editor(in: reopened)
        XCTAssertEqual(restored.value, before)
        XCTAssertEqual(sqlite3_exec(db, "DROP TRIGGER fail_create", nil, nil, nil), SQLITE_OK)
        reopened.saveEditor(); try await until { !reopened.isSaving }
        XCTAssertEqual(try repository.entry(id: before.id, category: before.categoryID), before)
    }
}
