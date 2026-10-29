import Foundation
import CSQLite

struct SQLiteFailure: Error, LocalizedError {
    let code: Int32
    var errorDescription: String? { "无法读取资料库，请重试。" }
}

/// Confined to PromptLibrary's serial queue; tests may use it serially directly.
final class SQLitePromptRepository: PromptRepository {
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Prompt Injector/library.sqlite3")
    }
    private let url: URL
    private let seed: () throws -> [PromptEntry]
    private let logger: DiagnosticLog
    private var db: OpaquePointer?
    // Test seam for SQLite's column authorizer, installed after migration and before any page query.
    var didOpen: ((OpaquePointer) -> Void)?
    init(url: URL, logger: DiagnosticLog = .shared, seed: @escaping () throws -> [PromptEntry] = PromptSeed.entries) {
        self.url = url; self.logger = logger; self.seed = seed
    }
    deinit { if let db { sqlite3_close(db) } }

    private func open() throws {
        guard db == nil else { return }
        let start = ProcessInfo.processInfo.systemUptime
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            var handle: OpaquePointer?
            let code = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
            guard code == SQLITE_OK, let handle else {
                if let handle { sqlite3_close(handle) }
                throw SQLiteFailure(code: code)
            }
            db = handle
            sqlite3_busy_timeout(handle, 1500)
            try execute("PRAGMA foreign_keys = ON")
            try execute("BEGIN IMMEDIATE")
            do {
                let version = try rows("PRAGMA user_version") { sqlite3_column_int($0, 0) }.first ?? 0
                guard version <= 1 else { throw LibraryFailure.incompatibleVersion }
                if version == 0 {
                    // Never seed on top of an unrelated or partially initialized database.
                    let existing = try rows("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'") { self.text($0, 0) }
                    guard existing.isEmpty else { throw LibraryFailure.incompatibleVersion }
                    try migrate()
                    logger.write(.storageMigrating, fields: .init(stage: "seed-v1"))
                }
                try execute("COMMIT")
            } catch { try? execute("ROLLBACK"); throw error }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            logger.write(.storageOpened, fields: .init(elapsedMilliseconds: elapsed(start)))
            didOpen?(handle)
        } catch {
            if let db { sqlite3_close(db) }; db = nil
            logger.write(.storageFailed, level: .error, fields: .init(stage: "open", systemCode: errorCode(error), elapsedMilliseconds: elapsed(start)))
            throw error
        }
    }
    private func migrate() throws {
        let entries = try seed()
        guard Set(entries.map(\.id)).count == entries.count,
              entries.allSatisfy({ entry in !entry.id.isEmpty && !entry.title.isEmpty && !entry.prompt.isEmpty && PromptCategory.all.contains(where: { $0.id == entry.categoryID }) }) else {
            throw LibraryFailure.invalidSeed
        }
        try execute("CREATE TABLE categories (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, symbol TEXT NOT NULL, sort_order INTEGER NOT NULL UNIQUE)")
        try execute("CREATE TABLE prompts (id TEXT PRIMARY KEY NOT NULL, category_id TEXT NOT NULL REFERENCES categories(id), title TEXT NOT NULL, summary TEXT NOT NULL, original_experience TEXT NOT NULL, source TEXT NOT NULL, explanation TEXT NOT NULL, prompt TEXT NOT NULL, sort_order INTEGER NOT NULL UNIQUE)")
        try execute("CREATE INDEX prompts_category_order ON prompts(category_id, sort_order)")
        for (index, category) in PromptCategory.all.enumerated() {
            try execute("INSERT INTO categories VALUES (?, ?, ?, ?)", [category.id, category.name, category.symbol, String(index)])
        }
        for (index, entry) in entries.enumerated() {
            try execute("INSERT INTO prompts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", [entry.id, entry.categoryID, entry.title, entry.summary, entry.originalExperience, entry.source, entry.explanation, entry.prompt, String(index)])
        }
        try execute("PRAGMA user_version = 1")
        // Transaction commit is logged by the caller only after COMMIT succeeds.
    }
    func categories() throws -> [PromptCategory] {
        try query("categories") {
            try rows("SELECT id, name, symbol FROM categories ORDER BY sort_order, id") { .init(id: self.text($0, 0), name: self.text($0, 1), symbol: self.text($0, 2)) }
        }
    }
    func summaries(in category: String) throws -> [PromptSummary] {
        try query("list") {
            try rows("SELECT id, category_id, title, summary FROM prompts WHERE category_id = ? ORDER BY sort_order, id", [category]) {
                .init(id: self.text($0, 0), categoryID: self.text($0, 1), title: self.text($0, 2), summary: self.text($0, 3))
            }
        }
    }
    func entry(id: String, category: String) throws -> PromptEntry? {
        let entries: [PromptEntry] = try query("detail") {
            try rows("SELECT id, category_id, title, summary, original_experience, source, explanation, prompt FROM prompts WHERE id = ? AND category_id = ?", [id, category]) {
                .init(id: self.text($0, 0), categoryID: self.text($0, 1), title: self.text($0, 2), summary: self.text($0, 3), originalExperience: self.text($0, 4), source: self.text($0, 5), explanation: self.text($0, 6), prompt: self.text($0, 7))
            }
        }
        return entries.first
    }
    private func query<T>(_ layer: String, _ body: () throws -> [T]) throws -> [T] {
        let start = ProcessInfo.processInfo.systemUptime
        do {
            try open()
            let result = try body()
            logger.write(.storageQuery, fields: .init(stage: layer, elapsedMilliseconds: elapsed(start), rowCount: result.count))
            return result
        } catch {
            logger.write(.storageFailed, level: .error, fields: .init(stage: layer, systemCode: errorCode(error), elapsedMilliseconds: elapsed(start)))
            throw error
        }
    }
    private func elapsed(_ start: TimeInterval) -> Int { Int((ProcessInfo.processInfo.systemUptime - start) * 1000) }
    private func errorCode(_ error: Error) -> Int { Int((error as? SQLiteFailure)?.code ?? Int32((error as NSError).code)) }
    private func statement(_ sql: String, _ values: [String]) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let code = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard code == SQLITE_OK, let stmt else { throw SQLiteFailure(code: code) }
        do {
            for (index, value) in values.enumerated() {
                // Explicit byte count preserves embedded NUL and all Unicode; SQLITE_TRANSIENT owns the bytes.
                let bound = value.withCString { sqlite3_bind_text(stmt, Int32(index + 1), $0, Int32(value.utf8.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
                guard bound == SQLITE_OK else { throw SQLiteFailure(code: bound) }
            }
            return stmt
        } catch { sqlite3_finalize(stmt); throw error }
    }
    private func execute(_ sql: String, _ values: [String] = []) throws {
        let stmt = try statement(sql, values); defer { sqlite3_finalize(stmt) }
        let code = sqlite3_step(stmt)
        guard code == SQLITE_DONE else { throw SQLiteFailure(code: code) }
    }
    private func rows<T>(_ sql: String, _ values: [String] = [], decode: (OpaquePointer) -> T) throws -> [T] {
        let stmt = try statement(sql, values); defer { sqlite3_finalize(stmt) }
        var result: [T] = []
        while true {
            let code = sqlite3_step(stmt)
            if code == SQLITE_DONE { return result }
            guard code == SQLITE_ROW else { throw SQLiteFailure(code: code) }
            result.append(decode(stmt))
        }
    }
    private func text(_ stmt: OpaquePointer, _ column: Int32) -> String {
        guard let bytes = sqlite3_column_text(stmt, column) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(stmt, column))), as: UTF8.self)
    }
}
