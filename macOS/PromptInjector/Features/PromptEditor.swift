import AppKit

final class EditorText: SurfaceView {
    let scroll = NSScrollView(), text = NSTextView()
    init(_ value: String, label: String, size: CGFloat = 14) {
        super.init(color: Theme.shell, radius: 9)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        text.isRichText = false; text.drawsBackground = false; text.textColor = Theme.text
        text.allowsUndo = true
        text.insertionPointColor = Theme.text; text.font = .systemFont(ofSize: size)
        text.textContainerInset = NSSize(width: 12, height: 10); text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.widthTracksTextView = true; text.isHorizontallyResizable = false
        text.isVerticallyResizable = true; text.autoresizingMask = [.width]
        text.string = value; text.setAccessibilityLabel(label); text.focusRingType = .none
        text.minSize = .zero; text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let p = NSMutableParagraphStyle(); p.minimumLineHeight = size >= 15 ? 28 : 24; p.maximumLineHeight = p.minimumLineHeight
        text.defaultParagraphStyle = p
        text.typingAttributes = [.font: NSFont.systemFont(ofSize: size), .foregroundColor: Theme.text, .paragraphStyle: p]
        text.textStorage?.setAttributedString(NSAttributedString(string: value, attributes: text.typingAttributes))
        scroll.documentView = text; addSubview(scroll)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout(); scroll.frame = bounds.insetBy(dx: 1, dy: 1)
        text.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(scroll.contentSize.height, text.frame.height)))
    }
}

