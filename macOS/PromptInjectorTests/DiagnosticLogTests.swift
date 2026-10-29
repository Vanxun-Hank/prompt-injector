import XCTest
@testable import PromptInjector

final class DiagnosticLogTests: XCTestCase {
    private let build = BuildIdentity(version: "test", buildID: "build-42", sourceFingerprint: "source-abc", revision: "unversioned")
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PI-logs-\(UUID())") }
    private func records(_ directory: URL) throws -> [DiagnosticRecord] {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
            .flatMap { try String(contentsOf: $0, encoding: .utf8).split(separator: "\n").map { try decoder.decode(DiagnosticRecord.self, from: Data($0.utf8)) } }
    }
    func testHistoryRetainsSuccessThenFailureWithSeparateOperationIDs() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let logger = DiagnosticLog(directory: dir, build: build)
        let success = UUID(), failure = UUID()
        logger.write(.insertionVerified, operationID: success, fields: .init(method: "paste", observedUTF16Count: 99))
        logger.write(.insertionFailed, level: .error, operationID: failure, fields: .init(stage: "permission", errorCode: "permission"))
        logger.flush()
        let entries = try records(dir).sorted { $0.sequence < $1.sequence }
        XCTAssertEqual(entries.map(\.event), [.insertionVerified, .insertionFailed])
        XCTAssertEqual(entries.map(\.operationID), [success, failure])
        XCTAssertEqual(entries[1].build.sourceFingerprint, "source-abc")
        XCTAssertEqual(entries[1].fields.stage, "permission")
        XCTAssertEqual(entries[0].sessionID, entries[1].sessionID)
        XCTAssertNil(logger.lastWriteErrorCode)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("events.jsonl")).split(separator: 10)[0]) as? [String: Any])
        let fields = try XCTUnwrap(json["fields"] as? [String: Any])
        XCTAssertEqual(Set(fields.keys), ["method", "observedUTF16Count"])
    }
    func testRotationBoundsDiskUseAndKeepsValidCompleteLines() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let logger = DiagnosticLog(directory: dir, build: build, maxFileBytes: 4096, archiveCount: 2)
        for index in 0..<100 { logger.write(.probe, fields: .init(systemCode: index)) }
        logger.flush()
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "jsonl" }
        XCTAssertEqual(files.count, 3)
        for file in files {
            let data = try Data(contentsOf: file)
            XCTAssertLessThanOrEqual(data.count, 4096); XCTAssertEqual(data.last, 10)
        }
        XCTAssertEqual(try records(dir).max { $0.sequence < $1.sequence }?.fields.systemCode, 99)
    }
    func testConcurrentWritersProduceIndependentSessionsWithoutCorruptingJSON() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let first = DiagnosticLog(directory: dir, build: build), second = DiagnosticLog(directory: dir, build: build)
        for _ in 0..<30 { first.write(.probe); second.write(.probe) }
        first.flush(); second.flush()
        let entries = try records(dir)
        XCTAssertEqual(entries.count, 60)
        XCTAssertEqual(Set(entries.map(\.sessionID)).count, 2)
    }
    func testLoggingFailureIsContainedInsteadOfThrowingIntoAppFlow() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        try Data("not a directory".utf8).write(to: dir)
        let logger = DiagnosticLog(directory: dir, build: build)
        logger.write(.probe); logger.flush()
        XCTAssertNotNil(logger.lastWriteErrorCode)
    }
}
