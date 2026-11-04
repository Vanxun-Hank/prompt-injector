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
        let raw = "仅在可复现时先写测试。\n\n不要虚构来源。"
        func data(_ rows: [[String: String]]) throws -> Data { try JSONSerialization.data(withJSONObject: ["experiences": rows]) }
        let good = try data([["title": "先写测试", "original": "仅在可复现时先写测试。"], ["title": "保留出处", "original": "不要虚构来源。"]])
        let items = try DeepSeekClient.decodeExperiences(good, original: raw)
        XCTAssertEqual(items.map(\.original).joined(separator: "\n\n"), raw); XCTAssertNotEqual(items[0].id, items[1].id)
        XCTAssertThrowsError(try DeepSeekClient.decodeExperiences(data([["title": "无条件测试", "original": "一律先写测试。"]]), original: raw))
        XCTAssertThrowsError(try DeepSeekClient.decodeExperiences(data([["title": "一", "original": raw], ["title": "二", "original": raw]]), original: raw))
        XCTAssertThrowsError(try DeepSeekClient.decodeExperiences(data([["title": "一", "original": raw, "source": "虚构作者"]]), original: raw))
    }
    func testExtractionCannotSplitOneParagraphIntoSentencesOrOmitItsConditions() throws {
        let raw = "仅当问题可复现时，先写失败测试。再修复代码。最后验证同类路径。"
        func decode(_ quotes: [String]) throws -> [ExperienceItem] {
            try DeepSeekClient.decodeExperiences(JSONSerialization.data(withJSONObject: ["experiences": quotes.map { ["title": "验证问题", "original": $0] }]), original: raw)
        }
        XCTAssertThrowsError(try decode(["仅当问题可复现时，先写失败测试。", "再修复代码。", "最后验证同类路径。"]))
        XCTAssertThrowsError(try decode(["再修复代码。最后验证同类路径。"]))
        XCTAssertEqual(try decode([raw]).first?.original, raw)
    }
    func testExtractionLocksTopLevelNumbersIncludingNestedStepsAndDuplicateEighteen() throws {
        let units = (1...20).map { number in
            number == 8 ? "8. 用脚本验证规则。\n  1. 运行脚本。\n  2. 检查结果。" : number == 18 ? "18. 先小范围试用。\n18. 再逐步发布。" : "\(number). 第\(number)条经验。"
        }
        let raw = "作者分享的经验：\n" + units.joined(separator: "\n")
        func decode(_ quotes: [String]) throws -> [ExperienceItem] {
            try DeepSeekClient.decodeExperiences(JSONSerialization.data(withJSONObject: ["experiences": quotes.map { ["title": "经验规则", "original": $0] }]), original: raw)
        }
        XCTAssertEqual(try decode(units).map(\.original), units)
        var split = units; split.replaceSubrange(7...7, with: ["8. 用脚本验证规则。", "1. 运行脚本。", "2. 检查结果。"])
        XCTAssertThrowsError(try decode(split))
        XCTAssertThrowsError(try decode(Array(units.reversed())))
        XCTAssertThrowsError(try decode(Array(units.dropLast())))
        let inline = units.enumerated().map { i, unit in i == 7 ? "8. 用脚本验证规则；运行后检查结果。" : unit.replacingOccurrences(of: "\n", with: " ") }
        let inlineRaw = "作者分享： " + inline.joined(separator: " ")
        let data = try JSONSerialization.data(withJSONObject: ["experiences": inline.map { ["title": "经验规则", "original": $0] }])
        XCTAssertEqual(try DeepSeekClient.decodeExperiences(data, original: inlineRaw).map(\.original), inline)
    }
    func testExtractionCanMergeWholeParagraphsButCannotOverlapReorderOrSkipThem() throws {
        let a = "定位可复现的问题。", b = "先写失败测试。", c = "另一条经验：说明改动影响。"
        let raw = a + "\r\n\r\n" + b + "\r\n\r\n" + c
        func decode(_ quotes: [String]) throws -> [ExperienceItem] {
            try DeepSeekClient.decodeExperiences(JSONSerialization.data(withJSONObject: ["experiences": quotes.map { ["title": "经验规则", "original": $0] }]), original: raw)
        }
        XCTAssertEqual(try decode([a + "\r\n\r\n" + b, c]).count, 2)
        XCTAssertThrowsError(try decode([b, c]))
        XCTAssertThrowsError(try decode([b, a, c]))
        XCTAssertThrowsError(try decode([a + "\r\n\r\n" + b, b + "\r\n\r\n" + c]))
    }
    func testExtractionAcceptsFlattenedNumberedListStartingDirectlyAtOne() throws {
        let units = ["1. 第一条经验。", "2. 第二条经验。"]
        let data = try JSONSerialization.data(withJSONObject: ["experiences": units.map { ["title": "经验规则", "original": $0] }])
        for raw in [units.joined(separator: " "), units.joined(separator: " ") + "\n", "作者经验：\n" + units.joined(separator: " ")] {
            XCTAssertEqual(try DeepSeekClient.decodeExperiences(data, original: raw).map(\.original), units)
        }
        let nested = "1. 一条经验，保留方法和子步骤。\n  1. 先定位。\n  2. 再验证。"
        let single = try JSONSerialization.data(withJSONObject: ["experiences": [["title": "整条经验", "original": nested]]])
        XCTAssertEqual(try DeepSeekClient.decodeExperiences(single, original: nested).count, 1)
    }
    func testExtractionKeepsTheHundredthNumberedExperienceSeparate() throws {
        let units = (1...100).map { "\($0). 第\($0)条经验。" }
        let data = try JSONSerialization.data(withJSONObject: ["experiences": units.map { ["title": "经验规则", "original": $0] }])
        for separator in ["\n", " "] {
            XCTAssertEqual(try DeepSeekClient.decodeExperiences(data, original: units.joined(separator: separator)).map(\.original), units)
        }
    }
    func testBatchIsAtomicDeduplicatesCategoryPreservesLegacyDraftAndHistoryAcrossRestart() throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let legacy = try XCTUnwrap(PromptSeed.entries().first); try repo.storeDraft(legacy, original: legacy)
        try repo.recordUsage(legacy, kind: .insert, date: Date())
        var s = session(); s.revision = 4
        for i in s.items.indices { s.items[i].selected = true; s.items[i].confirmed = true; s.items[i].candidate = candidate("第\(i)条", name: i == 0 ? " 模型方法 " : "模型方法"); s.items[i].input = "未发送问题" }
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
        var s = session(); s.items[0].selected = true; s.items[0].confirmed = true; s.items[0].candidate = candidate()
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
    @MainActor func testBoundaryFailureKeepsOriginalAndSourceForRetryAndRestart() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        var draft = ExperienceSession(); draft.input = "同一个方法先定位、再验证，不拆成三条。"; draft.source = "用户粘贴的作者原文"
        let service = ControlledExperienceService(), model = ExperienceController(session: draft, library: PromptLibrary(repository: repo), service: service)
        model.send(); try await until { service.identifyCalls.count == 1 }
        service.identifyCalls[0].1.resume(throwing: GenerationFailure.experienceBoundaries)
        try await until { !model.busy }; try await model.finish()
        XCTAssertTrue(model.status.contains("拆分结果")); XCTAssertTrue(model.session.items.isEmpty)
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertEqual(try reopened.experienceDraft()?.input, draft.input)
        XCTAssertEqual(try reopened.experienceDraft()?.raw, draft.input)
        XCTAssertEqual(try reopened.experienceDraft()?.source, draft.source)
        model.send(); try await until { service.identifyCalls.count == 2 }
        service.identifyCalls[1].1.resume(returning: [.init(title: "保留整条经验", original: draft.input)])
        try await until { !model.busy }; try await model.finish()
        XCTAssertEqual(model.session.items.count, 1); XCTAssertEqual(model.session.items[0].original, draft.input)
        XCTAssertEqual(try reopened.experienceDraft()?.source, draft.source)
    }
    @MainActor func testSelectionAndManualPromptsNeverCallNetworkAndSurviveRestart() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), model = ExperienceController(session: session(), library: PromptLibrary(repository: repo), service: service)
        let ids = model.session.items.map(\.id)
        model.choose(ids[0]); model.changePrompt("手贴甲"); model.choose(ids[1]); model.changePrompt("手贴乙")
        model.toggle(ids[0]); model.toggle(ids[1]); model.organize()
        XCTAssertEqual(model.current?.id, ids[1]); XCTAssertTrue(service.discussionCalls.isEmpty); XCTAssertTrue(service.organizeCalls.isEmpty)
        model.choose(ids[0]); XCTAssertEqual(model.current?.candidate?.prompt, "手贴甲")
        try await model.finish()
        XCTAssertEqual(try repo.experienceDraft()?.items.map { $0.candidate?.prompt }, ["手贴甲", "手贴乙"])
    }
    @MainActor func testGenerationUsesFreshCategoriesAndCannotOverwriteLaterEdits() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), model = ExperienceController(session: session(), library: PromptLibrary(repository: repo), service: service)
        model.generateCurrent(); try await until { service.organizeCalls.count == 1 }
        model.changePrompt("请求中手工粘贴")
        service.organizeCalls[0].2.resume(returning: candidate("迟到")); try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(model.current?.candidate?.prompt, "请求中手工粘贴"); XCTAssertFalse(model.busy)
        _ = try repo.saveDraft(EditorDraft(entry: GenerationTests().entry(), original: nil, newCategoryName: "模型选择"))
        model.generateCurrent(); try await until { service.organizeCalls.count == 2 }
        XCTAssertEqual(service.organizeCalls[1].1.last?.name, "模型选择")
        service.organizeCalls[1].2.resume(throwing: URLError(.timedOut)); try await until { !model.busy }
        XCTAssertTrue(model.status.contains("超时")); XCTAssertEqual(model.current?.candidate?.prompt, "请求中手工粘贴")
        model.generateCurrent(); try await until { service.organizeCalls.count == 3 }
        service.organizeCalls[2].2.resume(returning: candidate("重试成功")); try await until { !model.busy }
        XCTAssertEqual(model.current?.candidate?.prompt, "请求中手工粘贴")
        let suggestion = try XCTUnwrap(model.current?.suggestion)
        model.adoptSuggestion(model.current!.id, suggestion)
        XCTAssertEqual(model.current?.candidate?.title, "重试成功"); XCTAssertNil(model.current?.suggestion); try await model.finish()
    }
    @MainActor func testManualEntryAndReviewGateNeedNoModel() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), model = ExperienceController(session: ExperienceSession(), library: PromptLibrary(repository: repo), service: service)
        var reviews = 0; model.onReview = { reviews += 1 }
        model.beginManual(); model.changeInput("完整作者原文"); model.changeSource("https://github.com/author/project")
        model.continueManual(); XCTAssertEqual(reviews, 0)
        model.changePrompt("用户自己的指令"); try await model.finish()
        XCTAssertEqual(try repo.experienceDraft()?.manualPrompt, "用户自己的指令")
        model.continueManual(); XCTAssertEqual(reviews, 1)
        XCTAssertEqual(model.current?.original, "完整作者原文"); XCTAssertEqual(model.current?.candidate?.prompt, "用户自己的指令")
        model.toggle(model.current!.id); model.generateSelected(); XCTAssertEqual(reviews, 1)
        model.toggle(model.current!.id); model.changePrompt("  "); model.organize(); XCTAssertEqual(reviews, 1)
        XCTAssertTrue(service.identifyCalls.isEmpty); XCTAssertTrue(service.discussionCalls.isEmpty); XCTAssertTrue(service.organizeCalls.isEmpty)
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
    @MainActor func testPromptOnlyManualDraftFlushesOnImmediateClose() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let model = ExperienceController(session: ExperienceSession(), library: PromptLibrary(repository: repo), service: ControlledExperienceService())
        model.beginManual(); model.changePrompt("先粘贴 Prompt，原文稍后填写")
        try await model.finish()
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertEqual(try reopened.experienceDraft()?.manualPrompt, "先粘贴 Prompt，原文稍后填写")
        XCTAssertEqual(try reopened.experienceDraft()?.input, "")
    }
    @MainActor func testSingleIdentificationWaitsForExplicitGenerationWithExactSource() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), model = ExperienceController(session: ExperienceSession(), library: PromptLibrary(repository: repo), service: service)
        model.changeInput("只是一条完整经验。"); model.changeSource("作者来源")
        var reviews = 0; model.onReview = { reviews += 1 }
        model.send(); try await until { service.identifyCalls.count == 1 }
        service.identifyCalls[0].1.resume(returning: [.init(title: "一条经验", original: "只是一条完整经验。")])
        try await until { !model.busy }; XCTAssertTrue(service.organizeCalls.isEmpty)
        model.toggle(model.current!.id); model.generateSelected()
        try await until { service.organizeCalls.count == 1 }
        service.organizeCalls[0].2.resume(returning: candidate()); try await until { !model.busy }
        XCTAssertEqual(reviews, 0); model.organize()
        XCTAssertEqual(reviews, 1); XCTAssertEqual(model.reviewItems.count, 1)
        XCTAssertEqual(model.current?.original, "只是一条完整经验。"); XCTAssertEqual(model.session.source, "作者来源")
        XCTAssertTrue(service.discussionCalls.isEmpty); try await model.finish()
    }
    func testPastedPromptCanSaveWithOptionalDescriptionsEmptyAndRequiredFieldsStillValidated() throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        var s = session(); s.items[0].selected = true; s.items[0].confirmed = true
        s.items[0].candidate = GeneratedPrompt(title: "手填条目", summary: "", explanation: "", prompt: "用户指令", categoryID: "coding", newCategoryName: nil)
        XCTAssertThrowsError(try s.items[0].candidate!.validate(categories: repo.categories()))
        try repo.storeExperienceDraft(s); let saved = try repo.saveExperiences(s)
        XCTAssertEqual(saved.first?.summary, ""); XCTAssertEqual(saved.first?.explanation, "")
        XCTAssertEqual(saved.first?.prompt, "用户指令")
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertEqual(try reopened.entry(id: s.items[0].id, category: "coding")?.originalExperience, s.items[0].original)
        let invalid = GeneratedPrompt(title: "", summary: "", explanation: "", prompt: "用户指令", categoryID: "coding", newCategoryName: nil)
        XCTAssertThrowsError(try invalid.validate(categories: repo.categories(), requiringDescriptions: false))
    }
    @MainActor func testOldConversationDraftRemainsIntactWithoutStartingChat() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        var s = session(); s.items[0].messages = (0..<500).map { .init(role: .user, content: "已有消息\($0)") }; s.items[0].input = "旧未发送输入"
        let service = ControlledExperienceService(), model = ExperienceController(session: s, library: PromptLibrary(repository: repo), service: service)
        model.choose(s.items[1].id); model.choose(s.items[0].id); model.send(); try await model.finish()
        XCTAssertEqual(try repo.experienceDraft()?.items[0].messages, s.items[0].messages)
        XCTAssertEqual(try repo.experienceDraft()?.items[0].input, "旧未发送输入"); XCTAssertTrue(service.discussionCalls.isEmpty)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        object.removeValue(forKey: "manualPrompt")
        XCTAssertNil(try JSONDecoder().decode(ExperienceSession.self, from: JSONSerialization.data(withJSONObject: object)).manualPrompt)
    }
    @MainActor func testSelectionConfirmationAndPartialSaveStaySeparateForOneFiveAndTwenty() async throws {
        for count in [1, 5, 20] {
            let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
            var s = ExperienceSession(); s.raw = (0..<count).map { "原文\($0)。" }.joined(separator: "\n"); s.source = "来源保持原样"
            s.items = (0..<count).map { i in ExperienceItem(title: "经验\(i)", original: "原文\(i)。") }
            s.currentID = s.items[0].id
            let service = ControlledExperienceService()
            let model = ExperienceController(session: s, library: PromptLibrary(repository: repo), service: service)
            s.items.forEach { model.toggle($0.id) }; model.generateSelected()
            for i in 0..<count {
                try await until { service.organizeCalls.count == i + 1 }
                service.organizeCalls[i].2.resume(returning: candidate("待确认\(i)"))
            }
            try await until { !model.busy }
            XCTAssertEqual(model.reviewItems.count, count); XCTAssertTrue(model.session.confirmed.isEmpty)
            XCTAssertEqual(model.session.items.map(\.original), s.items.map(\.original))
            s.items.forEach { model.toggle($0.id) }
            model.toggle(s.items[0].id); XCTAssertTrue(model.session.confirmed.isEmpty)
            model.save(); XCTAssertTrue(model.status.contains("确认")); XCTAssertEqual(model.session.items.count, count)
            model.confirm(s.items[0].id); XCTAssertEqual(model.session.confirmed.count, 1)
            if count > 1 { model.choose(s.items[1].id) }
            model.save(); try await until { !model.saving }
            XCTAssertEqual(model.session.items.count, count - 1); XCTAssertTrue(model.session.selected.isEmpty)
            XCTAssertEqual(try repo.managedSummaries(category: "coding", query: "待确认0").count, 1)
            if count > 1 {
                XCTAssertEqual(model.current?.id, s.items[1].id)
                XCTAssertEqual(try repo.experienceDraft()?.items.count, count - 1)
                XCTAssertEqual(try repo.experienceDraft()?.source, s.source)
            } else { XCTAssertNil(try repo.experienceDraft()); XCTAssertNil(model.current) }
        }
    }
    @MainActor func testEditingConfirmedAndKeepingOrAdoptingSuggestionNeverOverwritesNewerWork() async throws {
        let (dir, repo) = repository(); defer { try? FileManager.default.removeItem(at: dir) }
        var s = session(); s.items[0].candidate = candidate(); let id = s.items[0].id
        let service = ControlledExperienceService(), model = ExperienceController(session: s, library: PromptLibrary(repository: repo), service: service)
        model.confirm(id); XCTAssertEqual(model.session.confirmed.count, 1)
        model.generateCurrent(); try await until { service.organizeCalls.count == 1 }
        model.choose(s.items[1].id)
        service.organizeCalls[0].2.resume(returning: candidate("AI 新建议")); try await until { !model.busy }
        XCTAssertEqual(model.session.items[0].candidate?.title, s.items[0].candidate?.title)
        XCTAssertEqual(model.session.items[0].suggestion?.title, "AI 新建议")
        model.choose(id); model.keepCurrent(id); XCTAssertNil(model.current?.suggestion); XCTAssertEqual(model.session.confirmed.count, 1)
        model.generateCurrent(); try await until { service.organizeCalls.count == 2 }
        let newer = candidate("待采用"); service.organizeCalls[1].2.resume(returning: newer); try await until { !model.busy }
        model.changePrompt("后来的手工修改"); model.adoptSuggestion(id, newer)
        XCTAssertEqual(model.current?.candidate?.prompt, "后来的手工修改"); XCTAssertTrue(model.session.confirmed.isEmpty)
        try await model.finish(); XCTAssertEqual(try repo.experienceDraft()?.items[0].candidate?.prompt, "后来的手工修改")
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
