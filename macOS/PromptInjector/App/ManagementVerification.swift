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
        @MainActor func until(_ condition: () -> Bool, line: Int = #line) async {
            for _ in 0..<300 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
            checks.append(["name": "management/async-timeout", "passed": false, "line": line])
        }
        openManagement()
        guard let manager = management, let window = manager.window else { return [["name": "management/window", "passed": false]] }
        await until { controller.window?.isVisible == false }
        check("management/separate-native-window", window !== controller.window && window.styleMask.contains(.titled))
        let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -24, dy: -24), styleMask: [.borderless], backing: .buffered, defer: false)
        backdrop.backgroundColor = Theme.hex(0x242424)
        func capture(_ name: String, target: NSWindow? = nil) async {
            if target == nil {
                backdrop.setFrame(window.frame.insetBy(dx: -24, dy: -24), display: true); backdrop.orderFront(nil)
                (window.attachedSheet ?? window).makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            }
            let captured = target ?? window
            captured.contentView?.layoutSubtreeIfNeeded()
            try? await Task.sleep(nanoseconds: 180_000_000)
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // Capture this live window even if desktop activity changes stacking or position.
            p.arguments = ["-x", "-o", "-l", String(captured.windowNumber), output + "/" + name + ".png"]
            do { try p.run(); p.waitUntilExit(); check("capture/" + name, p.terminationStatus == 0) }
            catch { check("capture/" + name, false) }
        }
        func sql(_ command: String) -> Bool {
            var db: OpaquePointer?
            guard sqlite3_open(directory.appendingPathComponent("library.sqlite3").path, &db) == SQLITE_OK else { return false }
            defer { sqlite3_close(db) }
            return sqlite3_exec(db, command, nil, nil, nil) == SQLITE_OK
        }
        await until { !manager.root.libraryView.items.isEmpty }
        check("management/regular-application", NSApp.activationPolicy() == .regular)
        // NSApplication resamples icon representations; compare pixels with 8/255 average-channel tolerance.
        func iconPixels(_ image: NSImage?) -> NSBitmapImageRep? {
            guard let image, let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 256, bitsPerPixel: 32), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.cgContext.clear(NSRect(x: 0, y: 0, width: 64, height: 64))
            image.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64))
            NSGraphicsContext.restoreGraphicsState(); return bitmap
        }
        if let actual = iconPixels(NSApp.applicationIconImage), let expected = iconPixels(DesignAssets.image("AppIcon", template: false)), let a = actual.bitmapData, let b = expected.bitmapData {
            let difference = (0..<(64 * 64 * 4)).reduce(0) { $0 + abs(Int(a[$1]) - Int(b[$1])) }
            checks.append(["name": "application/branded-icon", "passed": difference <= 8 * 64 * 64 * 4, "pixelDifference": difference])
        } else { check("application/branded-icon", false) }
        let packagedIcon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
        check("application/transparent-icon-canvas", [NSApp.applicationIconImage, DesignAssets.image("AppIcon", template: false), packagedIcon].allSatisfy { image in
            guard let bitmap = iconPixels(image) else { return false }
            return [(0, 0), (32, 0), (63, 0), (0, 32), (63, 32), (0, 63), (32, 63), (63, 63)].allSatisfy { x, y in
                (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1) < 0.01
            } && (bitmap.colorAt(x: 32, y: 32)?.alphaComponent ?? 0) > 0.95
        })
        check("management/native-window-controls", [.closeButton, .miniaturizeButton, .zoomButton].allSatisfy { window.standardWindowButton($0)?.isEnabled == true })
        check("management/initial-real-library", manager.root.libraryView.items.count == 7)
        check("assets/all-figma-assets-load", ["Logo", "Grid", "List", "ExternalLink", "Chart", "Search", "Plus", "Down", "Copy", "Edit", "Check", "Back", "Close", "Insert", "Chevron", "Status", "Dot-requirements", "Dot-coding", "Dot-debugging", "Dot-review", "Dot-release", "MenuBar", "AppIcon"].allSatisfy { DesignAssets.image($0, template: false)?.size.width ?? 0 > 0 })
        await capture("management-library")
        check("v7/grid-default-and-three-columns", manager.root.libraryView.presentation == .grid && manager.root.libraryView.grid.columnCount == 3 && manager.selectedEntry == nil)
        manager.root.libraryView.openItem(id: manager.root.libraryView.items[0].summary.id)
        await until { manager.selectedEntry != nil }
        if let entry = manager.selectedEntry {
            let alert = ManagementWindowController.deletionAlert(entry)
            alert.beginSheetModal(for: window) { _ in }
            await until { alert.buttons.allSatisfy(\.isEnabled) }
            await capture("management-delete-confirmation")
            check("management/delete-sheet-visible", alert.window.isVisible && window.attachedSheet === alert.window)
            check("management/delete-default-is-cancel", alert.buttons[0].keyEquivalent == "\r" && alert.buttons[1].keyEquivalent.isEmpty && alert.window.initialFirstResponder === alert.buttons[0])
            window.endSheet(alert.window, returnCode: .alertFirstButtonReturn); alert.window.orderOut(nil)
            let comparison = ManagementWindowController.comparisonAlert(current: entry.prompt, proposed: entry.prompt + "\n仅在能够复现时先验证。")
            comparison.beginSheetModal(for: window) { _ in }
            await until { comparison.buttons.allSatisfy(\.isEnabled) }
            await capture("management-comparison")
            check("management/comparison-sheet-visible", comparison.window.isVisible && window.attachedSheet === comparison.window)
            window.endSheet(comparison.window, returnCode: .alertFirstButtonReturn); comparison.window.orderOut(nil)
        }
        manager.newEntry()
        await until { manager.root.editor != nil }
        guard let editor = manager.root.editor else { window.orderOut(nil); management = nil; return checks }
        manager.saveEditor()
        check("management/required-fields", !manager.isSaving && !editor.titleError.isHidden && editor.titleField.currentEditor() != nil)
        editor.titleField.stringValue = "原生 QA · 中文😀"
        editor.summaryText.text.string = "本地新增、重启、编辑与搜索验证"
        editor.sourceField.stringValue = "自动化验证数据"
        editor.originalText.text.string = "保留原文\n第二行😀"
        editor.explanationText.text.string = "解释与 Prompt 独立保存。"
        editor.promptText.text.string = "仅写入原输入框，不发送。\n\n中文😀\nlet value = 1"
        let beforeReturn = editor.promptText.text.string
        window.makeFirstResponder(editor.promptText.text)
        editor.promptText.text.setSelectedRange(NSRange(location: beforeReturn.utf16.count, length: 0))
        let enter = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
        window.sendEvent(enter)
        check("management/return-edits-does-not-save", editor.promptText.text.string == beforeReturn + "\n" && !manager.isSaving)
        editor.promptText.text.string = beforeReturn
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
        let reading = manager.root.libraryView
        check("reading/prompt-only-verbatim", reading.document.text.string == initial.prompt)
        reading.segments.buttons[1].performClick(nil)
        check("reading/original-source-verbatim", reading.document.text.string == initial.source + "\n\n" + initial.originalExperience)
        await capture("management-reading-original")
        reading.segments.buttons[2].performClick(nil)
        check("reading/explanation-only", reading.document.text.string == initial.explanation)
        await capture("management-reading-explanation")
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
            await capture("management-inline-editor")
            check("v7/edit-stays-in-preview", editing.inlineMode && editing.superview === manager.root.libraryView.preview)
            window.setContentSize(NSSize(width: 1100, height: 720)); await capture("management-inline-minimum")
            check("v7/inline-minimum-fields-fit", editing.frame == manager.root.libraryView.preview.bounds && editing.content.bounds.contains(editing.promptText.frame) && manager.root.bounds.contains(manager.root.saveButton.convert(manager.root.saveButton.bounds, to: manager.root)))
            window.setContentSize(NSSize(width: 1440, height: 960))
            manager.root.cancelButton.performClick(nil)
            await until { manager.root.page == .library }
            manager.newEntry()
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
        await capture("management-grid-minimum")
        check("v7/grid-minimum-two-columns", manager.root.libraryView.grid.columnCount == 2)
        if let first = manager.root.libraryView.items.first { manager.root.libraryView.openItem(id: first.summary.id) }
        await until { manager.selectedEntry != nil }
        manager.root.libraryView.segments.buttons[0].performClick(nil)
        await capture("management-minimum")
        check("management/minimum-layout-actions-accessible", manager.root.newButton.frame.maxX <= manager.root.band.bounds.width && manager.root.libraryView.copyButton.frame.minX >= 0)
        manager.root.search.field.stringValue = ""
        manager.newEntry()
        await until { manager.root.editor != nil && manager.root.page == .editor }
        if let generationEditor = manager.root.editor {
            generationEditor.originalText.text.string = "仅对能够复现的问题，先写失败测试再修复。"
            generationEditor.sourceField.stringValue = "自动化模拟候选，未请求真实 API"
            let raw = generationEditor.value
            let candidate = GeneratedPrompt(title: "先固定复现条件", summary: "问题可复现时使用", explanation: "先用最小失败测试固定问题，再修复。", prompt: "仅在问题可复现时，先添加失败测试，确认失败后做最小修复并重跑。", categoryID: nil, newCategoryName: "学习与实验")
            generationEditor.receiveCandidate(candidate)
            check("generation/candidate-does-not-overwrite", generationEditor.value == raw)
            let candidateTitle = generationEditor.candidateEditor.fields[0].text
            candidateTitle.insertText("（审核修订）", replacementRange: NSRange(location: candidateTitle.string.utf16.count, length: 0))
            check("generation/candidate-is-editable", generationEditor.candidate?.title == candidate.title + "（审核修订）" && generationEditor.value == raw)
            await capture("management-candidate")
            generationEditor.adoptButton.performClick(nil)
            generationEditor.newCategoryField.stringValue = "学习与实验"
            check("generation/adoption-preserves-original-source", generationEditor.value.originalExperience == raw.originalExperience && generationEditor.value.source == raw.source)
            generationEditor.layoutSubtreeIfNeeded()
            generationEditor.addCategory()
            if let chooser = generationEditor.categoryChooser {
                check("categories/new-name-entire-control-visible", chooser.view.bounds.contains(chooser.nameField.convert(chooser.nameField.bounds, to: chooser.view)))
                chooser.nameField.stringValue = "  "; chooser.create()
                check("categories/blank-name-stays-inline", chooser.popover.isShown && !chooser.errorLabel.stringValue.isEmpty)
                await capture("management-category-create", target: chooser.view.window)
                chooser.nameField.stringValue = "学习与实验"
                chooser.createButton.performClick(nil)
            } else { check("categories/new-name-entire-control-visible", false) }
            await capture("management-new-category")
            manager.saveEditor()
            await until { !manager.isSaving && manager.root.page == .library && manager.root.categoryItems.count == 6 && manager.selectedEntry?.id == generationEditor.id }
            check("categories/sixth-sidebar-preview", manager.root.categoryItems.last?.label == "学习与实验" && manager.root.libraryView.categoryLabel.stringValue == "学习与实验")
            if let saved = manager.selectedEntry {
                controller.launcher.navigate(to: .entries(saved.categoryID))
                await until { !controller.launcher.isLoading }
                check("categories/sixth-launcher-list", controller.launcher.table.numberOfRows == 1)
                controller.launcher.navigate(to: .detail(saved.categoryID, saved.id))
                await until { !controller.launcher.isLoading }
                check("categories/sixth-launcher-full-prompt", controller.launcher.currentEntry == saved)
                // The external target remains simulated; this only checks the existing local copy/usage path.
                manager.root.libraryView.copyButton.performClick(nil); copiedChangeCount = pasteboard.changeCount
                manager.showStatistics()
                await until { manager.root.dashboard?.currentSummary.categoryCounts[saved.categoryID] == 1 }
                check("categories/sixth-statistics", manager.root.dashboard?.currentSummary.categoryCounts[saved.categoryID] == 1)
                await capture("management-sixth-statistics")
            }
        }
        manager.showLibrary(category: nil)
        await until { !manager.root.libraryView.items.isEmpty }
        let actualCategories = manager.root.categoryItems.map { PromptCategory(id: $0.category!, name: $0.label, symbol: "folder") }
        let many = actualCategories + (7...26).map { PromptCategory(id: "scroll-fixture-\($0)", name: "滚动测试 \($0)", symbol: "folder") }
        manager.root.setCategories(many); manager.root.layoutSubtreeIfNeeded()
        if let last = manager.root.categoryItems.last, let scroll = last.enclosingScrollView {
            let fixed = manager.root.all.frame
            last.scrollToVisible(last.bounds)
            check("categories/growing-sidebar-scroll", scroll.contentView.bounds.minY > 0 && scroll.documentVisibleRect.contains(last.frame) && manager.root.all.frame == fixed)
            await capture("management-categories-scroll")
        } else { check("categories/growing-sidebar-scroll", false) }
        manager.root.setCategories(actualCategories)
                let beforeZoom = window.frame
        window.performMiniaturize(nil)
        await until { window.isMiniaturized }
        check("management/native-minimize", window.isMiniaturized)
        window.deminiaturize(nil)
        await until { !window.isMiniaturized }
        window.performZoom(nil)
        check("management/native-zoom", window.frame.size != beforeZoom.size)
        window.setFrame(beforeZoom, display: true)
        var enteredFullScreen = false, exitedFullScreen = false
        let entered = NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { _ in enteredFullScreen = true }
        let exited = NotificationCenter.default.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { _ in exitedFullScreen = true }
        window.toggleFullScreen(nil)
        await until { enteredFullScreen }
        check("management/native-fullscreen-space", enteredFullScreen && window.styleMask.contains(.fullScreen))
        if enteredFullScreen {
            window.toggleFullScreen(nil)
            await until { exitedFullScreen }
        }
        check("management/native-fullscreen-exit", exitedFullScreen && !window.styleMask.contains(.fullScreen))
        NotificationCenter.default.removeObserver(entered); NotificationCenter.default.removeObserver(exited)
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
