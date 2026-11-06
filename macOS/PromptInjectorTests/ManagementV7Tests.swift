import XCTest
import AppKit
@testable import PromptInjector

final class ManagementV7Tests: XCTestCase {
    @MainActor func testCompletionDoesNotLeaveAnEmptyListOrStaleEditor() {
        let model = ExperienceController(session: ExperienceSession(), library: PromptLibrary(repository: SQLitePromptRepository(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))), service: ControlledExperienceService())
        let view = ExperienceView(controller: model)
        view.showCompletion(1)
        XCTAssertTrue(view.panel.isHidden)
        XCTAssertNil(view.editor)
        XCTAssertTrue(view.input.isHidden)
    }

    @MainActor func testInlineCandidateNeedsExplicitAdoptionAndHiddenEditorHasFiniteGeometry() {
        _ = NSApplication.shared
        let entry = GenerationTests().entry(), candidate = GenerationTests().candidate
        let editor = PromptEditorView(draft: EditorDraft(entry: entry, original: entry), categories: PromptCategory.initial, inlineMode: true)
        editor.candidateEditor.layout()
        XCTAssertTrue(editor.candidateEditor.subviews.allSatisfy { $0.frame.minX.isFinite && $0.frame.minY.isFinite })
        XCTAssertTrue(editor.candidateEditor.fields.allSatisfy { $0.frame.width.isFinite && $0.frame.minX.isFinite })
        editor.receiveCandidate(candidate)
        XCTAssertEqual(editor.segments.selectedIndex, 0); XCTAssertEqual(editor.value, entry)
        editor.discardCandidate(); XCTAssertNil(editor.candidate); XCTAssertEqual(editor.value, entry)
        editor.receiveCandidate(candidate); editor.adoptCandidate()
        XCTAssertEqual(editor.value.prompt, candidate.prompt)
        XCTAssertEqual(editor.value.originalExperience, entry.originalExperience); XCTAssertEqual(editor.value.source, entry.source)
        XCTAssertNil(editor.candidate)
    }

    @MainActor func testInputModeSwitchPreservesPastedPromptAndRestoresWithoutNetwork() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")), service = ControlledExperienceService()
        let model = ExperienceController(session: ExperienceSession(), library: PromptLibrary(repository: repo), service: service)
        model.beginManual(); model.changeInput("作者原文保持原样"); model.changePrompt("手贴的 Prompt")
        model.beginAutomatic(); try await model.finish()
        let saved = try XCTUnwrap(SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")).experienceDraft())
        let resumed = ExperienceController(session: saved, library: PromptLibrary(repository: repo), service: service)
        XCTAssertFalse(resumed.isManualEntry); XCTAssertEqual(saved.manualPrompt, "手贴的 Prompt")
        resumed.beginManual(); XCTAssertTrue(resumed.isManualEntry); XCTAssertEqual(resumed.session.input, "作者原文保持原样")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        json.removeValue(forKey: "manualEntry")
        let legacy = try JSONDecoder().decode(ExperienceSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(ExperienceController(session: legacy, library: PromptLibrary(repository: repo), service: service).isManualEntry)
        XCTAssertTrue(service.identifyCalls.isEmpty && service.organizeCalls.isEmpty)
        try await resumed.finish()
    }

    @MainActor private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }; try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("V7 operation timed out")
    }
    @MainActor func testGridOpensOnlyChosenEntryAndInlineEditKeepsCategoryAndSearchContext() async throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        let manager = ManagementWindowController(library: PromptLibrary(repository: repo))
        manager.window?.setContentSize(NSSize(width: 1440, height: 960))
        manager.showLibrary(category: "coding")
        manager.root.search.field.stringValue = "验证"; manager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        try await until { !manager.root.libraryView.items.isEmpty }
        XCTAssertNil(manager.selectedEntry); XCTAssertEqual(manager.root.libraryView.presentation, .grid)
        let row = try XCTUnwrap(manager.root.libraryView.items.first)
        manager.root.libraryView.openItem(id: row.summary.id)
        try await until { manager.selectedEntry?.id == row.summary.id }
        manager.root.libraryView.editButton.performClick(nil)
        try await until { manager.root.editor != nil }
        let editor = try XCTUnwrap(manager.root.editor)
        manager.root.layoutSubtreeIfNeeded()
        XCTAssertTrue(editor.inlineMode); XCTAssertTrue(editor.superview === manager.root.libraryView.preview)
        editor.summaryText.text.string += "，保留筛选"; editor.textDidChange(Notification(name: NSText.didChangeNotification))
        let saved = editor.value; manager.saveEditor()
        try await until { !manager.isSaving && manager.selectedEntry == saved }
        XCTAssertEqual(manager.root.search.field.stringValue, "验证")
        XCTAssertTrue(manager.root.libraryView.items.allSatisfy { $0.summary.categoryID == "coding" })
        XCTAssertEqual(manager.root.libraryView.presentation, .detail)
        manager.root.backButton.performClick(nil)
        XCTAssertEqual(manager.root.libraryView.presentation, .grid)
        XCTAssertEqual(manager.root.search.field.stringValue, "验证")
        manager.window?.orderOut(nil)
    }

    @MainActor func testUnifiedWorkbenchGeneratesEditsAndPartiallySavesFive() async throws {
        _ = NSApplication.shared
        let count = 5
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")), service = ControlledExperienceService()
        let library = PromptLibrary(repository: repo)
        let manager = ManagementWindowController(library: library, experienceService: service)
        manager.window?.setContentSize(NSSize(width: 1100, height: 720))
        try await until { manager.root.categoryItems.count == 5 }
        var session = ExperienceSession(); session.raw = (0..<count).map { "原文\($0)。" }.joined(separator: "\n")
        session.input = session.raw; session.source = "https://x.com/author/status/1"
        session.items = (0..<count).map { .init(title: "经验\($0)", original: "原文\($0)。") }; session.currentID = session.items[0].id
        manager.presentExperience(session)
        let view = try XCTUnwrap(manager.root.experienceView), model = try XCTUnwrap(manager.experience)
        session.items.forEach { model.toggle($0.id) }; view.generate.performClick(nil)
        for i in 0..<count {
            try await until { service.organizeCalls.count == i + 1 }
            service.organizeCalls[i].2.resume(returning: .init(title: "生成\(i)", summary: "原文条件", explanation: "保留方法", prompt: "指令\(i)", categoryID: "coding", newCategoryName: nil))
        }
        try await until { !model.busy }; view.choose(session.items[0].id)
        let editor = try XCTUnwrap(view.editor)
        manager.root.layoutSubtreeIfNeeded()
        XCTAssertEqual(manager.root.page, .experience); XCTAssertNil(manager.root.editor)
        XCTAssertGreaterThanOrEqual(editor.promptText.frame.height, 150)
        editor.originalToggle.performClick(nil); manager.root.layoutSubtreeIfNeeded()
        XCTAssertFalse(editor.reviewOriginalScroll.isHidden)
        XCTAssertTrue(editor.content.bounds.contains(editor.promptText.frame))
        XCTAssertEqual(editor.originalText.text.string, session.items[0].original)
        editor.promptText.text.string += "，人工调整"; editor.textDidChange(Notification(name: NSText.didChangeNotification))
        XCTAssertTrue(view.editor === editor)
        view.confirmCurrent(); XCTAssertEqual(model.session.confirmed.count, 1)
        session.items.forEach { model.toggle($0.id) }; XCTAssertEqual(model.session.confirmed.count, 1)
        manager.saveEditor(); try await until { !model.saving }
        XCTAssertEqual(model.session.items.count, count - 1)
        XCTAssertEqual(view.selectedCount.stringValue, "已勾选 0 / \(count - 1)")
        let saved = try XCTUnwrap(repo.entry(id: session.items[0].id, category: "coding"))
        XCTAssertEqual(saved.prompt, "指令0，人工调整"); XCTAssertEqual(saved.source, session.source)
        XCTAssertEqual(view.editor?.id, session.items[1].id)
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertEqual(try reopened.experienceDraft()?.items.count, count - 1)
        XCTAssertEqual(try reopened.experienceDraft()?.source, session.source)
        await withCheckedContinuation { c in library.flush { c.resume() } }
        try await model.finish(); manager.window?.orderOut(nil)
    }

    @MainActor func testGridScrollSurvivesInlineSaveAndNewSearchResetsIt() async throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"), seed: { [] })
        var values: [PromptEntry] = []
        for i in 0..<30 {
            let item = PromptEntry(id: UUID().uuidString, categoryID: "coding", title: "滚动 \(i)", summary: "简述", originalExperience: "原文", source: "", explanation: "解释", prompt: "指令")
            try repo.create(item, operationID: UUID()); values.append(item)
        }
        let manager = ManagementWindowController(library: PromptLibrary(repository: repo))
        manager.window?.setContentSize(NSSize(width: 1440, height: 960)); manager.showLibrary(category: "coding")
        try await until { manager.root.libraryView.items.count == 30 }; manager.root.layoutSubtreeIfNeeded()
        let grid = manager.root.libraryView.grid
        grid.scroll.contentView.scroll(to: NSPoint(x: 0, y: 600))
        manager.root.libraryView.openItem(id: values[20].id)
        try await until { manager.selectedEntry?.id == values[20].id }
        manager.root.libraryView.editButton.performClick(nil); try await until { manager.root.editor != nil }
        let editor = try XCTUnwrap(manager.root.editor)
        editor.summaryText.text.string = "编辑后的简述"; editor.textDidChange(Notification(name: NSText.didChangeNotification))
        manager.saveEditor(); try await until { !manager.isSaving && manager.selectedEntry?.summary == "编辑后的简述" }
        manager.root.backButton.performClick(nil); manager.root.layoutSubtreeIfNeeded()
        XCTAssertEqual(grid.scroll.contentView.bounds.minY, 600, accuracy: 1)
        manager.root.search.field.stringValue = "滚动 0"; manager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        try await until { manager.root.libraryView.items.count == 1 }; manager.root.layoutSubtreeIfNeeded()
        XCTAssertEqual(grid.scroll.contentView.bounds.minY, 0, accuracy: 1)
        manager.window?.orderOut(nil)
    }

    @MainActor func testEditingDuringGenerationKeepsActiveEditorAndRejectsLateResponse() async throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")), service = ControlledExperienceService()
        let manager = ManagementWindowController(library: PromptLibrary(repository: repo), experienceService: service)
        var s = ExperienceSession(); s.raw = "只在能复现时测试。"; s.input = s.raw
        s.items = [.init(title: "验证", original: s.raw)]; s.currentID = s.items[0].id
        manager.presentExperience(s)
        let view = try XCTUnwrap(manager.root.experienceView), editor = try XCTUnwrap(view.editor), model = try XCTUnwrap(manager.experience)
        model.generateCurrent(); try await until { service.organizeCalls.count == 1 }
        editor.promptText.text.string = "后来手工填写"; editor.textDidChange(Notification(name: NSText.didChangeNotification))
        XCTAssertTrue(view.editor === editor); XCTAssertFalse(model.busy)
        service.organizeCalls[0].2.resume(returning: .init(title: "迟到", summary: "条件", explanation: "方法", prompt: "不能覆盖", categoryID: "coding", newCategoryName: nil))
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(model.current?.candidate?.prompt, "后来手工填写"); XCTAssertNil(model.current?.suggestion)
        XCTAssertTrue(view.editor === editor); try await model.finish(); manager.window?.orderOut(nil)
    }
}
