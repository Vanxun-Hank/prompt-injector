import AppKit
import Carbon

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var verificationDatabaseDirectory: URL?
    var controller: LauncherWindowController?
    var management: ManagementWindowController?
    private var status: NSStatusItem?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var lastExternalApp: NSRunningApplication?
    private var shortcutItems: [NSMenuItem] = []
    private var openItem: NSMenuItem?
    private var terminationReady = false
    private var terminationInProgress = false
    private var applicationLibrary: PromptLibrary?
    private var selectedShortcut: Int { ShortcutPreference.resolve(UserDefaults.standard.integer(forKey: "launcher.shortcut.v1"), optionCount: shortcutOptions.count) }
    private let shortcutOptions: [(title: String, carbon: UInt32, cocoa: NSEvent.ModifierFlags)] = [
        ("⇧⌥Space", UInt32(shiftKey | optionKey), [.shift, .option]),
        ("⌃⇧Space", UInt32(controlKey | shiftKey), [.control, .shift])
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DiagnosticLog.shared.write(.appStarted)
        if let index = CommandLine.arguments.firstIndex(of: "--verify-termination"), CommandLine.arguments.count > index + 1 {
            // Headless process regression: no window, menu, shortcut registration or external target capture.
            let library = PromptLibrary(repository: SQLitePromptRepository(url: URL(fileURLWithPath: CommandLine.arguments[index + 1])))
            applicationLibrary = library
            if let entry = try? PromptSeed.entries().first { library.recordUsage(entry, kind: .copy) }
            Task { @MainActor in NSApp.terminate(nil) }
            return
        }
        if let icon = DesignAssets.image("AppIcon", template: false) { NSApp.applicationIconImage = icon }
        let storedShortcut = UserDefaults.standard.integer(forKey: "launcher.shortcut.v1")
        if storedShortcut != selectedShortcut {
            DiagnosticLog.shared.write(.preferenceInvalid, level: .warning, fields: .init(shortcutIndex: storedShortcut, preference: "shortcut"))
            UserDefaults.standard.set(selectedShortcut, forKey: "launcher.shortcut.v1")
        }
        AccessibilityAccess.refresh()
        lastExternalApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        let library: PromptLibrary
        if CommandLine.arguments.contains("--verify-ui") {
            // Runtime verification never opens or seeds the user's database.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("PromptInjector-QA-" + UUID().uuidString).appendingPathComponent("library.sqlite3")
            verificationDatabaseDirectory = url.deletingLastPathComponent()
            library = PromptLibrary(repository: SQLitePromptRepository(url: url))
        } else { library = PromptLibrary() }
        applicationLibrary = library
        controller = LauncherWindowController(library: library)
        setupMenu()
        if !CommandLine.arguments.contains("--verify-ui") { registerShortcut() }
        if CommandLine.arguments.contains("--manage") { openManagement() }
        else if !CommandLine.arguments.contains("--start-hidden") {
            controller?.show(capturing: CommandLine.arguments.contains("--verify-ui") ? nil : externalTarget())
        }
        if CommandLine.arguments.contains("--verify-ui") { runVerification() }
    }
    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        lastExternalApp = app
    }
    private func externalTarget() -> NSRunningApplication? {
        if CommandLine.arguments.contains("--verify-ui") { return nil }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { return front }
        return lastExternalApp
    }
    @objc func toggle() {
        guard let controller else { return }
        if controller.isPresented { controller.hide() }
        else { controller.show(capturing: externalTarget()) }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc func openManagement() {
        guard let controller else { return }
        if controller.isPresented { controller.hide() }
        if management == nil { management = ManagementWindowController(library: controller.launcher.library) }
        management?.show()
    }
    @objc private func openStatistics() { openManagement(); management?.showStatistics() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationReady { return .terminateNow }
        if terminationInProgress { return .terminateCancel }
        guard let library = applicationLibrary else { return .terminateNow }
        terminationInProgress = true
        DiagnosticLog.shared.write(.appStopping, fields: .init(stage: "drain-library"))
        let finish: (Bool) -> Void = { [weak self] saved in
            guard let self else { return }
            guard saved else { self.terminationInProgress = false; self.management?.show(); return }
            library.flush { [weak self] in
                self?.terminationReady = true; self?.terminationInProgress = false
                NSApp.terminate(nil)
            }
        }
        if let management, management.needsTerminationSave {
            management.prepareForTermination(finish)
        } else { finish(true) }
        // Unwind the current task before durable writes finish; terminateLater's modal loop blocks their main-queue callbacks.
        return .terminateCancel
    }
    @objc private func requestAccessibility() { AccessibilityAccess.request() }
    func applicationDidBecomeActive(_ notification: Notification) { AccessibilityAccess.refresh() }
    private func setupMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menuIcon = DesignAssets.image("MenuBar")
        menuIcon?.size = NSSize(width: 18, height: 18)
        status?.button?.image = menuIcon
        status?.button?.setAccessibilityLabel("Prompt Injector")
        status?.button?.toolTip = "Prompt Injector"
        let menu = NSMenu()
        let open = NSMenuItem(title: "显示 / 隐藏 Prompt Injector", action: #selector(toggle), keyEquivalent: " ")
        open.keyEquivalentModifierMask = shortcutOptions[min(selectedShortcut, shortcutOptions.count - 1)].cocoa
        open.target = self; menu.addItem(open)
        openItem = open
        let manage = NSMenuItem(title: "管理内容…", action: #selector(openManagement), keyEquivalent: ",")
        manage.target = self; menu.addItem(manage)
        let statistics = NSMenuItem(title: "使用统计", action: #selector(openStatistics), keyEquivalent: "")
        statistics.target = self; menu.addItem(statistics)
        menu.addItem(.separator())
        let shortcuts = NSMenu(title: "唤醒快捷键")
        for (index, option) in shortcutOptions.enumerated() {
            let item = NSMenuItem(title: option.title, action: #selector(changeShortcut(_:)), keyEquivalent: "")
            item.target = self; item.tag = index; item.state = index == selectedShortcut ? .on : .off
            shortcutItems.append(item); shortcuts.addItem(item)
        }
        let shortcutsItem = NSMenuItem(title: "唤醒快捷键", action: nil, keyEquivalent: "")
        shortcutsItem.submenu = shortcuts; menu.addItem(shortcutsItem)
        let permission = NSMenuItem(title: "辅助功能权限…", action: #selector(requestAccessibility), keyEquivalent: "")
        permission.target = self; menu.addItem(permission)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        status?.menu = menu
        let main = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = menu.copy() as? NSMenu
        main.addItem(appItem)
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z"); redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        let windows = NSMenu(title: "窗口")
        windows.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fullScreen = windows.addItem(withTitle: "进入／退出全屏幕", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.control, .command]
        let windowItem = NSMenuItem(); windowItem.submenu = windows; main.addItem(windowItem)
        NSApp.mainMenu = main
    }
    private func registerShortcut() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let app = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            DispatchQueue.main.async { app.toggle() }
            return noErr
        }, 1, &spec, pointer, &hotKeyHandler)
        guard handlerStatus == noErr else {
            DiagnosticLog.shared.write(.shortcutFailed, level: .error, fields: .init(stage: "handler", systemCode: Int(handlerStatus)))
            controller?.launcher.showFeedback("快捷键不可用，可从菜单栏打开。", error: true, persist: true)
            return
        }
        installShortcut(min(selectedShortcut, shortcutOptions.count - 1))
    }
    @objc private func changeShortcut(_ sender: NSMenuItem) { installShortcut(sender.tag) }
    private func installShortcut(_ index: Int) {
        guard shortcutOptions.indices.contains(index) else { return }
        if hotKey != nil && selectedShortcut == index { return }
        var candidate: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(kVK_Space), shortcutOptions[index].carbon, EventHotKeyID(signature: 0x50494E4A, id: UInt32(index + 1)), GetApplicationEventTarget(), 0, &candidate)
        if result == noErr {
            DiagnosticLog.shared.write(.shortcutRegistered, fields: .init(shortcutIndex: index))
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = candidate
            UserDefaults.standard.set(index, forKey: "launcher.shortcut.v1")
            shortcutItems.forEach { $0.state = $0.tag == index ? .on : .off }
            openItem?.keyEquivalentModifierMask = shortcutOptions[index].cocoa
        }
        if result != noErr {
            DiagnosticLog.shared.write(.shortcutFailed, level: .error, fields: .init(stage: "registration", systemCode: Int(result), shortcutIndex: index))
            controller?.launcher.showFeedback("快捷键被占用，可从菜单栏打开。", error: true, persist: true)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if management != nil { openManagement() }
        else if !flag { controller?.show(capturing: externalTarget()) }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        DiagnosticLog.shared.write(.appStopped)
        DiagnosticLog.shared.flush()
    }
}