@MainActor final class PromptEditorView: FlippedView, NSTextFieldDelegate, NSTextViewDelegate {
    var onChange: (() -> Void)?
    private(set) var original: PromptEntry?
    let id: String
    private var category: String
    let info = SurfaceView(), content = SurfaceView(border: Theme.hex(0x626262))
    private let infoScroll = NSScrollView(), infoBody = FlippedView()
    private let infoHeading = Theme.label("条目信息", size: 16, weight: .medium)
    private let labels = ["标题 *", "分类", "简述", "来源"].map { Theme.label($0, size: 12, color: Theme.secondary) }
    let titleField = NSTextField(), sourceField = NSTextField()
    private let titleBox = SurfaceView(color: Theme.shell, radius: 9), sourceBox = SurfaceView(color: Theme.shell, radius: 9)
    let categoryButton = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    private let categoryBox = SurfaceView(color: Theme.shell, radius: 9)
    private var dot: CategoryDot?
    private let categoryArrow = NSImageView()
    let summaryText: EditorText, promptText: EditorText, originalText: EditorText, explanationText: EditorText
    let segments = ChoiceSegments(["Prompt", "原始经验与解释"])
    private let contentRule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    private let promptLabel = Theme.label("Prompt *", size: 14, weight: .medium)
    private let originalLabel = Theme.label("原始经验", size: 14, weight: .medium)
    private let explanationLabel = Theme.label("解释", size: 14, weight: .medium)
    private let explanationRule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    init(draft: EditorDraft) {
        id = draft.entry.id; category = draft.entry.categoryID; original = draft.original
        summaryText = EditorText(draft.entry.summary, label: "简述", size: 13)
        promptText = EditorText(draft.entry.prompt, label: "完整 Prompt", size: 15)
        originalText = EditorText(draft.entry.originalExperience, label: "原始经验", size: 15)
        explanationText = EditorText(draft.entry.explanation, label: "解释", size: 15)
        super.init(frame: .zero)
        addSubview(info); addSubview(content); info.addSubview(infoScroll)
        infoScroll.drawsBackground = false; infoScroll.hasVerticalScroller = true; infoScroll.scrollerStyle = .overlay; infoScroll.documentView = infoBody
        [infoHeading, titleBox, categoryBox, summaryText, sourceBox].forEach(infoBody.addSubview)
        labels.forEach(infoBody.addSubview)
        for (field, box, label, value) in [(titleField, titleBox, "标题", draft.entry.title), (sourceField, sourceBox, "来源", draft.entry.source)] {
            field.font = .systemFont(ofSize: 14); field.textColor = Theme.text; field.drawsBackground = false
            field.isBordered = false; field.focusRingType = .none; field.delegate = self
            field.stringValue = value; field.setAccessibilityLabel(label); box.addSubview(field)
        }
        categoryBox.addSubview(categoryButton); categoryButton.alignment = .left
        categoryArrow.image = DesignAssets.image("Down"); categoryBox.addSubview(categoryArrow)
        categoryButton.font = .systemFont(ofSize: 14); categoryButton.onPress = { [weak self] in self?.chooseCategory() }
        [segments, contentRule, promptLabel, promptText, originalLabel, originalText, explanationLabel, explanationText, explanationRule].forEach(content.addSubview)
        for edit in [summaryText, promptText, originalText, explanationText] { edit.text.delegate = self }
        // The long content editors use the surrounding panel as their surface.
        for edit in [promptText, originalText, explanationText] { edit.layer?.borderWidth = 0; edit.layer?.backgroundColor = NSColor.clear.cgColor }
        segments.onSelect = { [weak self] _ in self?.needsLayout = true }
        updateCategory()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var value: PromptEntry { .init(id: id, categoryID: category, title: titleField.stringValue, summary: summaryText.text.string, originalExperience: originalText.text.string, source: sourceField.stringValue, explanation: explanationText.text.string, prompt: promptText.text.string) }
    var hasChanges: Bool {
        if let original { return value != original }
        let value = value
        return [value.title, value.summary, value.originalExperience, value.source, value.explanation, value.prompt].contains { !$0.isEmpty }
    }
    func markSaved(_ entry: PromptEntry) { original = entry }
    func setEditingEnabled(_ enabled: Bool) {
        titleField.isEditable = enabled; sourceField.isEditable = enabled; categoryButton.isEnabled = enabled
        [summaryText, promptText, originalText, explanationText].forEach { $0.text.isEditable = enabled }
    }
    func controlTextDidChange(_ obj: Notification) { onChange?() }
    func textDidChange(_ notification: Notification) { onChange?() }
    private func updateCategory() {
        categoryButton.title = Theme.categoryName(category)
        dot?.removeFromSuperview(); let next = CategoryDot(category: category); categoryBox.addSubview(next); dot = next
        needsLayout = true
    }
    private func chooseCategory() {
        let menu = NSMenu()
        for value in PromptCategory.all {
            let item = NSMenuItem(title: value.name, action: #selector(selectedCategory(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = value.id; item.state = value.id == category ? .on : .off; menu.addItem(item)
        }
        menu.popUp(positioning: menu.items.first { $0.representedObject as? String == category }, at: NSPoint(x: 12, y: 40), in: categoryBox)
    }
    @objc private func selectedCategory(_ sender: NSMenuItem) { guard let id = sender.representedObject as? String else { return }; category = id; updateCategory(); onChange?() }
    override func layout() {
        super.layout(); let iw: CGFloat = bounds.width >= 1100 ? 380 : 320, cw = bounds.width - iw - 20, h = bounds.height
        info.frame = NSRect(x: 0, y: 0, width: iw, height: h); content.frame = NSRect(x: iw + 20, y: 0, width: cw, height: h)
        infoScroll.frame = info.bounds.insetBy(dx: 1, dy: 1); infoBody.frame = NSRect(x: 0, y: 0, width: iw - 2, height: max(h - 2, 512))
        infoHeading.frame = NSRect(x: 24, y: 24, width: iw - 48, height: 24)
        for (label, y) in zip(labels, [CGFloat(74), 162, 250, 386]) { label.frame = NSRect(x: 24, y: y, width: iw - 48, height: 18) }
        titleBox.frame = NSRect(x: 24, y: 98, width: iw - 48, height: 44)
        Theme.placeLine(titleField, in: NSRect(x: 12, y: 0, width: iw - 72, height: 44), stableBaseline: true)
        categoryBox.frame = NSRect(x: 24, y: 186, width: iw - 48, height: 44)
        dot?.frame = NSRect(x: 12, y: 18.5, width: 7, height: 7); categoryButton.frame = NSRect(x: 27, y: 5, width: iw - 88, height: 34)
        categoryArrow.frame = NSRect(x: iw - 76, y: 14, width: 16, height: 16)
        summaryText.frame = NSRect(x: 24, y: 274, width: iw - 48, height: 84)
        sourceBox.frame = NSRect(x: 24, y: 410, width: iw - 48, height: 44)
        Theme.placeLine(sourceField, in: NSRect(x: 12, y: 0, width: iw - 72, height: 44), stableBaseline: true)
        segments.frame = NSRect(x: 24, y: 24, width: 296, height: 44); contentRule.frame = NSRect(x: 24, y: 84, width: cw - 48, height: 1)
        promptLabel.frame = NSRect(x: 24, y: 104, width: cw - 48, height: 24)
        promptText.frame = NSRect(x: 12, y: 136, width: cw - 24, height: max(120, h - 160))
        originalLabel.frame = promptLabel.frame
        let oh = max(120, min(180, (h - 228) * 0.4))
        originalText.frame = NSRect(x: 12, y: 136, width: cw - 24, height: oh)
        explanationRule.frame = NSRect(x: 24, y: originalText.frame.maxY + 12, width: cw - 48, height: 1)
        explanationLabel.frame = NSRect(x: 24, y: explanationRule.frame.maxY + 16, width: cw - 48, height: 24)
        explanationText.frame = NSRect(x: 12, y: explanationLabel.frame.maxY + 8, width: cw - 24, height: max(80, h - explanationLabel.frame.maxY - 32))
        let prompt = segments.selectedIndex == 0
        [promptLabel, promptText].forEach { $0.isHidden = !prompt }
        [originalLabel, originalText, explanationRule, explanationLabel, explanationText].forEach { $0.isHidden = prompt }
    }
}
