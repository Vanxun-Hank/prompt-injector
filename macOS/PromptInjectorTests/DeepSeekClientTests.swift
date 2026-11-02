import XCTest
@testable import PromptInjector

private final class DeepSeekProtocol: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.respond(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class DeepSeekClientTests: XCTestCase {
    var session: URLSession!
    let candidateJSON = """
    {"title":"先复现再修复","summary":"问题能复现时","explanation":"仅针对可复现的问题，先写失败测试固定行为。","prompt":"若问题可复现，先添加最小失败测试，验证失败，再修复并重跑。","categoryID":"debugging","newCategoryName":null}
    """
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [DeepSeekProtocol.self]
        session = URLSession(configuration: config)
    }
    override func tearDown() { session.invalidateAndCancel(); session = nil; DeepSeekProtocol.respond = nil }
    func response(_ content: String, finish: String = "stop") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish, "message": ["role": "assistant", "content": content, "reasoning_content": "仅模拟思考内容，不进入草稿"]]]])
    }
    func testRequestContainsCurrentCategoriesExactInputJSONAndNoTools() throws {
        let client = DeepSeekClient(session: session, key: { "test-only-key" })
        let raw = "仅在可复现时，先写测试。\n\"引号\"😀", source = "署名 / https://example.com/?a=1&b=2"
        let categories = PromptCategory.initial + [.init(id: "sixth", name: "学习", symbol: "folder")]
        let request = try client.request(experience: raw, source: source, categories: categories)
        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.timeoutInterval, 180)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only-key")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "deepseek-flash")
        XCTAssertEqual(body["reasoning_effort"] as? String, "high")
        XCTAssertEqual((body["response_format"] as? [String: String])?["type"], "json_object")
        XCTAssertNil(body["tools"])
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.first?["content"], DeepSeekClient.systemPrompt)
        XCTAssertTrue(DeepSeekClient.systemPrompt.contains("先说明再做"))
        XCTAssertTrue(DeepSeekClient.systemPrompt.contains("原文明示要确认"))
        let input = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(messages.last?["content"]).utf8)) as? [String: Any])
        XCTAssertEqual(input["originalExperience"] as? String, raw); XCTAssertEqual(input["source"] as? String, source)
        XCTAssertEqual((input["categories"] as? [[String: String]])?.last?["id"], "sixth")
    }
    func testSuccessfulHTTPResponseValidatesAllFieldsAndIgnoresReasoning() async throws {
        let data = try response(candidateJSON)
        DeepSeekProtocol.respond = { _ in XCTAssertFalse(Thread.isMainThread); return (200, data) }
        let client = DeepSeekClient(session: session, key: { "test-only-key" })
        let result = try await client.generate(experience: "仅在问题能复现时，先写失败测试再修复。", source: "本人", categories: PromptCategory.initial)
        XCTAssertEqual(result.title, "先复现再修复"); XCTAssertEqual(result.categoryID, "debugging")
        XCTAssertFalse(result.prompt.isEmpty); XCTAssertFalse(result.explanation.isEmpty); XCTAssertFalse(result.summary.isEmpty)
        let draft = EditorDraft(entry: GenerationTests().entry(), original: nil, candidate: result)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(draft), as: UTF8.self).contains("模拟思考"))
    }
    func testKeyFileImportRefusesInvalidOrLinkedInputWithoutConsumingIt() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("key.txt"), link = dir.appendingPathComponent("link.txt")
        for value in ["请在此输入", "\n ", String(repeating: "x", count: 1025)] {
            let data = Data(value.utf8); try data.write(to: file)
            XCTAssertThrowsError(try DeepSeekKeychain.importFile(file))
            XCTAssertEqual(try Data(contentsOf: file), data)
        }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try DeepSeekKeychain.importFile(link))
    }
    func testHTTPFailureTimeoutAndTruncatedOrEmptyResponsesAreRejected() async throws {
        let client = DeepSeekClient(session: session, key: { "test-only-key" })
        for status in [401, 402, 429, 500] {
            DeepSeekProtocol.respond = { _ in (status, Data("sensitive error body".utf8)) }
            do { _ = try await client.generate(experience: "经验", source: "", categories: PromptCategory.initial); XCTFail("HTTP failure accepted") }
            catch GenerationFailure.http(let code) { XCTAssertEqual(code, status) }
        }
        DeepSeekProtocol.respond = { _ in throw URLError(.timedOut) }
        do { _ = try await client.generate(experience: "经验", source: "", categories: PromptCategory.initial); XCTFail("Timeout accepted") }
        catch let error as URLError { XCTAssertEqual(error.code, .timedOut) }
        for data in [try response(candidateJSON, finish: "length"), try response(" "), Data("{}".utf8), Data("not JSON".utf8)] {
            XCTAssertThrowsError(try DeepSeekClient.decodeResponse(data, categories: PromptCategory.initial))
        }
        XCTAssertThrowsError(try client.request(experience: " ", source: "", categories: []))
        XCTAssertThrowsError(try client.request(experience: String(repeating: "字", count: 60001), source: "", categories: []))
    }
    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    func testFetchAndIdentifyUseProviderOnlyAndPreserveExactQuotes() async throws {
        let client = DeepSeekClient(session: session, key: { "fixture-key" }), raw = "仅可复现时先测试。"
        DeepSeekProtocol.respond = { request in
            XCTAssertEqual(request.url?.host, "api.deepseek.com"); XCTAssertEqual(request.url?.path, "/v1/tools/fetch")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-key")
            XCTAssertEqual(try self.body(request)["url"] as? String, "https://example.com/article")
            return (200, try JSONSerialization.data(withJSONObject: ["title": "公开文章", "content": raw]))
        }
        let fetched = try await client.fetch(URL(string: "https://example.com/article")!); XCTAssertEqual(fetched, raw)
        DeepSeekProtocol.respond = { request in
            let body = try self.body(request)
            XCTAssertNil(body["tools"]); XCTAssertNotNil(body["response_format"])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            let input = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(messages[1]["content"]).utf8)) as? [String: String])
            XCTAssertEqual(input["originalText"], raw)
            return (200, try self.response("{\"experiences\":[{\"title\":\"先测试\",\"original\":\"仅可复现时先测试。\"}]}"))
        }
        let items = try await client.identify(fetched); XCTAssertEqual(items.first?.original, raw)
        DeepSeekProtocol.respond = { _ in (404, Data("private error".utf8)) }
        do { _ = try await client.fetch(URL(string: "https://example.com/missing")!); XCTFail("Unavailable page accepted") }
        catch GenerationFailure.fetchUnavailable { }
    }
    func testDiscussionSendsOnlyCurrentHistoryAndOrganizeSendsFreshCategoriesAndDiscussion() async throws {
        let client = DeepSeekClient(session: session, key: { "fixture-key" })
        let context = "全篇仅适用于能稳定复现的问题。\n仅可复现时先测试。"
        var item = ExperienceItem(title: "先验证", original: "仅可复现时先测试。")
        item.messages = [.init(role: .user, content: "为什么？"), .init(role: .assistant, content: "先固定问题。"), .init(role: .user, content: "请保留这个前提。")]
        DeepSeekProtocol.respond = { request in
            let body = try self.body(request), messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            XCTAssertNil(body["tools"]); XCTAssertNil(body["response_format"])
            let input = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(messages[1]["content"]).utf8)) as? [String: Any])
            XCTAssertEqual(input["originalContext"] as? String, context)
            XCTAssertEqual(Array(messages.suffix(3)).compactMap { $0["content"] }, item.messages.map(\.content))
            return (200, try self.response("原文的条件必须保留。"))
        }
        let reply = try await client.discuss(item, source: "本人", context: context); XCTAssertEqual(reply, "原文的条件必须保留。")
        DeepSeekProtocol.respond = { request in
            let body = try self.body(request), messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            let input = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(messages[1]["content"]).utf8)) as? [String: Any])
            XCTAssertEqual((input["discussion"] as? [[String: String]])?.last?["content"], "请保留这个前提。")
            XCTAssertEqual(input["originalContext"] as? String, context)
            XCTAssertEqual((input["categories"] as? [[String: String]])?.last?["id"], "live-sixth")
            return (200, try self.response(self.candidateJSON))
        }
        _ = try await client.organize(item, source: "本人", context: context, categories: PromptCategory.initial + [.init(id: "live-sixth", name: "新增类", symbol: "folder")])
    }
    func testSocialFetchDoesNotAttributeRepliesToTheLinkedAuthor() async throws {
        let post = "1. 保留适用条件。2. 真实运行检查。"
        let markdown = "# X 上的作者：“\(post)”\n\n- \(post)\n- 回复：把所有要求一律变成必须执行。"
        DeepSeekProtocol.respond = { _ in (200, try JSONSerialization.data(withJSONObject: ["title": "公开帖子", "content": markdown])) }
        let client = DeepSeekClient(session: session, key: { "fixture-key" })
        let result = try await client.fetch(URL(string: "https://x.com/author/status/1")!)
        XCTAssertEqual(result, post)
    }
}
