import XCTest
import AppKit
@testable import PromptInjector

final class ManagementFilteringTests: XCTestCase {
    @MainActor func testChangingCategoryImmediatelyClearsOldRowsAndRejectsEarlierQueries() async throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")), library = PromptLibrary(repository: repo)
        let manager = ManagementWindowController(library: library)
        func settle() async { await withCheckedContinuation { c in library.flush { c.resume() } } }
        manager.showLibrary(category: "coding"); await settle()
        XCTAssertFalse(manager.root.libraryView.items.isEmpty)
        manager.showLibrary(category: "requirements")
        XCTAssertTrue(manager.root.libraryView.items.isEmpty, "Old category must not remain visible under a new filter")
        manager.showLibrary(category: "coding")
        manager.root.search.field.stringValue = "不存在的特定内容"
        manager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        await settle()
        XCTAssertTrue(manager.root.libraryView.items.isEmpty)
        XCTAssertNil(manager.selectedEntry)
        XCTAssertTrue(manager.root.subtitle.stringValue.hasPrefix("0 条"))
        manager.window?.orderOut(nil)
    }
}
