import AppKit

/// One quiet container, separated by rules rather than a stack of individual cards.
final class DetailDocument: NSView {
    override var isFlipped: Bool { true }
    let heading = NSTextView()
    let box = NSView()
    let promptTextView = NSTextView()
    private var sections: [(NSTextField, NSTextView)] = []
    private var rules: [PassiveView] = []
    private var arranging = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure(heading)
        addSubview(heading)
        box.wantsLayer = true
        box.layer?.cornerRadius = 10
        box.layer?.backgroundColor = NSColor(white: 1, alpha: 0.028).cgColor
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor(white: 1, alpha: 0.09).cgColor
        addSubview(box)
        for name in ["原始经验", "来源", "解释", "Prompt"] {
            let label = Theme.label(name, size: 12, weight: .medium, color: Theme.secondary)
            let text = name == "Prompt" ? promptTextView : NSTextView()
            configure(text)
            text.setAccessibilityLabel(name)
            addSubview(label); addSubview(text)
            sections.append((label, text))
        }
        for _ in 0..<3 {
            let rule = PassiveView(); rule.wantsLayer = true
            rule.layer?.backgroundColor = NSColor(white: 1, alpha: 0.09).cgColor
            addSubview(rule); rules.append(rule)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func configure(_ text: NSTextView) {
        text.isEditable = false; text.isSelectable = true; text.drawsBackground = false
        text.textContainerInset = .zero
        text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.widthTracksTextView = true
        text.isHorizontallyResizable = false
        text.isVerticallyResizable = false
        text.focusRingType = .none
    }
    func setEntry(_ entry: PromptEntry) {
        heading.textStorage?.setAttributedString(body(entry.title, size: 20, weight: .semibold))
        for (index, text) in [entry.originalExperience, entry.source, entry.explanation, entry.prompt].enumerated() {
            sections[index].1.textStorage?.setAttributedString(body(text, size: index == 1 ? 13 : 14, color: index == 1 ? Theme.secondary : Theme.text, fencedCode: index == 3))
            sections[index].0.isHidden = text.isEmpty
            sections[index].1.isHidden = text.isEmpty
        }
        arrange(width: frame.width)
    }
    private func body(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Theme.text, fencedCode: Bool = false) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        var code = false
        for line in text.components(separatedBy: "\n") {
            if fencedCode && line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { code.toggle(); continue }
            let p = NSMutableParagraphStyle(); p.lineSpacing = code ? 3 : 5; p.lineBreakMode = .byCharWrapping
            var attributes: [NSAttributedString.Key: Any] = [.font: code ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p]
            if code { attributes[.backgroundColor] = NSColor(white: 1, alpha: 0.06) }
            output.append(NSAttributedString(string: line + "\n", attributes: attributes))
        }
        if output.length > 0 { output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1)) }
        return output
    }
    @discardableResult private func position(_ text: NSTextView, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        text.frame = NSRect(x: x, y: y, width: width, height: 20)
        text.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        if let container = text.textContainer { text.layoutManager?.ensureLayout(for: container) }
        let height = ceil(text.layoutManager?.usedRect(for: text.textContainer!).height ?? 20) + 2
        text.frame.size.height = height
        return height
    }
    func arrange(width: CGFloat) {
        guard !arranging, width > 0 else { return }
        arranging = true
        defer { arranging = false }
        let titleHeight = position(heading, x: 0, y: 0, width: width)
        let boxY = titleHeight + 20
        var y = boxY + 16
        var ruleIndex = 0
        let visible = sections.filter { !$0.0.isHidden }
        for (index, section) in visible.enumerated() {
            section.0.frame = NSRect(x: 16, y: y, width: width - 32, height: 18)
            y += 26
            y += position(section.1, x: 16, y: y, width: width - 32)
            y += 16
            if index < visible.count - 1 {
                rules[ruleIndex].isHidden = false
                rules[ruleIndex].frame = NSRect(x: 16, y: y, width: width - 32, height: 1)
                ruleIndex += 1; y += 17
            }
        }
        rules.dropFirst(ruleIndex).forEach { $0.isHidden = true }
        box.frame = NSRect(x: 0, y: boxY, width: width, height: y - boxY)
        setFrameSize(NSSize(width: width, height: y + 12))
    }
}
