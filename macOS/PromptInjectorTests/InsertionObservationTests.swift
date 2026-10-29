import XCTest
@testable import PromptInjector

final class InsertionObservationTests: XCTestCase {
    func testCollapsedBlankLinesAreDiagnosedButNeverVerified() throws {
        let plan = try XCTUnwrap(InsertionPlan(before: "Q-TEST", range: .init(location: 6, length: 0), prompt: "一\n\n二\n\n三"))
        let actual = "Q-TEST一\n二\n三"
        let observation = InsertionObservation(expected: plan.expected, observed: actual)
        XCTAssertEqual(observation.expectedUTF16Count-observation.observedUTF16Count, 2)
        XCTAssertEqual(observation.expectedLineBreakCount, 4)
        XCTAssertEqual(observation.observedLineBreakCount, 2)
        XCTAssertTrue(observation.matchesCollapsingBlankLines)
        XCTAssertFalse(plan.matches(actual))
    }
    func testMissingPrefixOrCharactersCannotBeExplainedAsLineBreakChange() throws {
        let plan = try XCTUnwrap(InsertionPlan(before: "Q-TEST", range: .init(location: 6, length: 0), prompt: "一\n二"))
        let observation = InsertionObservation(expected: plan.expected, observed: "TEST一\n二")
        XCTAssertFalse(observation.matchesCollapsingBlankLines)
        XCTAssertFalse(observation.matchesIgnoringLineBreaks)
        XCTAssertFalse(plan.matches("TEST一\n二"))
    }
    func testCRLFNormalizationRemainsValidWithoutTrimmingSpaces() throws {
        let plan = try XCTUnwrap(InsertionPlan(before: "", range: .init(location: 0, length: 0), prompt: " 一\n\n二 "))
        XCTAssertTrue(plan.matches(" 一\r\n\r\n二 "))
        XCTAssertFalse(plan.matches("一\n\n二"))
    }
}
