import XCTest
import AppKit
@testable import PromptInjector

private final class DelayedRepository: PromptRepository {
    let backing: MemoryPromptRepository
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var delayDetail = false
    var failDetail = false
    init() throws { backing = MemoryPromptRepository(entries: try PromptSeed.entries()) }
    func categories() throws -> [PromptCategory] { XCTAssertFalse(Thread.isMainThread); return try backing.categories() }
    func summaries(in category: String) throws -> [PromptSummary] { XCTAssertFalse(Thread.isMainThread); return try backing.summaries(in: category) }
    func entry(id: String, category: String) throws -> PromptEntry? {
        XCTAssertFalse(Thread.isMainThread)
        if delayDetail { entered.signal(); _ = release.wait(timeout: .now() + 3) }
        if failDetail { throw SQLiteFailure(code: 11) }
        return try backing.entry(id: id, category: category)
    }
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
}
