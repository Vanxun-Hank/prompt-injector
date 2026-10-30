import XCTest
import AppKit
@testable import PromptInjector

private final class CreationRepository: PromptRepository {
    let backing = MemoryPromptRepository(entries: [])
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var fail = false
    var block = false
    var createCount = 0
    func categories() throws -> [PromptCategory] { try backing.categories() }
    func summaries(in category: String) throws -> [PromptSummary] { try backing.summaries(in: category) }
    func entry(id: String, category: String) throws -> PromptEntry? { try backing.entry(id: id, category: category) }
    func create(_ entry: PromptEntry, operationID: UUID) throws {
        XCTAssertFalse(Thread.isMainThread)
        createCount += 1
        if block { entered.signal(); _ = release.wait(timeout: .now() + 3) }
        if fail { throw SQLiteFailure(code: 13) }
        try backing.create(entry, operationID: operationID)
    }
}

final class CreationTests: XCTestCase {
    @MainActor private func finished(_ form: ManagementWindowController) async throws {
        for _ in 0..<200 {
            if !form.isSaving { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Save timed out")
    }
    @MainActor private func fill(_ form: ManagementWindowController) {
        form.category.selectItem(at: 1)
        form.titleField.stringValue = " 中文😀标题 ' "
        form.summaryField.stringValue = "简述😀"
        form.originalExperience.string = "经验\n原文"
        form.source.string = "作者\nhttps://example.com"
        form.explanation.string = "解释🧑🏽‍💻\n保留"
        form.prompt.string = "\n中文😀\n```swift\nlet value = \"原文\"\n\n```\n"
    }
    @MainActor func testRequiredFieldsPreventWritesAndKeepInput() throws {
        let repo = CreationRepository()
        let form = ManagementWindowController(library: PromptLibrary(repository: repo))
        form.titleField.stringValue = " \n"
        form.prompt.string = "\n\t"
        let before = form.entry
        form.save()
        XCTAssertFalse(form.isSaving); XCTAssertFalse(form.titleError.isHidden); XCTAssertFalse(form.promptError.isHidden)
        XCTAssertEqual(form.entry, before); XCTAssertEqual(repo.createCount, 0)
        form.titleField.stringValue = "标题"
        form.save()
        XCTAssertTrue(form.titleError.isHidden); XCTAssertFalse(form.promptError.isHidden)
        XCTAssertEqual(repo.createCount, 0)
        form.newEntry(); XCTAssertEqual(form.entry.id, before.id)
    }
    @MainActor func testDuplicateClicksSaveOnceAndNewDraftRequiresExplicitAction() async throws {
        let repo = CreationRepository(); repo.block = true
        let form = ManagementWindowController(library: PromptLibrary(repository: repo)); fill(form)
        let before = form.entry
        form.save()
        XCTAssertEqual(repo.entered.wait(timeout: .now() + 2), .success)
        form.save(); form.newEntry()
        XCTAssertEqual(repo.createCount, 1); XCTAssertFalse(form.saveButton.isEnabled)
        XCTAssertFalse(form.prompt.isEditable); XCTAssertFalse(form.category.isEnabled)
        repo.release.signal(); try await finished(form)
        XCTAssertTrue(form.isSaved); XCTAssertEqual(repo.backing.entries, [before])
        form.save(); XCTAssertEqual(repo.createCount, 1)
        XCTAssertEqual(form.entry, before); XCTAssertFalse(form.saveButton.isEnabled)
        form.newEntry()
        XCTAssertNotEqual(form.entry.id, before.id); XCTAssertTrue(form.entry.prompt.isEmpty)
        XCTAssertTrue(form.saveButton.isEnabled); XCTAssertTrue(form.prompt.isEditable)
        XCTAssertFalse(form.isSaved)
    }
    @MainActor func testFailureAndWindowReopenPreserveEveryFieldAndStableIDThenRetry() async throws {
        let repo = CreationRepository(); repo.fail = true
        let form = ManagementWindowController(library: PromptLibrary(repository: repo)); fill(form)
        let before = form.entry
        form.save(); try await finished(form)
        XCTAssertFalse(form.isSaved); XCTAssertEqual(form.entry, before)
        XCTAssertTrue(form.saveButton.isEnabled); XCTAssertTrue(form.prompt.isEditable)
        XCTAssertTrue(form.feedback.stringValue.contains("保存失败")); XCTAssertTrue(repo.backing.entries.isEmpty)
        form.window?.close()
        XCTAssertEqual(form.entry, before)
        repo.fail = false
        form.save(); try await finished(form)
        XCTAssertTrue(form.isSaved); XCTAssertEqual(repo.backing.entries, [before])
    }
}
