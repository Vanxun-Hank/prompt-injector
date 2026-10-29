import AppKit
import ApplicationServices

@MainActor enum AccessibilityAccess {
    private static var lastLoggedTrust: Bool?
    /// This is the running application's status, not the Settings toggle or a helper's permission.
    @discardableResult static func refresh() -> Bool {
        let trusted = AXIsProcessTrusted()
        if lastLoggedTrust != trusted {
            DiagnosticLog.shared.write(.permissionChanged, fields: .init(trusted: trusted))
            lastLoggedTrust = trusted
        }
        UserDefaults.standard.set([
            "trusted": trusted,
            "pid": Int(ProcessInfo.processInfo.processIdentifier),
            "bundlePath": Bundle.main.bundleURL.path,
            "checkedAt": Date()
        ], forKey: "accessibility.permissionSnapshot")
        return trusted
    }

    static func request() {
        DiagnosticLog.shared.write(.permissionRequested)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        refresh()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
