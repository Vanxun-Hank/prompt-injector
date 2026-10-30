import XCTest
import CSQLite
@testable import PromptInjector

final class ManagementTests: XCTestCase {
    var dir: URL!
    var loggers: [DiagnosticLog] = []
    var url: URL { dir.appendingPathComponent("library.sqlite3") }
    override func setUpWithError() throws { dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
    override func tearDownWithError() throws { loggers.forEach { $0.flush() }; loggers = []; try FileManager.default.removeItem(at: dir) }
    func repo() -> SQLitePromptRepository {
        let logger = DiagnosticLog(directory: dir.appendingPathComponent("logs")); loggers.append(logger)
        return .init(url: url, logger: logger)
    }
    func entry(id: String = "new", category: String = "coding", title: String = "中文 100%_😀", prompt: String = "原文\n\nlet a = 'quoted'\n\0尾部") -> PromptEntry {
        .init(id: id, categoryID: category, title: title, summary: "有_符号的摘要", originalExperience: "完整原文😀\n第二行", source: "作者 / 来源", explanation: "解释不覆盖原文", prompt: prompt)
    }
    func sql(_ command: String) throws {
        var db: OpaquePointer?; XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK); defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, command, nil, nil, nil), SQLITE_OK)
    }
    func testCreateRetryReopenAndJSONRoundTripKeepEveryFieldAndStableID() throws {
        let value = entry(), repository = repo()
        try repository.save(value, replacing: nil); try repository.save(value, replacing: nil)
        XCTAssertEqual(try repository.entry(id: value.id, category: value.categoryID), value)
        XCTAssertEqual(try repo().entry(id: value.id, category: value.categoryID), value)
        XCTAssertEqual(try repository.managedSummaries(category: nil, query: "100%").count, 1)
        let decoded = try JSONDecoder().decode(PromptEntry.self, from: JSONEncoder().encode(value))
        let other = SQLitePromptRepository(url: dir.appendingPathComponent("restored.sqlite3"))
        try other.save(decoded, replacing: nil)
        XCTAssertEqual(try other.entry(id: value.id, category: value.categoryID), value)
    }
    func testEditMovesCategoryAndRefusesStaleOverwrite() throws {
        let repository = repo(), first = entry()
        try repository.save(first, replacing: nil)
        let changed = entry(category: "debugging", title: "修改后")
        try repository.save(changed, replacing: first)
        XCTAssertNil(try repository.entry(id: first.id, category: first.categoryID))
        XCTAssertEqual(try repo().entry(id: changed.id, category: changed.categoryID), changed)
        XCTAssertThrowsError(try repository.save(entry(title: "过期窗口"), replacing: first))
        XCTAssertEqual(try repository.entry(id: changed.id, category: changed.categoryID), changed)
    }
    func testValidationAndFailedTransactionPreserveDraftAndDoNotCommitPartialRows() throws {
        let repository = repo(), value = entry()
        try repository.storeDraft(value, original: nil)
        XCTAssertThrowsError(try repository.save(entry(title: "  "), replacing: nil))
        try sql("CREATE TRIGGER fail_save BEFORE INSERT ON prompts BEGIN SELECT RAISE(ABORT,'test'); END")
        XCTAssertThrowsError(try repository.save(value, replacing: nil))
        XCTAssertNil(try repository.entry(id: value.id, category: value.categoryID))
        XCTAssertEqual(try repo().editorDraft()?.entry, value)
        try sql("DROP TRIGGER fail_save")
        try repository.save(value, replacing: nil)
        XCTAssertNil(try repository.editorDraft())
    }
    func testDraftRoundTripKeepsOriginalAndUnsavedEditsAcrossRestart() throws {
        let original = entry(), changed = entry(title: "尚未提交")
        try repo().storeDraft(changed, original: original)
        XCTAssertEqual(try repo().editorDraft(), EditorDraft(entry: changed, original: original))
        try repo().discardDraft(); XCTAssertNil(try repo().editorDraft())
    }
    func testSearchIsLiteralScopedAndDoesNotSearchBody() throws {
        let repository = repo(); try repository.save(entry(), replacing: nil)
        XCTAssertEqual(try repository.managedSummaries(category: "coding", query: "%_").count, 1)
        XCTAssertTrue(try repository.managedSummaries(category: "review", query: "%_").isEmpty)
        XCTAssertTrue(try repository.managedSummaries(category: nil, query: "' OR 1=1 --").isEmpty)
        XCTAssertTrue(try repository.managedSummaries(category: nil, query: "quoted").isEmpty)
    }
    func testUsagePersistsOnlyExplicitEventsAndAggregatesCorrectly() throws {
        let repository = repo(), value = entry(), now = Date()
        try repository.recordUsage(value, kind: .copy, date: now.addingTimeInterval(-86400))
        try repository.recordUsage(value, kind: .insert, date: now)
        let records = try repo().usage(since: nil), summary = UsageSummary(records: records)
        XCTAssertEqual(summary.total, 2); XCTAssertEqual(summary.copies, 1); XCTAssertEqual(summary.insertions, 1)
        XCTAssertEqual(summary.promptCount, 1); XCTAssertEqual(summary.categoryCounts["coding"], 2)
        XCTAssertEqual(summary.ranks.first?.total, 2)
        XCTAssertEqual(try repository.usage(since: now.addingTimeInterval(-10)).count, 1)
    }
    func testAuxiliaryStateKeepsContentSchemaV1AndReadOnlyRollbackQueries() throws {
        let repository = repo(), value = entry()
        try repository.save(value, replacing: nil); try repository.recordUsage(value, kind: .copy, date: Date())
        var db: OpaquePointer?; XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK); defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW); XCTAssertEqual(sqlite3_column_int(stmt, 0), 1); sqlite3_finalize(stmt)
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('usage_events','editor_drafts')", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW); XCTAssertEqual(sqlite3_column_int(stmt, 0), 0); sqlite3_finalize(stmt)
        XCTAssertEqual(try repo().entry(id: value.id, category: value.categoryID), value)
    }
    func testQueueFlushCommitsPendingUsageBeforeTermination() async throws {
        let repository = repo(), library = PromptLibrary(repository: repository), value = entry()
        let flushed = expectation(description: "pending usage committed")
        library.recordUsage(value, kind: .copy)
        library.flush {
            XCTAssertEqual(try? repository.usage(since: nil).count, 1)
            flushed.fulfill()
        }
        await fulfillment(of: [flushed], timeout: 2)
    }
    func testSuccessfulSaveNotifiesAfterDurableWriteOnMainThread() async throws {
        let repository = repo(), library = PromptLibrary(repository: repository), value = entry()
        let notified = expectation(description: "content notification after commit")
        let observer = NotificationCenter.default.addObserver(forName: .promptLibraryChanged, object: library, queue: nil) { note in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(note.userInfo?["id"] as? String, value.id)
            XCTAssertEqual(try? repository.entry(id: value.id, category: value.categoryID), value)
            notified.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        library.save(value, replacing: nil) { result in if case .failure(let error) = result { XCTFail(String(describing: error)) } }
        await fulfillment(of: [notified], timeout: 2)
    }
    func testMainActorTerminationExitsAfterPendingUsageIsCommitted() async throws {
        let process = Process()
        process.executableURL = Bundle.module.bundleURL.deletingLastPathComponent().appendingPathComponent("PromptInjector")
        process.arguments = ["--verify-termination", url.path]
        try process.run()
        for _ in 0..<150 {
            if !process.isRunning { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        if process.isRunning { process.terminate(); XCTFail("Termination deadlocked before draining main-queue completion"); return }
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(try repo().usage(since: nil).count, 1)
    }
}
