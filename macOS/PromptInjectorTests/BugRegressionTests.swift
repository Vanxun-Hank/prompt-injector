import XCTest
import AppKit
@testable import PromptInjector

final class BugRegressionTests: XCTestCase {
    @MainActor func testCaptureWithoutInputReportsNoTextFocusAndNeverWrites() async throws {
        let suite = "PI-missing-focus-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let logger = DiagnosticLog(directory: directory)
        defer { logger.flush(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let service = InjectionService(defaults: defaults, logger: logger, permissionCheck: { true })
        for application in [nil, NSRunningApplication.current] {
            service.capture(application)
            var hidden = false
            do { try await service.insert("PRIVATE PROMPT", hide: { hidden = true }); XCTFail("Must reject a missing captured input") }
            catch { XCTAssertEqual(error as? InjectionService.Failure, .noTextFocus) }
            XCTAssertFalse(hidden)
            let snapshot = try XCTUnwrap(defaults.dictionary(forKey: "insertion.lastResult"))
            XCTAssertEqual(snapshot["errorCode"] as? String, "noTextFocus")
        }
        logger.flush()
        let records = try String(contentsOf: directory.appendingPathComponent("events.jsonl"), encoding: .utf8)
        XCTAssertFalse(records.contains("insertion.write_requested")); XCTAssertFalse(records.contains("PRIVATE PROMPT"))
    }
    // PI-003 / PI-004: exercise the real service's early failure path, without touching external apps.
    @MainActor func testServiceClearsOldSuccessAndLogsFreshPermissionFailureThenRecapture() async throws {
        let suite = "PI-regression-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let logger = DiagnosticLog(directory: directory)
        var granted = false
        let service = InjectionService(defaults: defaults, logger: logger, permissionCheck: { granted })
        defaults.set(["status": "verified"], forKey: "insertion.lastResult")
        var hidden = false
        do { try await service.insert("PRIVATE INPUT MUST NOT BE LOGGED", hide: { hidden = true }); XCTFail("Expected permission rejection") }
        catch { XCTAssertEqual(error as? InjectionService.Failure, .permission) }
        let failure = try XCTUnwrap(defaults.dictionary(forKey: "insertion.lastResult"))
        XCTAssertEqual(failure["status"] as? String, "failed")
        XCTAssertEqual(failure["errorCode"] as? String, "permission")
        XCTAssertNotNil(failure["operationID"])
        XCTAssertFalse(hidden)
        service.capture(nil)
        granted = true
        do { try await service.insert("PRIVATE INPUT MUST NOT BE LOGGED", hide: { hidden = true }); XCTFail("Expected recapture request") }
        catch { XCTAssertEqual(error as? InjectionService.Failure, .recaptureRequired) }
        logger.flush()
        let data = try String(contentsOf: directory.appendingPathComponent("events.jsonl"), encoding: .utf8)
        XCTAssertTrue(data.contains("insertion.failed"))
        XCTAssertTrue(data.contains("recaptureRequired"))
        XCTAssertFalse(data.contains("PRIVATE INPUT MUST NOT BE LOGGED"))
        XCTAssertFalse(hidden)
    }
    // PI-002: Codex's editable AXGroup was incorrectly rejected by a role-only whitelist.
    func testCustomEditableGroupIsAcceptedButReadOnlyOrSecureGroupIsNot() {
        XCTAssertTrue(TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: true, valueWritable: false).supportsInsertion)
        XCTAssertFalse(TargetCapabilities(role: "AXGroup", isSecure: false, textReadable: true, selectionReadable: true, selectionWritable: false, valueWritable: false).supportsInsertion)
        XCTAssertFalse(TargetCapabilities(role: "AXTextField", isSecure: true, textReadable: true, selectionReadable: true, selectionWritable: true, valueWritable: true).supportsInsertion)
        XCTAssertFalse(TargetCapabilities(role: "AXTextArea", isSecure: false, textReadable: false, selectionReadable: true, selectionWritable: true, valueWritable: true).supportsInsertion)
    }
    // PI-001: a successful AX setter call did not update the Codex composer.
    func testCodexUsesPasteAndUnchangedTextCannotPassVerification() throws {
        XCTAssertEqual(InsertionMethod.forApplication("com.openai.codex"), .paste)
        let plan = try XCTUnwrap(InsertionPlan(before: "已有草稿", range: NSRange(location: 4, length: 0), prompt: "\n新 Prompt"))
        XCTAssertFalse(plan.matches("已有草稿"))
        XCTAssertTrue(plan.matches("已有草稿\n新 Prompt"))
    }
    // PI-004: permissions granted while the panel was open must not reuse a stale denial.
    @MainActor func testNewPermissionRequiresRecaptureInsteadOfReportingPermissionDeniedAgain() {
        XCTAssertEqual(InsertionPreflight.failure(permissionGranted: true, captureFailure: .permission), .recaptureRequired)
        XCTAssertEqual(InsertionPreflight.failure(permissionGranted: false, captureFailure: nil), .permission)
        XCTAssertEqual(InsertionPreflight.failure(permissionGranted: true, captureFailure: .unsupported), .unsupported)
        XCTAssertNil(InsertionPreflight.failure(permissionGranted: true, captureFailure: nil))
    }
    // PI-005: invalid persisted indexes must not become negative array indexes.
    func testInvalidShortcutPreferencesFallBackToFirstOption() {
        for invalid in [-1, Int.min, 2, Int.max] {
            XCTAssertEqual(ShortcutPreference.resolve(invalid, optionCount: 2), 0)
        }
        XCTAssertEqual(ShortcutPreference.resolve(1, optionCount: 2), 1)
    }
    func testRelatedMalformedWindowPreferencesAreRejected() {
        XCTAssertFalse(WindowGeometry.isValidSavedFrame(.zero))
        XCTAssertFalse(WindowGeometry.isValidSavedFrame(CGRect(x: CGFloat.nan, y: 0, width: 620, height: 520)))
        XCTAssertFalse(WindowGeometry.isValidSavedFrame(CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 520)))
        // Negative coordinates are valid for monitors placed left/below the primary display.
        XCTAssertTrue(WindowGeometry.isValidSavedFrame(CGRect(x: -1000, y: -200, width: 620, height: 520)))
    }
}
