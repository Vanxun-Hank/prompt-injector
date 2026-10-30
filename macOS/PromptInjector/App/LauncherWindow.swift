import AppKit

final class LauncherPanel: NSPanel {
    var routeKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !inputOwnsKey(event), routeKey?(event) == true { return }
        super.sendEvent(event)
    }
    private func inputOwnsKey(_ event: NSEvent) -> Bool {
        if let text = firstResponder as? NSTextView {
            if text.hasMarkedText() { return true }
            if text.isEditable { return true }
        }
        if let client = firstResponder as? NSTextInputClient, client.hasMarkedText() { return true }
        return false
    }
}

@MainActor final class LauncherWindowController: NSWindowController, NSWindowDelegate {
    let launcher: LauncherView
    let injection = InjectionService()
    let presentation = PanelPresentation()
    var isPresented: Bool { presentation.isPresented }
    private var isInserting = false
    private let geometryKey = "launcher.frame.v1"

    init(library: PromptLibrary) {
        launcher = LauncherView(library: library)
        let panel = LauncherPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 520), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        panel.title = "Prompt Injector"
        panel.identifier = .init("PromptInjector.Launcher")
        panel.minSize = NSSize(width: 360, height: 300)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = launcher
        super.init(window: panel)
        panel.delegate = self
        restoreGeometry()
        panel.routeKey = { [weak self] event in self?.handle(event) ?? false }
        launcher.onClose = { [weak self] in self?.hide() }
        launcher.onInsert = { [weak self] entry in self?.insert(entry) }
        launcher.onPermission = { AccessibilityAccess.request() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(capturing application: NSRunningApplication?) {
        guard !isInserting else { return }
        let showStart = ProcessInfo.processInfo.systemUptime
        let showID = UUID()
        DiagnosticLog.shared.write(.launcherShown, operationID: showID, fields: .init(targetBundleID: application?.bundleIdentifier))
        injection.capture(application)
        if injection.hasCapturedTarget { launcher.setInsertionFailure(nil) }
        launcher.targetName = injection.targetName
        launcher.retryFailedLoad()
        if let window {
            presentation.show(window) {
                DiagnosticLog.shared.write(.launcherSettled, operationID: showID, fields: .init(elapsedMilliseconds: Int((ProcessInfo.processInfo.systemUptime - showStart) * 1000)))
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(launcher.currentEntry == nil ? launcher.table : launcher.textView)
        DiagnosticLog.shared.write(.launcherReady, operationID: showID, fields: .init(elapsedMilliseconds: Int((ProcessInfo.processInfo.systemUptime - showStart) * 1000)))
    }
    func hide(animated: Bool = true) {
        DiagnosticLog.shared.write(.launcherHidden)
        launcher.pageTransition.cancel()
        launcher.remember()
        saveGeometry()
        if let window { presentation.hide(window, animated: animated) }
    }
    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 53 && modifiers.isEmpty { launcher.goBack(); return true }
        if event.keyCode == 36 && modifiers == [.shift] {
            if launcher.navigation.page != .categories { launcher.goBack() }
            return true
        }
        if event.keyCode == 36 && modifiers == [.command] && launcher.currentEntry != nil {
            launcher.insertPrompt(); return true
        }
        if event.keyCode == 36 && modifiers.isEmpty {
            if launcher.currentEntry == nil { launcher.openSelection() }
            return true
        }
        // NSTextView owns selection, copy, navigation and IME composition on the detail page.
        return false
    }
    private func insert(_ entry: PromptEntry) {
        guard !isInserting else { return }
        isInserting = true; launcher.insertButton.isEnabled = false
        Task { @MainActor in
            defer { isInserting = false; launcher.insertButton.isEnabled = launcher.insertionFailure == nil }
            do {
                try await injection.insert(entry.prompt, hide: { [weak self] in self?.hide(animated: false) })
                launcher.library.recordUsage(entry, kind: .insert)
            } catch {
                if let failure = error as? InjectionService.Failure, failure != .clipboard, failure != .shortcutHeld {
                    launcher.setInsertionFailure(failure)
                }
                if let window { presentation.show(window, animated: false) }
                NSApp.activate(ignoringOtherApps: true)
                launcher.showFeedback(error.localizedDescription, error: true, permission: (error as? InjectionService.Failure) == .permission, persist: true)
            }
        }
    }
    func windowDidMove(_ notification: Notification) { saveGeometry() }
    func windowDidResize(_ notification: Notification) { saveGeometry() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
    private func saveGeometry() {
        guard let frame = window?.frame else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: geometryKey)
    }
    private func restoreGeometry() {
        guard let window else { return }
        if let saved = UserDefaults.standard.string(forKey: geometryKey) {
            var frame = NSRectFromString(saved)
            guard WindowGeometry.isValidSavedFrame(frame) else {
                DiagnosticLog.shared.write(.preferenceInvalid, level: .warning, fields: .init(preference: "windowFrame"))
                UserDefaults.standard.removeObject(forKey: geometryKey)
                window.center()
                return
            }
            frame.size.width = max(frame.width, window.minSize.width)
            frame.size.height = max(frame.height, window.minSize.height)
            let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                frame.size.width = min(frame.width, visible.width)
                frame.size.height = min(frame.height, visible.height)
                frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
                frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
            }
            window.setFrame(frame, display: false)
        } else { window.center() }
    }
}
