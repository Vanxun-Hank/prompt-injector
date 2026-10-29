import XCTest
import AppKit
@testable import PromptInjector

final class NavigationTests: XCTestCase {
    func testBackRestoresIndependentSelectionAndScroll() {
        var state = NavigationState()
        state.remember(selection: 2, scrollY: 40)
        state.open(.entries("debugging"))
        state.remember(selection: 1, scrollY: 88)
        state.open(.detail("debugging", "debug-hypotheses"))
        state.remember(selection: 0, scrollY: 250)
        XCTAssertTrue(state.back())
        XCTAssertEqual(state.restored.selection, 1)
        XCTAssertEqual(state.restored.scrollY, 88)
        XCTAssertTrue(state.back())
        XCTAssertEqual(state.restored.selection, 2)
        XCTAssertEqual(state.restored.scrollY, 40)
        XCTAssertFalse(state.back())
    }

    func testSeedContentHasDistinctIDsAndRequiredFields() throws {
        let entries = try PromptSeed.entries()
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        for category in PromptCategory.all { XCTAssertFalse(entries.filter { $0.categoryID == category.id }.isEmpty) }
        for entry in entries {
            XCTAssertFalse(entry.summary.isEmpty)
            XCTAssertFalse(entry.originalExperience.isEmpty)
            XCTAssertFalse(entry.source.isEmpty)
            XCTAssertFalse(entry.prompt.isEmpty)
        }
    }

    @MainActor func testOnlyFencedCodeUsesMonospacedFont() {
        let entry = PromptEntry(id: "test", categoryID: "coding", title: "中文标题", summary: "说明", originalExperience: "原文", source: "测试", explanation: "解释", prompt: "普通文字\n```swift\nlet value = 1\n```\n继续说明")
        let view = DetailDocument(frame: NSRect(x: 0, y: 0, width: 360, height: 300))
        view.setEntry(entry)
        let rendered = view.promptTextView.attributedString()
        let text = rendered.string as NSString
        for sample in ["普通文字", "继续说明"] {
            let font = rendered.attribute(.font, at: text.range(of: sample).location, effectiveRange: nil) as! NSFont
            XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
        }
        let font = rendered.attribute(.font, at: text.range(of: "let value").location, effectiveRange: nil) as! NSFont
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }
}
