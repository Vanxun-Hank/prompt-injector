import XCTest
import AppKit
@testable import PromptInjector

private final class DelayedRepository: PromptRepository {
    let backing: MemoryPromptRepository
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var delayDetail = false
    var failDetail = false
    var reverseSummaries = false
    init() throws { backing = MemoryPromptRepository(entries: try PromptSeed.entries()) }
    func categories() throws -> [PromptCategory] { XCTAssertFalse(Thread.isMainThread); return try backing.categories() }
    func summaries(in category: String) throws -> [PromptSummary] {
        XCTAssertFalse(Thread.isMainThread)
        let values = try backing.summaries(in: category)
        return reverseSummaries ? values.reversed() : values
    }
    func entry(id: String, category: String) throws -> PromptEntry? {
        XCTAssertFalse(Thread.isMainThread)
        if delayDetail { entered.signal(); _ = release.wait(timeout: .now() + 3) }
        if failDetail { throw SQLiteFailure(code: 11) }
        return try backing.entry(id: id, category: category)
    }
    func create(_ entry: PromptEntry, operationID: UUID) throws { try backing.create(entry, operationID: operationID) }
}

final class LibraryLoadingTests: XCTestCase {
    @MainActor private func ready(_ view: LauncherView) async throws {
        for _ in 0..<200 {
            if !view.isLoading { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Library load timed out")
    }
    @MainActor func testLateDetailCannotReplaceNewPageOrEnableStaleInsertion() async throws {
        let repo = try DelayedRepository()
        let view = LauncherView(library: PromptLibrary(repository: repo)); try await ready(view)
        repo.delayDetail = true
        view.navigate(to: .detail("debugging", "debug-root-cause"), animate: false)
        var inserted = false; view.onInsert = { _ in inserted = true }
        view.insertPrompt(); XCTAssertFalse(inserted)
        // Navigate back before the queued detail finishes; stale completion must be discarded.
        view.goBack()
        repo.release.signal()
        try await ready(view)
        XCTAssertEqual(view.navigation.page, .entries("debugging"))
        XCTAssertNil(view.currentEntry); XCTAssertTrue(view.insertButton.isHidden)
        XCTAssertEqual(view.numberOfRows(in: view.table), 3)
    }
    @MainActor func testDatabaseFailureClearsPreviousPromptAndCannotInsertIt() async throws {
        let repo = try DelayedRepository()
        let view = LauncherView(library: PromptLibrary(repository: repo)); try await ready(view)
        view.navigate(to: .detail("debugging", "debug-root-cause"), animate: false); try await ready(view)
        XCTAssertNotNil(view.currentEntry)
        view.goBack(); try await ready(view)
        repo.failDetail = true
        view.openSelection(); try await ready(view)
        XCTAssertNil(view.currentEntry); XCTAssertTrue(view.insertButton.isHidden)
        XCTAssertFalse(view.feedback.isHidden); XCTAssertTrue(view.feedback.stringValue.contains("无法读取"))
        var inserted = false; view.onInsert = { _ in inserted = true }; view.insertPrompt(); XCTAssertFalse(inserted)
        repo.failDetail = false
        view.retryFailedLoad(); try await ready(view)
        XCTAssertNotNil(view.currentEntry); XCTAssertTrue(view.feedback.isHidden)
    }
    @MainActor func testLazyNavigationRestoresSelectionAndPassesExactPromptToInsertion() async throws {
        let repo = try DelayedRepository()
        let view = LauncherView(library: PromptLibrary(repository: repo)); try await ready(view)
        view.table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        view.openSelection(); try await ready(view)
        view.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        view.openSelection(); try await ready(view)
        let expected = try repo.backing.entry(id: "debug-hypotheses", category: "debugging")
        var received: PromptEntry?; view.onInsert = { received = $0 }; view.insertPrompt()
        XCTAssertEqual(received, expected)
        view.goBack(); try await ready(view); XCTAssertEqual(view.table.selectedRow, 1)
        view.goBack(); try await ready(view); XCTAssertEqual(view.table.selectedRow, 2)
    }

    private var newEntry: PromptEntry {
        .init(id: UUID().uuidString, categoryID: "debugging", title: "新内容😀", summary: "摘要", originalExperience: "原文", source: "来源", explanation: "解释", prompt: "\n新 Prompt\n```swift\nlet x = 1\n```\n")
    }
    @MainActor private func create(_ value: PromptEntry, in library: PromptLibrary, committed: @escaping () -> Void = {}) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            library.create(value) { result in
                XCTAssertTrue(Thread.isMainThread)
                committed()
                continuation.resume(with: result)
            }
        }
    }
    @MainActor func testCommittedCreationRefreshesListAndPreservesSelectionByStableID() async throws {
        let repo = try DelayedRepository()
        let library = PromptLibrary(repository: repo)
        let view = LauncherView(library: library); try await ready(view)
        view.navigate(to: .entries("debugging"), animate: false); try await ready(view)
        view.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        repo.reverseSummaries = true
        let value = newEntry
        try await create(value, in: library) { XCTAssertTrue(view.isLoading) }
        try await ready(view)
        XCTAssertEqual(view.numberOfRows(in: view.table), 4)
        XCTAssertEqual(view.table.selectedRow, 3)
        view.openSelection(); try await ready(view)
        XCTAssertEqual(view.currentEntry?.id, "debug-root-cause")
        view.goBack(); try await ready(view)
        view.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        view.openSelection(); try await ready(view)
        XCTAssertEqual(view.currentEntry, value)
        var inserted: PromptEntry?
        view.onInsert = { inserted = $0 }; view.insertPrompt()
        XCTAssertEqual(inserted, value)
    }
    @MainActor func testSaveInvalidatesDetailUntilReloadAndFailureCannotInsertPreviousPrompt() async throws {
        let repo = try DelayedRepository()
        let library = PromptLibrary(repository: repo)
        let view = LauncherView(library: library); try await ready(view)
        view.navigate(to: .detail("debugging", "debug-root-cause"), animate: false); try await ready(view)
        var inserted = false; view.onInsert = { _ in inserted = true }
        repo.failDetail = true
        try await create(newEntry, in: library) {
            XCTAssertNil(view.currentEntry)
            view.insertPrompt(); XCTAssertFalse(inserted)
        }
        try await ready(view)
        XCTAssertNil(view.currentEntry); view.insertPrompt(); XCTAssertFalse(inserted)
        XCTAssertFalse(view.feedback.isHidden)
        repo.failDetail = false
        view.retryFailedLoad(); try await ready(view)
        XCTAssertEqual(view.currentEntry?.id, "debug-root-cause")
    }
    @MainActor func testSamePageRefreshDiscardsLateDetailBeforeReplacementFinishes() async throws {
        let repo = try DelayedRepository()
        let library = PromptLibrary(repository: repo)
        let view = LauncherView(library: library); try await ready(view)
        repo.delayDetail = true
        view.navigate(to: .detail("debugging", "debug-root-cause"), animate: false)
        XCTAssertEqual(repo.entered.wait(timeout: .now() + 2), .success)
        NotificationCenter.default.post(name: PromptLibrary.didChange, object: library, userInfo: ["categoryID": "debugging"])
        repo.release.signal()
        XCTAssertEqual(repo.entered.wait(timeout: .now() + 2), .success)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertNil(view.currentEntry); XCTAssertTrue(view.isLoading)
        var inserted = false; view.onInsert = { _ in inserted = true }; view.insertPrompt(); XCTAssertFalse(inserted)
        repo.release.signal(); try await ready(view)
        XCTAssertEqual(view.currentEntry?.id, "debug-root-cause")
    }
    @MainActor func testUnrelatedCategoryAndFailedWritesDoNotInvalidateCurrentDetail() async throws {
        let repo = try DelayedRepository()
        let library = PromptLibrary(repository: repo)
        let view = LauncherView(library: library); try await ready(view)
        view.navigate(to: .detail("coding", "coding-small-steps"), animate: false); try await ready(view)
        let before = view.currentEntry
        XCTAssertNotNil(before)
        try await create(newEntry, in: library)
        XCTAssertEqual(view.currentEntry, before); XCTAssertFalse(view.isLoading)
        let invalid = PromptEntry(id: "invalid", categoryID: "coding", title: "标题", summary: "", originalExperience: "", source: "", explanation: "", prompt: "正文")
        do { try await create(invalid, in: library); XCTFail("Invalid write must fail") } catch {}
        XCTAssertEqual(view.currentEntry, before); XCTAssertFalse(view.isLoading)
    }
}
