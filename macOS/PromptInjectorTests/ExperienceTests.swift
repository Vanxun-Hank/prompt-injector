import XCTest
import CSQLite
@testable import PromptInjector

@MainActor final class ControlledExperienceService: ExperienceServing {
    var identifyCalls: [(String, CheckedContinuation<[ExperienceItem], Error>)] = []
    var discussionCalls: [(ExperienceItem, CheckedContinuation<String, Error>)] = []
    var organizeCalls: [(ExperienceItem, [PromptCategory], CheckedContinuation<GeneratedPrompt, Error>)] = []
    var fetched: [URL] = []
    var page = "原文甲。\n原文乙。"
    func fetch(_ url: URL) async throws -> String { fetched.append(url); return page }
    func identify(_ text: String) async throws -> [ExperienceItem] { try await withCheckedThrowingContinuation { identifyCalls.append((text, $0)) } }
    func discuss(_ item: ExperienceItem, source: String, context: String) async throws -> String { try await withCheckedThrowingContinuation { discussionCalls.append((item, $0)) } }
    func organize(_ item: ExperienceItem, source: String, context: String, categories: [PromptCategory]) async throws -> GeneratedPrompt { try await withCheckedThrowingContinuation { organizeCalls.append((item, categories, $0)) } }
}

final class ExperienceTests: XCTestCase {
    func session() -> ExperienceSession {
        var s = ExperienceSession(); s.raw = "仅能复现时，先测试。\n先交代改动和影响。"; s.source = "https://x.com/HiTw93/status/2115366100221501540"
        s.input = s.raw; s.items = [.init(title: "先验证再修复", original: "仅能复现时，先测试。"), .init(title: "动手前说明", original: "先交代改动和影响。")]
        s.currentID = s.items[0].id; return s
    }
    func candidate(_ title: String = "先验证再修复", name: String? = nil) -> GeneratedPrompt {
        .init(title: title, summary: "满足适用条件时", explanation: "原文方法\n保留前提。\n\n讨论补充\n用户确认的理解。", prompt: "保持原文条件，执行当前指令。", categoryID: name == nil ? "coding" : nil, newCategoryName: name)
    }
    func repository() -> (URL, SQLitePromptRepository) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (dir, SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")))
    }
    func testExtractionRejectsRewrittenQuotesDuplicateQuotesAndUnknownFields() throws {
        let raw = "仅在可复现时先写测试。\n不要虚构来源。"
        func data(_ rows: [[String: String]]) throws -> Data { try JSONSerialization.data(withJSONObject: ["experiences": rows]) }
        let good = try data([["title": "先写测试", "original": "仅在可复现时先写测试。"], ["title": "保留出处", "original": "不要虚构来源。"]])
        let items = try DeepSeekClient.decodeExperiences(good, original: raw)
        XCTAssertEqual(items.map(\.original).joined(separator: "\n"), raw); XCTAssertNotEqual(items[0].id, items[1].id)
        XCTAssertThrowsError(try DeepSeekClient.decodeExperiences(data([["title": "无条件测试", "original": "一律先写测试。"]]), original: raw))
        XCTAssertThrowsError(try DeepSeekClient.decodeExperiences(data([["title": "一", "original": raw], ["title": "二", "original": raw]]), original: raw))
        XCTAssertThrowsError(try DeepSeekClient.decodeExperiences(data([["title": "一", "original": raw, "source": "虚构作者"]]), original: raw))
    }
    func testBatchIsAtomicDeduplicatesCategoryPreservesLegacyDraftAndHistoryAcrossRestart() throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let legacy = try XCTUnwrap(PromptSeed.entries().first); try repo.storeDraft(legacy, original: legacy)
        try repo.recordUsage(legacy, kind: .insert, date: Date())
        var s = session(); s.revision = 4
        for i in s.items.indices { s.items[i].selected = true; s.items[i].candidate = candidate("第\(i)条", name: i == 0 ? " 模型方法 " : "模型方法"); s.items[i].input = "未发送问题" }
        try repo.storeExperienceDraft(s)
        var db: OpaquePointer?; XCTAssertEqual(sqlite3_open(dir.appendingPathComponent("library.sqlite3").path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        let trigger = "CREATE TRIGGER fail_second BEFORE INSERT ON prompts WHEN NEW.title='第1条' BEGIN SELECT RAISE(ABORT,'fixture'); END"
        XCTAssertEqual(sqlite3_exec(db, trigger, nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try repo.saveExperiences(s))
        XCTAssertEqual(try repo.categories().count, 5); XCTAssertEqual(try repo.experienceDraft(), s)
        XCTAssertEqual(try repo.managedSummaries(category: nil, query: "第0条").count, 0)
        XCTAssertEqual(sqlite3_exec(db, "DROP TRIGGER fail_second", nil, nil, nil), SQLITE_OK)
        let saved = try repo.saveExperiences(s)
        XCTAssertEqual(saved.count, 2); XCTAssertEqual(saved[0].categoryID, saved[1].categoryID)
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertEqual(try reopened.categories().count, 6); XCTAssertNil(try reopened.experienceDraft())
        XCTAssertEqual(try reopened.editorDraft()?.entry, legacy); XCTAssertEqual(try reopened.usage(since: nil).count, 1)
        for (value, item) in zip(saved, s.items) {
            XCTAssertEqual(try reopened.entry(id: value.id, category: value.categoryID), value)
            XCTAssertEqual(value.originalExperience, item.original); XCTAssertEqual(value.source, s.source); XCTAssertEqual(value.id, item.id)
        }
        XCTAssertThrowsError(try reopened.storeExperienceDraft(s)); XCTAssertNil(try reopened.experienceDraft())
        XCTAssertThrowsError(try reopened.saveExperiences(s)); XCTAssertEqual(try reopened.categories().last?.entryCount, 2)
    }
    func testPartialBatchRetainsUncheckedDiscussionAndRejectsStaleDraft() throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        var s = session(); s.items[0].selected = true; s.items[0].candidate = candidate()
        s.items[1].input = "尚未发出的理解"; s.items[1].messages = [.init(role: .user, content: "这句话是什么意思？")]
        try repo.storeExperienceDraft(s); _ = try repo.saveExperiences(s)
        XCTAssertEqual(try repo.experienceDraft(), s.remaining)
        XCTAssertThrowsError(try repo.storeExperienceDraft(s)); XCTAssertEqual(try repo.experienceDraft()?.items[0].input, "尚未发出的理解")
    }
    func testDeleteKeepsHistoryAndCategoryRejectsStaleSnapshotAndDoesNotResurrectOnRestart() throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let original = try XCTUnwrap(PromptSeed.entries().first); try repo.recordUsage(original, kind: .copy, date: Date())
        var edited = original; edited = .init(id: original.id, categoryID: original.categoryID, title: "修改后", summary: original.summary, originalExperience: original.originalExperience, source: original.source, explanation: original.explanation, prompt: original.prompt)
        try repo.save(edited, replacing: original); XCTAssertThrowsError(try repo.deleteEntry(original))
        try repo.deleteEntry(edited)
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertNil(try reopened.entry(id: edited.id, category: edited.categoryID)); XCTAssertEqual(try reopened.categories().count, 5)
        XCTAssertEqual(try reopened.usage(since: nil).first?.title, original.title)
    }
    @MainActor private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<300 { if condition() { return }; try await Task.sleep(nanoseconds: 10_000_000) }
        XCTFail("Experience flow timed out")
    }
    @MainActor func testDiscussionSelectionDraftRetryCancellationAndLateResponse() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), model = ExperienceController(session: session(), library: PromptLibrary(repository: repo), service: service)
        let ids = model.session.items.map(\.id)
        model.choose(ids[0]); try await until { service.discussionCalls.count == 1 }
        XCTAssertEqual(try repo.experienceDraft()?.items[0].messages.last?.delivery, .pending)
        model.toggle(ids[1]); XCTAssertEqual(model.current?.id, ids[0]); XCTAssertEqual(service.discussionCalls.count, 1)
        model.changeInput("请求中继续输入")
        model.cancel(); service.discussionCalls[0].1.resume(returning: "迟到，不得覆盖")
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(model.current?.input, "请求中继续输入"); XCTAssertEqual(model.current?.messages.count, 1)
        model.choose(ids[1]); try await until { service.discussionCalls.count == 2 }
        service.discussionCalls[1].1.resume(throwing: URLError(.timedOut)); try await until { !model.busy }
        XCTAssertTrue(model.canRetry); XCTAssertTrue(model.status.contains("超时"))
        let count = model.current?.messages.count
        model.send(); try await until { service.discussionCalls.count == 3 }
        service.discussionCalls[2].1.resume(returning: "这是当前经验的解释。")
        try await until { !model.busy }
        XCTAssertEqual(model.current?.messages.count, (count ?? 0) + 1)
        model.choose(ids[0]); XCTAssertEqual(service.discussionCalls.count, 3)
        XCTAssertEqual(model.current?.input, "请求中继续输入"); XCTAssertTrue(model.session.items[1].selected)
        try await model.finish()
        let reopened = try XCTUnwrap(repo.experienceDraft())
        XCTAssertEqual(reopened.items[0].input, "请求中继续输入"); XCTAssertEqual(reopened.items[1].messages.last?.content, "这是当前经验的解释。")
    }
    @MainActor func testFreshCategoriesAndFailedBatchPreserveCandidateEdits() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), library = PromptLibrary(repository: repo)
        var s = session(); s.items.indices.forEach { s.items[$0].selected = true }
        let model = ExperienceController(session: s, library: library, service: service)
        model.organize(); try await until { service.organizeCalls.count == 1 }
        let entry = GenerationTests().entry()
        _ = try repo.saveDraft(EditorDraft(entry: entry, original: nil, newCategoryName: "模型选择"))
        service.organizeCalls[0].2.resume(returning: candidate())
        try await until { service.organizeCalls.count == 2 }
        XCTAssertEqual(service.organizeCalls[1].1.last?.name, "模型选择")
        service.organizeCalls[1].2.resume(throwing: URLError(.notConnectedToInternet)); try await until { !model.busy }
        model.updateCandidate(s.items[0].id, candidate("手工修改的候选"))
        model.organize(); try await until { service.organizeCalls.count == 3 }
        XCTAssertEqual(service.organizeCalls[2].0.id, s.items[1].id)
        model.cancel(); service.organizeCalls[2].2.resume(returning: candidate("不应采用"))
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(model.session.items[0].candidate?.title, "手工修改的候选"); XCTAssertNil(model.session.items[1].candidate)
        try await model.finish()
    }
    @MainActor func testURLReadIsCachedForRetryButChangingInputInvalidatesIt() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(); var s = ExperienceSession(); s.input = "https://example.com/article"
        let model = ExperienceController(session: s, library: PromptLibrary(repository: repo), service: service)
        model.send(); try await until { service.identifyCalls.count == 1 }
        XCTAssertEqual(try repo.experienceDraft()?.raw, service.page)
        service.identifyCalls[0].1.resume(throwing: GenerationFailure.invalidOutput); try await until { !model.busy }
        model.send(); try await until { service.identifyCalls.count == 2 }; XCTAssertEqual(service.fetched.count, 1)
        model.changeInput("新的手动正文"); service.identifyCalls[1].1.resume(returning: [.init(title: "旧链接经验", original: "原文甲。")])
        try await until { !model.busy }; XCTAssertTrue(model.session.items.isEmpty); XCTAssertEqual(model.session.input, "新的手动正文")
        XCTAssertEqual(model.session.raw, ""); try await model.finish()
    }
    func testSourceLogosUseExactHostBoundariesAndRejectCredentialsAndLocalLinks() {
        XCTAssertEqual(SourceLink.platform("https://x.com/user/status/1").name, "X")
        XCTAssertEqual(SourceLink.platform("https://github.com/openai/codex").name, "GitHub")
        XCTAssertEqual(SourceLink.platform("https://www.reddit.com/r/test").name, "Reddit")
        XCTAssertNotEqual(SourceLink.platform("https://github.com.evil.test/").name, "GitHub")
        for text in ["file:///etc/passwd", "https://user:secret@example.com", "http://127.0.0.1", "http://172.16.1.1", "http://localhost"] { XCTAssertNil(SourceLink.url(text)) }
    }
    @MainActor func testInterruptedRequestCanReopenAndPersistWithoutRevisionConflict() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        var draft = session(); draft.items[0].messages = [.init(role: .user, content: "未完成的请求", delivery: .pending)]
        try repo.storeExperienceDraft(draft)
        let restored = ExperienceController(session: try XCTUnwrap(repo.experienceDraft()), library: PromptLibrary(repository: repo), service: ControlledExperienceService())
        XCTAssertEqual(restored.current?.messages.last?.delivery, .failed)
        try await restored.persist()
        XCTAssertEqual(try repo.experienceDraft()?.items[0].messages.last?.delivery, .failed)
    }
    @MainActor func testFirstDiscussionNeverSendsOrReplacesUnsentInput() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), model = ExperienceController(session: session(), library: PromptLibrary(repository: repo), service: service)
        let ids = model.session.items.map(\.id)
        model.changeInput("尚未准备发送的问题")
        model.choose(ids[1]); try await until { service.discussionCalls.count == 1 }
        model.choose(ids[0]); try await until { service.discussionCalls.count == 2 }
        XCTAssertEqual(model.current?.input, "尚未准备发送的问题")
        XCTAssertNotEqual(service.discussionCalls[1].0.messages.last?.content, "尚未准备发送的问题")
        service.discussionCalls[0].1.resume(returning: "旧条回复")
        service.discussionCalls[1].1.resume(returning: "当前解释")
        try await until { !model.busy }
        try await model.finish()
        XCTAssertEqual(try repo.experienceDraft()?.items[0].input, "尚未准备发送的问题")
    }
    @MainActor func testMessageLimitRefusesNewTurnWithoutBreakingDraftOrExit() async throws {
        for count in [499, 500] {
            let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
            var s = session()
            s.items[0].messages = (0..<count).map { .init(role: $0 % 2 == 0 ? .user : .assistant, content: "已有消息\($0)") }
            let service = ControlledExperienceService(), model = ExperienceController(session: s, library: PromptLibrary(repository: repo), service: service)
            model.changeInput("未发送的问题"); model.send()
            try await until { !model.busy || !service.discussionCalls.isEmpty }
            if let call = service.discussionCalls.first { call.1.resume(returning: "本轮回答"); try await until { !model.busy } }
            XCTAssertTrue(service.discussionCalls.isEmpty)
            XCTAssertEqual(model.current?.input, "未发送的问题"); XCTAssertEqual(model.current?.messages.count, count)
            do { try await model.finish() } catch { XCTFail("Limit must not make a draft impossible to persist") }
        }
    }
    func testMultilineAndUnknownFetchFormatsPreserveAllOriginalText() throws {
        let url = URL(string: "https://x.com/author/status/1")!
        let multiline = "# X 上的作者：“第一行。 第二行。”\n\n- 第一行。\n  第二行。\n- 回复内容。"
        XCTAssertEqual(SourceLink.articleText(multiline, url: url), multiline)
        let unknown = "# 一个标题\n\n第一段。\n第二段。"
        XCTAssertEqual(SourceLink.articleText(unknown, url: url), unknown)
        let truncatedTitle = "# X 上的作者：“第一行。”\n\n- 第一行。\n  第二行。"
        XCTAssertEqual(SourceLink.articleText(truncatedTitle, url: url), truncatedTitle)
    }
}
