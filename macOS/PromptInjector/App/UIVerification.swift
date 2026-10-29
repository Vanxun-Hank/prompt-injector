import AppKit

// Opt-in development verification. Captures a live WindowServer window, never a static rendering.
extension AppDelegate {
    @MainActor func runVerification() {
        Task { @MainActor in
            guard let controller, let window = controller.window else { return }
            let args = CommandLine.arguments
            let output: String
            if let index = args.firstIndex(of: "--qa-output"), args.count > index + 1 { output = args[index + 1] }
            else { output = FileManager.default.currentDirectoryPath + "/artifacts/ui" }
            try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
            var checks: [[String: Any]] = []
            func check(_ name: String, _ passed: Bool) { checks.append(["name": name, "passed": passed]) }
            @MainActor func ready(_ target: LauncherView? = nil) async {
                let view = target ?? controller.launcher
                for _ in 0..<300 {
                    if !view.isLoading { return }
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                check("storage/page-load-timeout", false)
            }
            func settle() async { await ready(); try? await Task.sleep(nanoseconds: 350_000_000) }
            @MainActor func key(_ code: UInt16, _ modifiers: NSEvent.ModifierFlags = []) async {
                let character = code == 36 ? "\r" : code == 125 ? String(UnicodeScalar(NSDownArrowFunctionKey)!) : code == 126 ? String(UnicodeScalar(NSUpArrowFunctionKey)!) : "\u{1b}"
                let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code)!
                window.sendEvent(event)
                await ready()
            }
            @MainActor func capture(_ name: String) async {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                await settle()
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                let f = name == "default-shell" ? window.frame.insetBy(dx: -24, dy: -24) : window.frame
                let screenTop = NSScreen.screens.first?.frame.maxY ?? 0
                p.arguments = ["-x", "-R", "\(Int(f.minX)),\(Int(screenTop-f.maxY)),\(Int(f.width)),\(Int(f.height))", output + "/" + name + ".png"]
                do { try p.run(); p.waitUntilExit(); check("capture/" + name, p.terminationStatus == 0) }
                catch { check("capture/" + name, false) }
            }
            let original = window.frame
            let v = controller.launcher
            v.targetName = "Codex"
            // Controlled real window behind the panel: test color transmission without exposing user documents.
            let backdrop = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
            backdrop.backgroundColor = NSColor(calibratedWhite: 0.095, alpha: 1)
            let colorBlock = NSView(frame: NSRect(x: 0, y: 0, width: 410, height: 800))
            colorBlock.wantsLayer = true; colorBlock.layer?.backgroundColor = NSColor(calibratedRed: 0.45, green: 0.15, blue: 0.3, alpha: 1).cgColor
            backdrop.contentView?.addSubview(colorBlock)
            let backgroundText = Theme.label("Background legibility verification", size: 30)
            backgroundText.frame = NSRect(x: 80, y: 370, width: 800, height: 60)
            backdrop.contentView?.addSubview(backgroundText)
            backdrop.center(); backdrop.orderFront(nil)
            for (name, size) in [("minimum", NSSize(width: 360, height: 300)), ("default", NSSize(width: 620, height: 520)), ("large", NSSize(width: 900, height: 700))] {
                window.setContentSize(size); window.center()
                v.navigate(to: .categories, animate: false)
            await ready()
                window.makeFirstResponder(v.table)
                v.table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
                await settle()
                v.table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
                await capture(name + "-categories")
                if name == "default" { await capture("default-shell") }
                v.table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
                await key(36)
                check(name + "/return-enters-list", v.navigation.page == .entries("debugging"))
                await settle(); await capture(name + "-list")
                v.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                await key(125)
                check(name + "/down-selects-next", v.table.selectedRow == 1)
                await key(126)
                check(name + "/up-selects-previous", v.table.selectedRow == 0)
                await key(36)
                await settle(); await capture(name + "-detail")
                check(name + "/fixed-actions", v.insertButton.frame.maxX <= v.footer.bounds.maxX && v.insertButton.frame.minY >= 0)
                check(name + "/text-width", v.textView.frame.width <= v.detailScroll.contentSize.width + 1)
                await key(36)
                check(name + "/plain-return-does-not-insert", window.isVisible && v.currentEntry?.id == "debug-root-cause")
                await key(53)
                check(name + "/escape-restores-list-selection", v.navigation.page == .entries("debugging") && v.table.selectedRow == 0)
                await key(53)
                check(name + "/escape-restores-category-selection", v.navigation.page == .categories && v.table.selectedRow == 2)
                v.navigate(to: .entries("debugging"), animate: false)
            await ready()
                await key(36, [.shift])
                check(name + "/shift-return-goes-back", v.navigation.page == .categories)
                await key(36, [.shift])
                check(name + "/shift-return-home-noop", window.isVisible && v.navigation.page == .categories)
            }
            v.navigate(to: .detail("debugging", "debug-root-cause"), animate: false)
            await ready()
            let pageFrame = window.frame, headerFrame = v.header.frame, footerFrame = v.footer.frame
            v.pageTransition.reduceMotion = { false }
            v.goBack()
            await ready()
            check("page-motion/backward-starts", v.listScroll.layer?.animation(forKey: "page-arrival") != nil)
            v.openSelection()
            await ready()
            check("page-motion/forward-starts", v.detailScroll.layer?.animation(forKey: "page-arrival") != nil)
            v.navigate(to: .entries("debugging")); v.navigate(to: .detail("debugging", "debug-root-cause")); v.navigate(to: .entries("debugging")); v.navigate(to: .detail("debugging", "debug-root-cause"))
            await settle()
            check("page-motion/rapid-navigation-preserves-state", v.currentEntry?.id == "debug-root-cause" && v.navigation.page == .detail("debugging", "debug-root-cause"))
            check("page-motion/snapshot-cleaned", !v.pageTransition.hasSnapshot && v.contentHost.subviews.count == 2)
            check("page-motion/chrome-stays-still", window.frame == pageFrame && v.header.frame == headerFrame && v.footer.frame == footerFrame)
            v.pageTransition.reduceMotion = { true }
            v.goBack()
            await ready()
            check("page-motion/reduced-motion", v.listScroll.layer?.animation(forKey: "page-arrival") == nil && !v.pageTransition.hasSnapshot)
            v.pageTransition.reduceMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
            v.navigate(to: .detail("debugging", "debug-root-cause"), animate: false)
            await ready()
            let originalInsert = v.onInsert
            var routedPrompt: String?
            v.onInsert = { routedPrompt = $0.prompt }
            await key(36)
            check("keyboard/detail-return-does-not-route-insertion", routedPrompt == nil)
            await key(36, [.command])
            check("keyboard/command-return-routes-current-prompt", routedPrompt == v.currentEntry?.prompt && routedPrompt != nil)
            v.onInsert = originalInsert
            let pasteboard = NSPasteboard.general
            let backup = pasteboard.pasteboardItems?.map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } } ?? []
            v.copyPrompt()
            let copiedChangeCount = pasteboard.changeCount
            check("copy/actual-pasteboard", pasteboard.string(forType: .string) == v.currentEntry?.prompt)
            if pasteboard.changeCount == copiedChangeCount {
                pasteboard.clearContents()
                let items = backup.map { values -> NSPasteboardItem in
                    let item = NSPasteboardItem(); values.forEach { item.setData($0.1, forType: $0.0) }; return item
                }
                pasteboard.writeObjects(items)
            }
            v.detailScroll.contentView.scroll(to: NSPoint(x: 0, y: 120)); v.remember()
            v.goBack(); await ready(); v.navigate(to: .detail("debugging", "debug-root-cause"), animate: false); await ready()
            check("navigation/detail-scroll-restored", abs(v.detailScroll.contentView.bounds.origin.y - 120) < 2)
            v.applyAccessibilityAppearance(reduceTransparency: true, increaseContrast: false)
            check("accessibility/reduced-transparency", v.material.isHidden && v.tint.layer?.backgroundColor?.alpha == 1)
            v.updateAccessibilityAppearance()
            let editable = NSTextView(frame: NSRect(x: 30, y: 100, width: 100, height: 30))
            v.addSubview(editable); window.makeFirstResponder(editable)
            let beforePage = v.navigation.page
            editable.setMarkedText("拼音", selectedRange: NSRange(location: 0, length: 2), replacementRange: NSRange(location: NSNotFound, length: 0))
            await key(36)
            check("keyboard/composition-not-routed", v.navigation.page == beforePage)
            await key(53)
            check("keyboard/editable-escape-not-routed", v.navigation.page == beforePage)
            editable.removeFromSuperview()
            let stressEntry = PromptEntry(id: "stress", categoryID: "debugging", title: String(repeating: "中文长标题与长英文identifier边界检查", count: 4), summary: "多行内容", originalExperience: String(repeating: "保留原始经验，验证窄窗口中中文和长英文能够自动换行。", count: 8), source: "验证数据", explanation: "检查布局，不修改正式条目。", prompt: "普通文字\n```swift\n" + String(repeating: "identifier", count: 24) + "\n```\n" + String(repeating: "多行 Prompt 正文。\n", count: 30))
            let stress = LauncherView(library: PromptLibrary(entries: [stressEntry]))
            window.contentView = stress; window.setContentSize(NSSize(width: 360, height: 300)); window.center()
            stress.navigate(to: .detail("debugging", "stress"), animate: false)
            await ready(stress); await settle(); await capture("minimum-long-content")
            if let container = stress.textView.textContainer, let layout = stress.textView.layoutManager {
                layout.ensureLayout(for: container)
                check("layout/long-content-no-horizontal-overflow", layout.usedRect(for: container).maxX <= container.containerSize.width + 1)
            }
            window.contentView = v
            let testService = InjectionService()
            do { try await testService.insert("UI verification", hide: {}); check("insertion/invalid-request-rejected", false) }
            catch InjectionService.Failure.permission { check("insertion/permission-denied", !AXIsProcessTrusted()) }
            catch InjectionService.Failure.targetLost { check("insertion/missing-target-rejected", AXIsProcessTrusted()) }
            catch { check("insertion/unexpected-error", false) }
            window.setContentSize(NSSize(width: 360, height: 300)); window.center()
            v.navigate(to: .detail("debugging", "debug-root-cause"), animate: false)
            await ready()
            v.showFeedback("需要辅助功能权限。", error: true, permission: true, persist: true)
            await settle(); await capture("minimum-permission-error")
            v.showFeedback("原输入框已失效，请重新唤起。", error: true, persist: true)
            await settle(); await capture("minimum-target-error")
            check("error/actions-remain-visible", !v.copyButton.isHidden && v.copyButton.frame.minY >= 0 && !v.insertButton.isHidden)
            let visible = NSScreen.main?.visibleFrame ?? original
            let requestedFrame = NSRect(x: visible.midX - 340, y: visible.midY - 280, width: 680, height: 560)
            window.setFrame(requestedFrame, display: true)
            let saved = window.frame // AppKit aligns fractional origins to the backing pixel grid.
            controller.hide(); controller.show(capturing: nil)
            await settle()
            checks.append(["name": "window/reopen-restores-frame", "passed": window.frame == saved, "expected": NSStringFromRect(saved), "actual": NSStringFromRect(window.frame)])
            toggle()
            await settle()
            check("toggle/visible-hides", !window.isVisible)
            toggle()
            await settle()
            check("toggle/hidden-shows", window.isVisible)
            controller.hide(); controller.show(capturing: nil); controller.hide(); controller.show(capturing: nil)
            await settle()
            check("motion/interrupted-show-remains-visible", window.isVisible && window.alphaValue == 1 && !window.ignoresMouseEvents)
            checks.append(["name": "motion/geometry-unchanged", "passed": window.frame == saved, "expected": NSStringFromRect(saved), "actual": NSStringFromRect(window.frame)])
            controller.presentation.reduceMotion = { true }
            controller.hide()
            check("motion/reduced-hide-is-immediate", !window.isVisible)
            controller.show(capturing: nil)
            check("motion/reduced-show-is-opaque", window.isVisible && window.alphaValue == 1)
            controller.presentation.reduceMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
            var completedShows = 0
            controller.presentation.reduceMotion = { false }
            controller.presentation.hide(window, animated: false)
            controller.presentation.show(window, completion: { completedShows += 1 })
            controller.presentation.hide(window, animated: false)
            await settle()
            check("motion/cancelled-show-does-not-report-completion", completedShows == 0)
            controller.presentation.show(window, animated: false, completion: { completedShows += 1 })
            check("motion/immediate-show-completes-once", completedShows == 1)
            controller.presentation.reduceMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
            let second = LauncherWindowController(library: controller.launcher.library)
            checks.append(["name": "window/new-controller-restores-frame", "passed": second.window?.frame == saved, "expected": NSStringFromRect(saved), "actual": NSStringFromRect(second.window?.frame ?? .zero)])
            window.setFrame(original, display: true)
            v.navigate(to: .categories, animate: false)
            await ready()
            backdrop.orderOut(nil)
            let report: [String: Any] = ["buildID": BuildIdentity.current.buildID, "sourceFingerprint": BuildIdentity.current.sourceFingerprint, "sessionID": DiagnosticLog.shared.sessionID.uuidString, "completedAt": ISO8601DateFormatter().string(from: Date()), "checks": checks, "passed": checks.allSatisfy { $0["passed"] as? Bool == true }, "capture": "Live macOS desktop region with a controlled backdrop window", "macOS": ProcessInfo.processInfo.operatingSystemVersionString, "notVerified": ["Codex real input insertion and target loss after capture (requires app accessibility permission)", "Chinese input-source candidate selection (marked-text guard tested)", "manual edge/corner dragging", "changing global system reduced transparency setting (rendering path tested directly)"]]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: output + "/report.json"))
            }
            if let directory = verificationDatabaseDirectory { try? FileManager.default.removeItem(at: directory) }
            NSApp.terminate(nil)
        }
    }
}
