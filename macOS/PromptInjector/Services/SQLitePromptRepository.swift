import Foundation
import CSQLite

struct SQLiteFailure: Error, LocalizedError {
    let code: Int32
    var errorDescription: String? { "无法读取或写入本地资料库，请重试。" }
}

/// Confined to PromptLibrary's serial queue; tests may use it serially directly.
final class SQLitePromptRepository: ManagedPromptRepository {
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Prompt Injector/library.sqlite3")
    }
    private let url: URL
    private let seed: () throws -> [PromptEntry]
    private let logger: DiagnosticLog
    private var db: OpaquePointer?
    private var activityAttached = false
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
            try rows("SELECT c.id, c.name, c.symbol, (SELECT count(*) FROM prompts p WHERE p.category_id=c.id) FROM categories c ORDER BY c.sort_order, c.id") { .init(id: self.text($0, 0), name: self.text($0, 1), symbol: self.text($0, 2), entryCount: Int(sqlite3_column_int($0, 3))) }
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
    func managedSummaries(category: String?, query search: String) throws -> [ManagedSummary] {
        try query("management-list") {
            // instr treats percent, underscore and quotes literally; body fields are never searched.
            try rows("SELECT id, category_id, title, summary, source FROM prompts WHERE (? = '' OR category_id = ?) AND (? = '' OR instr(lower(title), lower(?)) > 0 OR instr(lower(summary), lower(?)) > 0) ORDER BY sort_order, id", [category ?? "", category ?? "", search, search, search]) {
                ManagedSummary(summary: .init(id: self.text($0, 0), categoryID: self.text($0, 1), title: self.text($0, 2), summary: self.text($0, 3)), source: self.text($0, 4))
            }
        }
    }
    func save(_ entry: PromptEntry, replacing original: PromptEntry?) throws {
        let start = ProcessInfo.processInfo.systemUptime
        do {
            guard !entry.id.isEmpty, !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !entry.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  PromptCategory.all.contains(where: { $0.id == entry.categoryID }) else { throw LibraryFailure.invalidFields }
            try open()
            try attachActivity()
            try execute("BEGIN IMMEDIATE")
            do {
                let current = try rows("SELECT category_id FROM prompts WHERE id=?", [entry.id]) { self.text($0, 0) }.first
                let existing = try current.flatMap { try self.entry(id: entry.id, category: $0) }
                if let original {
                    guard original.id == entry.id, existing == original || existing == entry else { throw LibraryFailure.conflict }
                } else if let existing, existing != entry { throw LibraryFailure.conflict }
                let fields = [entry.categoryID, entry.title, entry.summary, entry.originalExperience, entry.source, entry.explanation, entry.prompt, entry.id]
                if existing != nil {
                    try execute("UPDATE prompts SET category_id=?,title=?,summary=?,original_experience=?,source=?,explanation=?,prompt=? WHERE id=?", fields)
                } else {
                    try execute("INSERT INTO prompts(category_id,title,summary,original_experience,source,explanation,prompt,id,sort_order) VALUES(?,?,?,?,?,?,?,?,(SELECT coalesce(max(sort_order),-1)+1 FROM prompts))", fields)
                }
                try execute("DELETE FROM activity.editor_drafts WHERE slot='editor'")
                try execute("COMMIT")
                logger.write(.storageSaved, fields: .init(stage: original == nil ? "create" : "edit", elapsedMilliseconds: elapsed(start), rowCount: 1))
            } catch { try? execute("ROLLBACK"); throw error }
        } catch {
            logger.write(.storageFailed, level: .error, fields: .init(stage: "save", systemCode: errorCode(error), elapsedMilliseconds: elapsed(start)))
            throw error
        }
    }
    // Optional UI state and usage live in a companion SQLite file; the v1 content schema stays readable by v0.1.
    private func attachActivity() throws {
        try open()
        guard !activityAttached else { return }
        let file = url.deletingPathExtension().lastPathComponent + "-activity.sqlite3"
        try execute("ATTACH DATABASE ? AS activity", [url.deletingLastPathComponent().appendingPathComponent(file).path])
        do {
            try execute("BEGIN IMMEDIATE")
            try execute("CREATE TABLE IF NOT EXISTS activity.editor_drafts(slot TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS activity.usage_events(id TEXT PRIMARY KEY NOT NULL, prompt_id TEXT NOT NULL, category_id TEXT NOT NULL, title TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('copy','insert')), created_at REAL NOT NULL)")
            try execute("CREATE INDEX IF NOT EXISTS activity.usage_date ON usage_events(created_at)")
            try execute("COMMIT")
            activityAttached = true
        } catch { try? execute("ROLLBACK"); try? execute("DETACH DATABASE activity"); throw error }
    }
    func storeDraft(_ entry: PromptEntry, original: PromptEntry?) throws {
        do {
            try attachActivity()
            let payload = String(decoding: try JSONEncoder().encode(EditorDraft(entry: entry, original: original)), as: UTF8.self)
            try execute("INSERT INTO activity.editor_drafts VALUES('editor',?) ON CONFLICT(slot) DO UPDATE SET payload=excluded.payload", [payload])
            logger.write(.draftSaved, fields: .init(stage: "local-draft"))
        } catch { logger.write(.storageFailed, level: .error, fields: .init(stage: "draft", systemCode: errorCode(error))); throw error }
    }
    func editorDraft() throws -> EditorDraft? {
        try query("draft-read") {
            try attachActivity()
            return try rows("SELECT payload FROM activity.editor_drafts WHERE slot='editor'") { try JSONDecoder().decode(EditorDraft.self, from: Data(self.text($0, 0).utf8)) }
        }.first
    }
    func discardDraft() throws { try attachActivity(); try execute("DELETE FROM activity.editor_drafts WHERE slot='editor'") }
    func recordUsage(_ entry: PromptEntry, kind: UsageKind, date: Date) throws {
        do {
            try attachActivity()
            try execute("INSERT INTO activity.usage_events VALUES(?,?,?,?,?,?)", [UUID().uuidString, entry.id, entry.categoryID, entry.title, kind.rawValue, String(date.timeIntervalSince1970)])
            logger.write(.usageRecorded, fields: .init(stage: kind.rawValue, rowCount: 1))
        } catch { logger.write(.storageFailed, level: .error, fields: .init(stage: "usage", systemCode: errorCode(error))); throw error }
    }
    func usage(since: Date?) throws -> [UsageRecord] {
        try query("usage") {
            try attachActivity()
            return try rows("SELECT prompt_id,category_id,title,kind,created_at FROM activity.usage_events WHERE created_at>=? ORDER BY created_at,id", [String(since?.timeIntervalSince1970 ?? 0)]) {
                let date = sqlite3_column_double($0, 4)
                let category = self.text($0, 1)
                guard let kind = UsageKind(rawValue: self.text($0, 3)), date.isFinite,
                      PromptCategory.all.contains(where: { $0.id == category }) else { throw SQLiteFailure(code: SQLITE_CORRUPT) }
                return UsageRecord(promptID: self.text($0, 0), categoryID: category, title: self.text($0, 2), kind: kind, date: Date(timeIntervalSince1970: date))
            }
        }
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
    private func rows<T>(_ sql: String, _ values: [String] = [], decode: (OpaquePointer) throws -> T) throws -> [T] {
        let stmt = try statement(sql, values); defer { sqlite3_finalize(stmt) }
        var result: [T] = []
        while true {
            let code = sqlite3_step(stmt)
            if code == SQLITE_DONE { return result }
            guard code == SQLITE_ROW else { throw SQLiteFailure(code: code) }
            result.append(try decode(stmt))
        }
    }
    private func text(_ stmt: OpaquePointer, _ column: Int32) -> String {
        guard let bytes = sqlite3_column_text(stmt, column) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(stmt, column))), as: UTF8.self)
    }
}
