import AppKit
import ApplicationServices

/// Only a user-initiated insertion may act on the input captured before showing the panel.
@MainActor final class InjectionService {
    private(set) var targetName: String?
    private var application: NSRunningApplication?
    private var element: AXUIElement?
    private var capturedText: String?
    private var capturedRange: NSRange?
    private var capturedDOMClassAvailable: Bool?
    private var capturedProseMirrorRoot: Bool?
    private var capturedEmptyComposerMarker: Bool?
    private var capturedInspectedNodeCount: Int?
    private var capturedAXValueCount: Int?
    private var capturedEmptyComposerNormalized: Bool?
    private var captureFailure: Failure?
    private var captureID: UUID?
    private var operationID: UUID?
    private var stage = "capture"
    private var activeMethod = "none"
    private var operationStart: TimeInterval?
    private let defaults: UserDefaults
    private let logger: DiagnosticLog
    private let permissionCheck: () -> Bool

    init(defaults: UserDefaults = .standard, logger: DiagnosticLog = .shared, permissionCheck: (() -> Bool)? = nil) {
        self.defaults = defaults; self.logger = logger
        self.permissionCheck = permissionCheck ?? { AccessibilityAccess.refresh() }
    }

    func capture(_ app: NSRunningApplication?) {
        application = app; element = nil; capturedText = nil; capturedRange = nil; captureFailure = .noTextFocus
        capturedDOMClassAvailable = nil; capturedProseMirrorRoot = nil; capturedEmptyComposerMarker = nil; capturedInspectedNodeCount = nil
        capturedAXValueCount = nil; capturedEmptyComposerNormalized = nil
        captureID = UUID(); operationID = nil; operationStart = nil; stage = "capture"; activeMethod = "none"
        targetName = app?.localizedName
        record("capture-started", method: "none")
        guard permissionCheck() else { captureFailure = .permission; record("capture-failed", method: "none", failure: "permission"); return }
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { record("capture-failed", method: "none", failure: "noExternalTarget"); return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { record("capture-failed", method: "none", failure: "noFocusedElement"); return }
        let target = value as! AXUIElement
        let role = string(kAXRoleAttribute, from: target)
        guard !TargetCapabilities.isNonTextControl(role) else {
            captureFailure = .noTextFocus
            record("capture-unsupported", method: "none", role: role, failure: "nonTextControl")
            return
        }
        let secure = string(kAXSubroleAttribute, from: target) == kAXSecureTextFieldSubrole
        guard !secure else {
            captureFailure = .unsupported
            record("capture-unsupported", method: "none", role: role, failure: "secureInput")
            return
        }
        var selectedTextWritable = DarwinBoolean(false), valueWritable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(target, kAXSelectedTextAttribute as CFString, &selectedTextWritable)
        AXUIElementIsAttributeSettable(target, kAXValueAttribute as CFString, &valueWritable)
        let enabled = boolean(kAXEnabledAttribute, from: target)
        let editable = boolean("AXEditable", from: target)
        let method = InsertionMethod.forApplication(app.bundleIdentifier)
        let text = readContents(from: target, recordingCapture: true)
        let range = selection(in: target)
        // Custom editors may expose an editable AXGroup. Use capabilities, not role alone.
        let capabilities = TargetCapabilities(role: role, isSecure: secure, textReadable: text != nil, selectionReadable: range != nil,
                                              selectionWritable: selectedTextWritable.boolValue, valueWritable: valueWritable.boolValue, isEnabled: enabled, isEditable: editable, method: method)
        var diagnostics = ["textReadable": text != nil, "selectionReadable": range != nil, "selectionWritable": selectedTextWritable.boolValue, "valueWritable": valueWritable.boolValue]
        diagnostics["targetEnabled"] = enabled
        diagnostics["targetEditable"] = editable
        guard capabilities.supportsInsertion,
              let text, let range else {
            captureFailure = .unsupported
            record("capture-unsupported", method: method.rawValue, role: role, capabilities: diagnostics, failure: "unsupportedCapabilities")
            return
        }
        element = target; capturedText = text; capturedRange = range; captureFailure = nil
        record("captured", method: method.rawValue, before: text, role: role, capabilities: diagnostics)
    }

    enum Failure: String, LocalizedError {
        case permission, recaptureRequired, targetLost, noTextFocus, unsupported, changed, notVerified, shortcutHeld, clipboard
        var errorDescription: String? {
            switch self {
            case .permission: return "需要辅助功能权限。"
            case .recaptureRequired: return "权限已生效，请回到输入框后重新唤起。"
            case .targetLost: return "原输入框已失效，请回到输入框后重新唤起。"
            case .noTextFocus: return "未选中输入框。请收起浮窗，点击输入框后重新唤起。"
            case .unsupported: return "此输入框暂不支持自动插入，请复制。"
            case .changed: return "输入框内容或选区已变化，请重新唤起。"
            case .notVerified: return "未能确认插入结果，请检查原输入框，勿重复插入。"
            case .shortcutHeld: return "请松开快捷键后重试。"
            case .clipboard: return "剪贴板已变化或暂不可用，请重试。"
            }
        }
    }

    func insert(_ text: String, hide: () -> Void) async throws {
        operationID = UUID(); operationStart = ProcessInfo.processInfo.systemUptime
        stage = "permission"; activeMethod = InsertionMethod.forApplication(application?.bundleIdentifier).rawValue
        record("started", method: activeMethod, before: capturedText)
        do {
            try await performInsert(text, hide: hide)
        } catch {
            let code = (error as? Failure)?.rawValue ?? (error is CancellationError ? "cancelled" : "internal")
            record("failed", method: activeMethod, before: capturedText, failure: code)
            throw error
        }
    }

    private func performInsert(_ text: String, hide: () -> Void) async throws {
        let granted = permissionCheck()
        if granted && captureFailure != .permission { setStage("captureValidation") }
        if let failure = InsertionPreflight.failure(permissionGranted: granted, captureFailure: captureFailure) { throw failure }
        setStage("target")
        guard let app = application, !app.isTerminated, let target = element,
              let before = capturedText, let range = capturedRange else { throw Failure.targetLost }
        guard let plan = InsertionPlan(before: before, range: range, prompt: text) else { throw Failure.unsupported }
        // Keep the Return key-up and any held-key repeat in our window, not in the destination composer.
        setStage("shortcutRelease")
        try await waitForShortcutRelease()
        setStage("beforeActivation")
        try validateContents(target, plan: plan)
        hide()
        setStage("activation")
        guard app.activate(options: []) else { throw Failure.targetLost }
        try await Task.sleep(nanoseconds: 180_000_000)
        setStage("focusValidation")
        try validateFocus(target, application: app)
        try validateContents(target, plan: plan)

        let method = activeMethod
        setStage("writePreparation")
        var transaction: PasteboardTransaction?
        if method == "paste" {
            let source = CGEventSource(stateID: .privateState)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { throw Failure.unsupported }
            do { transaction = try PasteboardTransaction(text: text) }
            catch { throw Failure.clipboard }
            do {
                try validateFocus(target, application: app)
                try validateContents(target, plan: plan)
                guard transaction?.stillOwned == true else { throw Failure.clipboard }
            } catch {
                if let transaction { recordClipboardRestoration(transaction.restoreIfOwned()) }
                throw error
            }
            down.flags = .maskCommand; up.flags = []
            // The only synthesized keys are V down/up. Never synthesize Return or a submit action.
            down.postToPid(app.processIdentifier); up.postToPid(app.processIdentifier)
        } else {
            var writable = DarwinBoolean(false)
            AXUIElementIsAttributeSettable(target, kAXSelectedTextAttribute as CFString, &writable)
            guard writable.boolValue,
                  AXUIElementSetAttributeValue(target, kAXSelectedTextAttribute as CFString, text as CFString) == .success else {
                throw Failure.unsupported
            }
        }
        stage = "verification"
        record("write-requested", method: method, before: before)
        var observed: String?
        for _ in 0..<24 {
            try await Task.sleep(nanoseconds: 50_000_000)
            observed = readContents(from: target)
            if let observed, plan.matches(observed) {
                if let transaction { recordClipboardRestoration(transaction.restoreIfOwned()) }
                record("verified", method: method, before: before, observed: observed)
                return
            }
        }
        // A timeout is ambiguous: no fallback, no retry, and leave the paste payload available.
        // Restoring here could race a destination that has not yet consumed its paste event.
        record("not-verified", method: method, before: before, observed: observed, observation: observed.map { InsertionObservation(expected: plan.expected, observed: $0) })
        throw Failure.notVerified
    }

    private func waitForShortcutRelease() async throws {
        for _ in 0..<100 {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let modifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            if !CGEventSource.keyState(.combinedSessionState, key: 36),
               !CGEventSource.keyState(.combinedSessionState, key: 76), flags.intersection(modifiers).isEmpty { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw Failure.shortcutHeld
    }
    private func validateFocus(_ target: AXUIElement, application app: NSRunningApplication) throws {
        guard !app.isTerminated, NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw Failure.targetLost }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFEqual(focused, target) else { throw Failure.targetLost }
    }
    private func validateContents(_ target: AXUIElement, plan: InsertionPlan) throws {
        guard let value = readContents(from: target), let range = selection(in: target) else { throw Failure.targetLost }
        guard value == plan.before, range == plan.range else { throw Failure.changed }
    }
    private func readContents(from target: AXUIElement, recordingCapture: Bool = false) -> String? {
        guard let value = string(kAXValueAttribute, from: target) else { return nil }
        let range = selection(in: target)
        let role = string(kAXRoleAttribute, from: target)
        let bundleID = application?.bundleIdentifier
        let structure = bundleID == "com.openai.codex" && role == "AXTextArea" && range == NSRange(location: 0, length: 0) && !value.isEmpty
            ? inspectComposerStructure(in: target) : nil
        if recordingCapture {
            capturedDOMClassAvailable = structure?.available
            capturedProseMirrorRoot = structure?.root
            capturedEmptyComposerMarker = structure?.empty
            capturedInspectedNodeCount = structure?.nodeCount
        }
        if recordingCapture { capturedAXValueCount = value.utf16.count }
        guard let resolved = TargetText.resolved(value: value, selection: range, bundleID: bundleID, role: role, emptyComposerMarker: structure?.empty == true) else { return nil }
        // Reject a torn read instead of treating changing real text as an empty composer.
        if resolved != value {
            guard string(kAXValueAttribute, from: target) == value, selection(in: target) == range else { return nil }
        }
        if recordingCapture { capturedEmptyComposerNormalized = resolved != value }
        return resolved
    }
    private func boolean(_ attribute: String, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return (value as? NSNumber)?.boolValue
    }
    private func string(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
    private func selection(in element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
    private func inspectComposerStructure(in target: AXUIElement) -> (available: Bool, root: Bool, empty: Bool, nodeCount: Int) {
        var nodes = [target], index = 0
        var rootClasses: [String]?, descendants: [[String]] = []
        var available = false
        while index < nodes.count && index < 32 {
            let node = nodes[index]
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, "AXDOMClassList" as CFString, &value) == .success, let classes = value as? [String] {
                available = true
                if index == 0 { rootClasses = classes } else { descendants.append(classes) }
            }
            value = nil
            if nodes.count < 32, AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &value) == .success, let children = value as? [AnyObject] {
                for child in children.prefix(32 - nodes.count) where CFGetTypeID(child) == AXUIElementGetTypeID() {
                    nodes.append(child as! AXUIElement)
                }
            }
            index += 1
        }
        assert(index <= 32)
        return (available, rootClasses?.contains("ProseMirror") == true,
                TargetCapabilities.hasEmptyComposerMarker(rootClasses: rootClasses, descendantClasses: descendants), index)
    }
    private func setStage(_ value: String) {
        stage = value
        record("stage", method: activeMethod)
    }
    private func recordClipboardRestoration(_ restored: Bool) {
        logger.write(restored ? .clipboardRestored : .clipboardKept, operationID: operationID,
                                   fields: .init(captureID: captureID, stage: stage, result: restored ? "restored" : "ownershipChanged"))
    }
    private func record(_ status: String, method: String, before: String? = nil, observed: String? = nil, role: String? = nil, capabilities: [String: Bool]? = nil, failure: String? = nil, observation: InsertionObservation? = nil) {
        var data: [String: Any] = ["status": status, "method": method, "checkedAt": Date()]
        data["stage"] = stage
        data["captureID"] = captureID?.uuidString
        data["operationID"] = operationID?.uuidString
        data["errorCode"] = failure
        data["executionMode"] = CommandLine.arguments.contains("--verify-ui") ? "ui-verification" : "application"
        data["buildID"] = BuildIdentity.current.buildID
        if let before { data["beforeUTF16Count"] = (before as NSString).length }
        if let observed { data["observedUTF16Count"] = (observed as NSString).length }
        if let role { data["role"] = role }
        if let capabilities { data["capabilities"] = capabilities }
        defaults.set(data, forKey: "insertion.lastResult")
        let event: DiagnosticEvent
        switch status {
        case "capture-started": event = .captureStarted
        case "captured": event = .captureReady
        case "capture-failed", "capture-unsupported": event = .captureFailed
        case "started": event = .insertionStarted
        case "write-requested": event = .writeRequested
        case "verified": event = .insertionVerified
        case "not-verified": event = .insertionUnconfirmed
        case "failed": event = .insertionFailed
        default: event = .insertionStage
        }
        logger.write(event, level: event == .insertionFailed || event == .insertionUnconfirmed ? .error : event == .captureFailed ? .warning : .info,
                                   operationID: operationID,
                                   fields: .init(captureID: captureID, stage: stage, result: status, errorCode: failure, method: method,
                                                 targetBundleID: application?.bundleIdentifier, role: role,
                                                 beforeUTF16Count: before.map { ($0 as NSString).length },
                                                 observedUTF16Count: observed.map { ($0 as NSString).length },
                                                 textReadable: capabilities?["textReadable"], selectionReadable: capabilities?["selectionReadable"],
                                                 selectionWritable: capabilities?["selectionWritable"], valueWritable: capabilities?["valueWritable"],
                                                 targetEnabled: capabilities?["targetEnabled"], targetEditable: capabilities?["targetEditable"],
                                                 elapsedMilliseconds: operationStart.map { Int((ProcessInfo.processInfo.systemUptime - $0) * 1000) },
                                                 selectionLocation: capturedRange?.location, selectionLength: capturedRange?.length,
                                                 expectedUTF16Count: observation?.expectedUTF16Count,
                                                 expectedLineBreakCount: observation?.expectedLineBreakCount,
                                                 observedLineBreakCount: observation?.observedLineBreakCount,
                                                 matchesCollapsingBlankLines: observation?.matchesCollapsingBlankLines,
                                                 matchesIgnoringLineBreaks: observation?.matchesIgnoringLineBreaks,
                                                 domClassMetadataAvailable: capturedDOMClassAvailable,
                                                 proseMirrorRootSeen: capturedProseMirrorRoot,
                                                 emptyComposerMarkerSeen: capturedEmptyComposerMarker,
                                                 inspectedNodeCount: capturedInspectedNodeCount,
                                                 axValueUTF16Count: capturedAXValueCount,
                                                 emptyComposerNormalized: capturedEmptyComposerNormalized))
    }
}
