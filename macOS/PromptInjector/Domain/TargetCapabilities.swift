import Foundation

struct TargetCapabilities {
    let role: String?
    let isSecure: Bool
    let textReadable: Bool
    let selectionReadable: Bool
    let selectionWritable: Bool
    let valueWritable: Bool

    var isEnabled: Bool? = nil
    var isEditable: Bool? = nil
    var method: InsertionMethod = .accessibility

    static func isNonTextControl(_ role: String?) -> Bool {
        ["AXButton", "AXCheckBox", "AXRadioButton", "AXSlider", "AXPopUpButton", "AXMenuItem"].contains(role ?? "")
    }

    static func hasEmptyComposerMarker(rootClasses: [String]?, descendantClasses: [[String]]) -> Bool {
        rootClasses?.contains("ProseMirror") == true && descendantClasses.contains { $0.contains("placeholder") }
    }

    var supportsInsertion: Bool {
        guard !Self.isNonTextControl(role) else { return false }
        let editable = ["AXTextArea", "AXTextField", "AXComboBox"].contains(role ?? "") || selectionWritable || valueWritable
        // AX setter availability describes direct AX writes, not standard paste support.
        // Only the explicitly selected Codex paste route admits a focused custom group.
        let pasteCandidate = method == .paste && role == "AXGroup"
        return !isSecure && isEnabled != false && isEditable != false
            && (editable || pasteCandidate) && textReadable && selectionReadable
    }
}

enum InsertionMethod: String {
    case paste, accessibility
    static func forApplication(_ bundleID: String?) -> Self {
        bundleID == "com.openai.codex" ? .paste : .accessibility
    }
}
