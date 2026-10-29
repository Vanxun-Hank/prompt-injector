import XCTest
import CSQLite
@testable import PromptInjector

final class SQLiteRepositoryTests: XCTestCase {
    private var dir: URL!
    private var logger: DiagnosticLog!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("PI-SQL-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        logger = DiagnosticLog(directory: dir.appendingPathComponent("logs"))
    }
    override func tearDownWithError() throws { logger.flush(); try FileManager.default.removeItem(at: dir) }
    private var url: URL { dir.appendingPathComponent("library.sqlite3") }
    private func repository(seed: @escaping () throws -> [PromptEntry] = PromptSeed.entries) -> SQLitePromptRepository {
        SQLitePromptRepository(url: url, logger: logger, seed: seed)
    }
    private func sql(_ text: String) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK); defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, text, nil, nil, nil), SQLITE_OK)
    }
    func testFirstLaunchRoundTripAndRestartDoNotReseedOrChangeStableIDs() throws {
        let seeds = try PromptSeed.entries()
        do {
            let repo = repository()
            XCTAssertEqual(try repo.categories(), PromptCategory.all)
            for entry in seeds { XCTAssertEqual(try repo.entry(id: entry.id, category: entry.categoryID), entry) }
        }
        let reopened = repository { XCTFail("Seed must not be read on restart"); return [] }
        let summaries = try PromptCategory.all.flatMap { try reopened.summaries(in: $0.id) }
        XCTAssertEqual(Set(summaries.map(\.id)), Set(seeds.map(\.id)))
        XCTAssertEqual(summaries.count, seeds.count)
    }
    func testCategoryAndListNeverReadBodyColumns() throws {
        let repo = repository()
        repo.didOpen = { db in
            sqlite3_set_authorizer(db, { _, action, table, column, _, _ in
                guard action == SQLITE_READ, let table, let column else { return SQLITE_OK }
                let name = String(cString: table), field = String(cString: column)
                if name == "prompts" && ["original_experience", "source", "explanation", "prompt"].contains(field) { return SQLITE_DENY }
                return SQLITE_OK
            }, nil)
        }
        XCTAssertEqual(try repo.categories().count, 5)
        XCTAssertEqual(try repo.summaries(in: "debugging").count, 3)
        XCTAssertThrowsError(try repo.entry(id: "debug-root-cause", category: "debugging"))
    }
    func testExactUnicodeMultilineAndNULRoundTripAndBoundParameters() throws {
        let body = "中文😀\n```swift\nlet x = 'quote'\n```\n\0尾部"
        let entry = PromptEntry(id: "x' OR 1=1 --", categoryID: "coding", title: "标题", summary: "摘要", originalExperience: body, source: "来源", explanation: body, prompt: body)
        let repo = repository { [entry] }
        XCTAssertEqual(try repo.entry(id: entry.id, category: "coding"), entry)
        XCTAssertNil(try repo.entry(id: entry.id, category: "debugging"))
        XCTAssertNil(try repo.entry(id: "' OR 1=1 --", category: "coding"))
    }
    func testExistingEditsAndDeletionsSurviveRestartWithoutResurrection() throws {
        do { _ = try repository().categories() }
        try sql("UPDATE prompts SET title='已修改' WHERE id='debug-root-cause'; DELETE FROM prompts WHERE id='debug-hypotheses';")
        let repo = repository { XCTFail("Must not reseed existing database"); return [] }
        XCTAssertEqual(try repo.entry(id: "debug-root-cause", category: "debugging")?.title, "已修改")
        XCTAssertNil(try repo.entry(id: "debug-hypotheses", category: "debugging"))
        XCTAssertEqual(try repo.summaries(in: "debugging").count, 2)
    }
    func testFailedSeedRollsBackAndNextOpenCanRecover() throws {
        let seeds = try PromptSeed.entries()
        let bad = repository { [seeds[0], seeds[0]] }
        XCTAssertThrowsError(try bad.categories())
        XCTAssertEqual(try repository().categories().count, 5)
        XCTAssertEqual(try repository().summaries(in: "debugging").count, 3)
    }
    func testCorruptAndNewerDatabasesAreNeverDeletedOrReplaced() throws {
        let original = Data("not a database".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try repository().categories())
        XCTAssertEqual(try Data(contentsOf: url), original)
        try FileManager.default.removeItem(at: url)
        try sql("PRAGMA user_version=99; CREATE TABLE future_data(value TEXT); INSERT INTO future_data VALUES ('keep');")
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try repository().categories())
        XCTAssertEqual(try Data(contentsOf: url), before)
    }
    func testEmptyAndMissingCategoryReturnEmptyNotUnrelatedData() throws {
        let repo = repository { [] }
        XCTAssertEqual(try repo.categories().count, 5)
        XCTAssertTrue(try repo.summaries(in: "coding").isEmpty)
        XCTAssertTrue(try repo.summaries(in: "missing").isEmpty)
        XCTAssertNil(try repo.entry(id: "missing", category: "coding"))
    }
    func testReadFailureIsLoggedWithoutSourceOrPromptContent() throws {
        let repo = repository()
        _ = try repo.categories()
        try sql("DROP TABLE prompts")
        XCTAssertThrowsError(try repo.summaries(in: "coding"))
        // Verify with a dedicated synchronous logger flush boundary.
        let logger = DiagnosticLog(directory: dir.appendingPathComponent("checklogs"))
        let broken = SQLitePromptRepository(url: url, logger: logger)
        XCTAssertThrowsError(try broken.summaries(in: "coding")); logger.flush()
        let logs = try String(contentsOf: dir.appendingPathComponent("checklogs/events.jsonl"), encoding: .utf8)
        XCTAssertTrue(logs.contains("storage.failed")); XCTAssertTrue(logs.contains("\"stage\":\"list\""))
        XCTAssertFalse(logs.contains("先定位根因"))
    }
    func testSimultaneousFirstOpenIsAtomicAndDoesNotDuplicateSeed() throws {
        let queue = DispatchQueue(label: "sqlite-concurrent-test", attributes: .concurrent)
        let group = DispatchGroup()
        for _ in 0..<2 {
            group.enter(); queue.async {
                defer { group.leave() }
                do {
                    let items = try self.repository().summaries(in: "debugging")
                    XCTAssertEqual(items.count, 3)
                } catch { XCTFail("Concurrent open failed: \(error)") }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(try repository().summaries(in: "debugging").count, 3)
    }
}
