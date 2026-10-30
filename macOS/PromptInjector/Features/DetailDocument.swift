import AppKit

/// One quiet container, separated by rules rather than a stack of individual cards.
final class DetailDocument: NSView {
    override var isFlipped: Bool { true }
    let heading = NSTextView()
    let box = NSView()
    let promptTextView = NSTextView()
    let segments = ChoiceSegments(["Prompt", "经验与来源"])
    let sourceLabel = Theme.label(size: 11, color: Theme.tertiary)
    let bodyScroll = NSScrollView()
    private let sectionHost = FlippedView()
    private var entry: PromptEntry?
    var activeTextView: NSTextView { sections.first { !$0.1.isHidden }?.1 ?? promptTextView }
    private var sections: [(NSTextField, NSTextView)] = []
    private var rules: [PassiveView] = []
    private var arranging = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure(heading)
        heading.textContainer?.maximumNumberOfLines = 2
        heading.textContainer?.lineBreakMode = .byTruncatingTail
        heading.wantsLayer = true; heading.layer?.masksToBounds = true
        addSubview(heading)
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        box.layer?.backgroundColor = Theme.panel.cgColor
        box.layer?.borderWidth = 1
        box.layer?.borderColor = Theme.border.cgColor
        addSubview(box)
        bodyScroll.drawsBackground = false; bodyScroll.hasVerticalScroller = true; bodyScroll.scrollerStyle = .overlay
        bodyScroll.automaticallyAdjustsContentInsets = false; bodyScroll.documentView = sectionHost
        box.addSubview(bodyScroll); addSubview(sourceLabel); addSubview(segments)
        segments.onSelect = { [weak self] _ in
            guard let self, let entry = self.entry else { return }
            self.setEntry(entry)
            self.bodyScroll.contentView.scroll(to: .zero)
            self.window?.makeFirstResponder(self.activeTextView)
        }
        for name in ["原始经验", "来源", "解释", "Prompt"] {
            let label = Theme.label(name, size: 12, weight: .medium, color: Theme.secondary)
            let text = name == "Prompt" ? promptTextView : NSTextView()
            configure(text)
            text.setAccessibilityLabel(name)
            sectionHost.addSubview(label); sectionHost.addSubview(text)
            sections.append((label, text))
        }
        for _ in 0..<3 {
            let rule = PassiveView(); rule.wantsLayer = true
            rule.layer?.backgroundColor = NSColor(white: 1, alpha: 0.09).cgColor
            sectionHost.addSubview(rule); rules.append(rule)
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
        if self.entry?.id != entry.id { segments.selectedIndex = 0 }
        self.entry = entry
        heading.textStorage?.setAttributedString(Theme.body(entry.title, size: 18, lineHeight: 26, weight: .medium))
        heading.toolTip = entry.title; sourceLabel.stringValue = entry.source
        for (index, text) in [entry.originalExperience, entry.source, entry.explanation, entry.prompt].enumerated() {
            sections[index].1.textStorage?.setAttributedString(body(text, size: 13, fencedCode: index == 3))
            let hidden = text.isEmpty || (segments.selectedIndex == 0 ? index != 3 : index == 3)
            sections[index].0.isHidden = hidden || index == 3
            sections[index].1.isHidden = hidden
        }
        arrange(width: frame.width)
    }
    private func body(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Theme.text, fencedCode: Bool = false) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        var code = false
        for line in text.components(separatedBy: "\n") {
            if fencedCode && line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { code.toggle(); continue }
            let p = NSMutableParagraphStyle(); p.minimumLineHeight = 22; p.maximumLineHeight = 22; p.lineBreakMode = .byCharWrapping
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
    func arrange(width: CGFloat, height: CGFloat? = nil) {
        guard !arranging, width > 0 else { return }
        arranging = true
        defer { arranging = false }
        let height = height ?? max(173, frame.height)
        let compact = width < 400, gap: CGFloat = compact ? 8 : 12
        let titleHeight = min(52, max(26, position(heading, x: 0, y: 0, width: width)))
        heading.frame.size.height = titleHeight
        sourceLabel.isHidden = compact
        sourceLabel.frame = NSRect(x: 0, y: titleHeight + gap, width: width, height: 18)
        let tabsY = compact ? titleHeight + gap : sourceLabel.frame.maxY + gap
        segments.frame = NSRect(x: 0, y: tabsY, width: min(280, width), height: 34)
        let boxY = segments.frame.maxY + gap
        box.frame = NSRect(x: 0, y: boxY, width: width, height: max(40, height - boxY))
        bodyScroll.frame = NSRect(x: 16, y: 16, width: max(40, width - 32), height: max(20, box.bounds.height - 32))
        var y: CGFloat = 0
        var ruleIndex = 0
        let visible = sections.filter { !$0.1.isHidden }
        for (index, section) in visible.enumerated() {
            let textWidth = bodyScroll.contentSize.width
            if !section.0.isHidden { section.0.frame = NSRect(x: 0, y: y, width: textWidth, height: 16); y += 24 }
            y += position(section.1, x: 0, y: y, width: textWidth)
            y += 12
            if index < visible.count - 1 {
                rules[ruleIndex].isHidden = false
                rules[ruleIndex].frame = NSRect(x: 0, y: y, width: textWidth, height: 1)
                ruleIndex += 1; y += 13
            }
        }
        rules.dropFirst(ruleIndex).forEach { $0.isHidden = true }
        sectionHost.setFrameSize(NSSize(width: bodyScroll.contentSize.width, height: y))
        setFrameSize(NSSize(width: width, height: height))
    }
}
