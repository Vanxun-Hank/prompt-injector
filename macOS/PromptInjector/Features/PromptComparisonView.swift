import AppKit

@MainActor final class PromptComparisonView: FlippedView {
    let current: EditorText, proposed: EditorText
    init(current: String, proposed: String) {
        self.current = EditorText(current, label: "当前版本", size: 14)
        self.proposed = EditorText(proposed, label: "AI 新建议", size: 14)
        super.init(frame: NSRect(x: 0, y: 0, width: 720, height: 300))
        for (i, pair) in [("当前版本", self.current), ("AI 新建议", self.proposed)].enumerated() {
            let label = Theme.label(pair.0, size: 13, weight: .medium)
            label.frame = NSRect(x: CGFloat(i) * 368, y: 0, width: 352, height: 24); addSubview(label)
            pair.1.frame = NSRect(x: CGFloat(i) * 368, y: 32, width: 352, height: 268)
            pair.1.text.isEditable = false; addSubview(pair.1)
        }
        for (field, from, to) in [(self.current, proposed, current), (self.proposed, current, proposed)] {
            let changed = Self.changedRange(current: from, proposed: to)
            if changed.length > 0 {
                field.text.textStorage?.addAttributes([.backgroundColor: Theme.selection, .foregroundColor: Theme.text], range: changed)
                field.text.scrollRangeToVisible(changed)
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    static func changedRange(current: String, proposed: String) -> NSRange {
        let a = Array(current), b = Array(proposed)
        var start = 0, suffix = 0
        while start < min(a.count, b.count), a[start] == b[start] { start += 1 }
        while suffix < min(a.count - start, b.count - start), a[a.count - suffix - 1] == b[b.count - suffix - 1] { suffix += 1 }
        return NSRange(location: String(b.prefix(start)).utf16.count, length: String(b[start..<(b.count - suffix)]).utf16.count)
    }
}
