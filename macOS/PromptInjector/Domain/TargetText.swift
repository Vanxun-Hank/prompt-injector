import Foundation

enum TargetText {
    static func resolved(value: String, selection: NSRange?, bundleID: String?, role: String?, emptyComposerMarker: Bool) -> String? {
        guard bundleID == "com.openai.codex", role == "AXTextArea", emptyComposerMarker else { return value }
        guard selection == NSRange(location: 0, length: 0) else { return nil }
        return ""
    }
}
