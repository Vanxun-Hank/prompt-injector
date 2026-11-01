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
}
