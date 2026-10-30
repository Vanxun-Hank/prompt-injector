import XCTest
import AppKit
import CoreText
@testable import PromptInjector

final class NavigationTests: XCTestCase {
    @MainActor func testAppIconHasTransparentCanvasOutsideDarkTile() throws {
        let image = try XCTUnwrap(DesignAssets.image("AppIcon", template: false))
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        for (x, y) in [(0, 0), (0.5, 0), (1, 0), (0, 0.5), (1, 0.5), (0, 1), (0.5, 1), (1, 1)] {
            let color = try XCTUnwrap(bitmap.colorAt(x: Int(x * Double(bitmap.pixelsWide - 1)), y: Int(y * Double(bitmap.pixelsHigh - 1))))
            XCTAssertLessThan(color.alphaComponent, 0.01, "Outer canvas must be transparent")
        }
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)).alphaComponent, 0.95)
    }

    @MainActor func testIconAndVisibleTextShareCenterline() {
        func inkCenter(_ field: NSTextField, in parent: NSView, text: String) -> CGFloat {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: field.font!]))
            let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            let fromTop = field.firstBaselineOffsetFromTop - ink.midY
            return parent.isFlipped ? field.frame.minY + fromTop : field.frame.maxY - fromTop
        }
        let row = PromptCell(frame: NSRect(x: 0, y: 0, width: 326, height: 44))
        row.category = true; row.title.stringValue = "需求对接"; row.count.stringValue = "12"; row.layout()
        XCTAssertEqual(inkCenter(row.title, in: row, text: row.title.stringValue), row.chevron.frame.midY, accuracy: 1)
        XCTAssertEqual(inkCenter(row.count, in: row, text: row.count.stringValue), row.chevron.frame.midY, accuracy: 1)
        let search = SearchBox(); search.frame = NSRect(x: 0, y: 0, width: 360, height: 40); search.layout()
        let icon = search.subviews.compactMap { $0 as? NSImageView }.first!
        XCTAssertEqual(inkCenter(search.field, in: search, text: "搜索标题和简述"), icon.frame.midY, accuracy: 1)
    }

    @MainActor func testRowSpacingDoesNotSelectCompactTextLayout() {
        let row = PromptCell(frame: NSRect(x: 0, y: 0, width: 570, height: 72))
        row.title.stringValue = "标题"; row.summary.stringValue = "简述"; row.layout()
        XCTAssertEqual(row.summary.maximumNumberOfLines, 1)
        func inkRect(_ field: NSTextField) -> NSRect {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: field.stringValue, attributes: [.font: field.font!]))
            let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            return ink.offsetBy(dx: field.frame.minX, dy: field.frame.maxY - field.firstBaselineOffsetFromTop)
        }
        XCTAssertEqual(inkRect(row.title).union(inkRect(row.summary)).midY, row.chevron.frame.midY, accuracy: 1)
    }

    @MainActor func testDrawnLabelsCenterVisibleInkInBothCoordinateDirections() throws {
        for flipped in [false, true] {
            let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 160, pixelsHigh: 44, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 640, bitsPerPixel: 32))
            let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
            graphics.cgContext.clear(NSRect(x: 0, y: 0, width: 160, height: 44))
            NSGraphicsContext.saveGraphicsState()
            if flipped { graphics.cgContext.translateBy(x: 0, y: 44); graphics.cgContext.scaleBy(x: 1, y: -1) }
            NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: flipped)
            Theme.drawLine("需求对接 12", font: .systemFont(ofSize: 13), color: .white, in: NSRect(x: 10, y: 0, width: 140, height: 44))
            NSGraphicsContext.restoreGraphicsState()
            let rows = (0..<44).filter { y in (0..<160).contains { x in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 } }
            XCTAssertFalse(rows.isEmpty)
            if let first = rows.first, let last = rows.last { XCTAssertEqual(CGFloat(first + last + 1) / 2, 22, accuracy: 1) }
        }
    }

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

    @MainActor func testLongTitleDoesNotPaintBehindDetailControls() {
        let entry = PromptEntry(id: "long", categoryID: "coding", title: String(repeating: "中文长标题与 Identifier 边界检查", count: 10), summary: "", originalExperience: "原文", source: "来源", explanation: "解释", prompt: "正文")
        let view = DetailDocument(frame: NSRect(x: 0, y: 0, width: 326, height: 170))
        view.setEntry(entry); view.arrange(width: 326, height: 170)
        let container = view.heading.textContainer!
        view.heading.layoutManager?.ensureLayout(for: container)
        XCTAssertLessThanOrEqual(view.heading.layoutManager!.usedRect(for: container).height, view.heading.bounds.height)
        XCTAssertGreaterThanOrEqual(view.segments.frame.minY, view.heading.frame.maxY + 8)
    }

    @MainActor func testPermissionFailureDisablesInsertionAndPreservesCopy() {
        let view = LauncherView(library: PromptLibrary(entries: []))
        view.showFeedback("需要辅助功能权限。", error: true, permission: true, persist: true)
        XCTAssertFalse(view.insertButton.isEnabled)
        XCTAssertTrue(view.copyButton.isEnabled)
        view.showFeedback("复制失败，请重试。", error: true)
        XCTAssertFalse(view.insertButton.isEnabled)
        view.setInsertionFailure(nil)
        XCTAssertTrue(view.feedback.isHidden)
        view.showFeedback("使用记录未保存。", error: true)
        XCTAssertTrue(view.insertButton.isEnabled)
        view.setInsertionFailure(.targetLost)
        XCTAssertFalse(view.insertButton.isEnabled)
        view.setInsertionFailure(nil)
        XCTAssertTrue(view.insertButton.isEnabled)
    }
}
