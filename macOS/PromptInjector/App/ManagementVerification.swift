import AppKit
import CSQLite

extension AppDelegate {
    @MainActor func verifyManagement(output: String) async -> [[String: Any]] {
        guard CommandLine.arguments.contains("--verify-ui"), let controller, let directory = verificationDatabaseDirectory else { return [["name": "management/isolated-database", "passed": false]] }
        var checks: [[String: Any]] = []
        let pasteboard = NSPasteboard.general
        let previousClipboard = pasteboard.pasteboardItems?.map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } } ?? []
        var copiedChangeCount: Int?
        func check(_ name: String, _ passed: Bool) { checks.append(["name": name, "passed": passed]) }
        @MainActor func until(_ condition: () -> Bool) async {
            for _ in 0..<300 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
            check("management/async-timeout", false)
        }
        let manager = ManagementWindowController(library: controller.launcher.library)
        management = manager; manager.show()
        guard let window = manager.window else { return [["name": "management/window", "passed": false]] }
        let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -24, dy: -24), styleMask: [.borderless], backing: .buffered, defer: false)
        backdrop.backgroundColor = Theme.hex(0x242424)
        func capture(_ name: String) async {
            backdrop.setFrame(window.frame.insetBy(dx: -24, dy: -24), display: true); backdrop.orderFront(nil)
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            window.contentView?.layoutSubtreeIfNeeded()
            try? await Task.sleep(nanoseconds: 180_000_000)
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // Capture this live window even if desktop activity changes stacking or position.
            p.arguments = ["-x", "-o", "-l", String(window.windowNumber), output + "/" + name + ".png"]
            do { try p.run(); p.waitUntilExit(); check("capture/" + name, p.terminationStatus == 0) }
            catch { check("capture/" + name, false) }
        }
        func sql(_ command: String) -> Bool {
            var db: OpaquePointer?
            guard sqlite3_open(directory.appendingPathComponent("library.sqlite3").path, &db) == SQLITE_OK else { return false }
            defer { sqlite3_close(db) }
            return sqlite3_exec(db, command, nil, nil, nil) == SQLITE_OK
        }
        await until { manager.selectedEntry != nil }
        check("management/native-window-controls", [.closeButton, .miniaturizeButton, .zoomButton].allSatisfy { window.standardWindowButton($0)?.isEnabled == true })
        check("management/initial-real-library", manager.root.libraryView.items.count == 7)
        check("assets/all-figma-assets-load", ["Logo", "Grid", "Chart", "Search", "Plus", "Down", "Copy", "Edit", "Check", "Back", "Close", "Insert", "Chevron", "Status", "Dot-requirements", "Dot-coding", "Dot-debugging", "Dot-review", "Dot-release", "MenuBar", "AppIcon"].allSatisfy { DesignAssets.image($0, template: false)?.size.width ?? 0 > 0 })
        await capture("management-library")
        manager.root.newButton.performClick(nil)
        await until { manager.root.editor != nil }
        guard let editor = manager.root.editor else { window.orderOut(nil); management = nil; return checks }
        editor.titleField.stringValue = "原生 QA · 中文😀"
        editor.summaryText.text.string = "本地新增、重启、编辑与搜索验证"
        editor.sourceField.stringValue = "自动化验证数据"
        editor.originalText.text.string = "保留原文\n第二行😀"
        editor.explanationText.text.string = "解释与 Prompt 独立保存。"
        editor.promptText.text.string = "仅写入原输入框，不发送。\n\n中文😀\nlet value = 1"
        editor.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: editor.titleField))
        let initial = editor.value
        await capture("management-editor")
        editor.segments.buttons[1].performClick(nil)
        await capture("management-original")
        check("management/edit-segments-preserve-text", editor.value == initial && editor.segments.selectedIndex == 1)
        check("management/install-failure-fixture", sql("CREATE TRIGGER qa_fail_save BEFORE INSERT ON prompts BEGIN SELECT RAISE(ABORT,'qa'); END"))
        manager.root.saveButton.performClick(nil)
        check("management/save-freezes-editor-snapshot", manager.isSaving && !editor.titleField.isEditable && !editor.promptText.text.isEditable)
        await until { !manager.isSaving }
        check("management/save-failure-keeps-input", manager.root.page == .editor && manager.root.editor?.value == initial)
        await capture("management-save-error")
        check("management/remove-failure-fixture", sql("DROP TRIGGER qa_fail_save"))
        manager.root.saveButton.performClick(nil)
        await until { !manager.isSaving && manager.root.page == .library && manager.selectedEntry?.id == initial.id }
        check("management/save-refreshes-list", manager.root.libraryView.items.count == 8 && manager.selectedEntry == initial)
        let reopened = PromptLibrary(repository: SQLitePromptRepository(url: directory.appendingPathComponent("library.sqlite3")))
        let loaded: PromptEntry? = await withCheckedContinuation { continuation in
            reopened.load(.detail(initial.categoryID, initial.id)) { result in
                if case .success(.detail(let value)) = result { continuation.resume(returning: value) } else { continuation.resume(returning: nil) }
            }
        }
        check("management/reopen-preserves-fields-and-id", loaded == initial)
        manager.root.libraryView.copyButton.performClick(nil)
        copiedChangeCount = pasteboard.changeCount
        check("management/copy-full-current-prompt", NSPasteboard.general.string(forType: .string) == initial.prompt)
        manager.root.libraryView.editButton.performClick(nil)
        await until { manager.root.page == .editor && manager.root.editor?.id == initial.id }
        if let editing = manager.root.editor {
            editing.titleField.stringValue = "编辑后 QA · 中文😀"
            editing.promptText.text.string += "\n编辑后的完整段落"
            editing.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: editing.titleField))
            let changed = editing.value
            manager.root.cancelButton.performClick(nil)
            await until { manager.root.page == .library }
            manager.root.newButton.performClick(nil)
            await until { manager.root.page == .editor }
            check("management/cancel-restores-local-draft", manager.root.editor?.value == changed)
            manager.root.saveButton.performClick(nil)
            await until { manager.root.page == .library && manager.selectedEntry == changed }
            check("management/edit-stable-id-without-duplicate", manager.root.libraryView.items.count == 8 && manager.selectedEntry?.id == initial.id)
        }
        manager.root.search.field.stringValue = "编辑后 QA"
        manager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: manager.root.search.field))
        await until { manager.root.libraryView.items.count == 1 }
        check("management/local-search-filters", manager.root.libraryView.items.first?.summary.id == initial.id)
        manager.root.stats.performClick(nil)
        await until { (manager.root.dashboard?.currentSummary.total ?? 0) >= 2 }
        check("statistics/explicit-success-events-only", (manager.root.dashboard?.currentSummary.copies ?? 0) >= 2 && manager.root.dashboard?.currentSummary.insertions == 0)
        await capture("management-statistics")
        if let dashboard = manager.root.dashboard {
            check("statistics/all-columns-fit", dashboard.table.rect(ofColumn: dashboard.table.numberOfColumns - 1).maxX <= dashboard.tableScroll.contentSize.width)
        }
        manager.root.all.performClick(nil)
        window.setContentSize(NSSize(width: 1100, height: 720)); window.center()
        await capture("management-minimum")
        check("management/minimum-layout-actions-accessible", manager.root.newButton.frame.maxX <= manager.root.band.bounds.width && manager.root.libraryView.copyButton.frame.minX >= 0)
        let beforeZoom = window.frame
        window.performMiniaturize(nil)
        await until { window.isMiniaturized }
        check("management/native-minimize", window.isMiniaturized)
        window.deminiaturize(nil)
        await until { !window.isMiniaturized }
        window.performZoom(nil)
        check("management/native-zoom", window.frame.size != beforeZoom.size)
        window.setFrame(beforeZoom, display: true)
        manager.root.editor = nil
        window.performClose(nil)
        await until { !window.isVisible }
        check("management/native-close-hides", !window.isVisible)
        backdrop.orderOut(nil); management = nil
        if pasteboard.changeCount == copiedChangeCount {
            pasteboard.clearContents()
            pasteboard.writeObjects(previousClipboard.map { values -> NSPasteboardItem in
                let item = NSPasteboardItem(); values.forEach { item.setData($0.1, forType: $0.0) }; return item
            })
        }
        return checks
    }
}
