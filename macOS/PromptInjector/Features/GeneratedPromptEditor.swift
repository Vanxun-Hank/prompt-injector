import AppKit

@MainActor final class GeneratedPromptEditor: FlippedView, NSTextViewDelegate, NSTextFieldDelegate {
    var onChange: (() -> Void)?
    private let scroll = NSScrollView(), body = FlippedView()
    private let empty = Theme.label("尚无整理候选", size: 14, color: Theme.secondary)
    private let labels = ["标题", "简述", "解释", "Prompt", "分类"].map { Theme.label($0, size: 12, color: Theme.secondary) }
    let fields = [EditorText("", label: "候选标题"), EditorText("", label: "候选简述"), EditorText("", label: "候选解释"), EditorText("", label: "候选 Prompt")]
    let categoryMenu = ActionButton(title: "选择分类", symbol: "chevron.down", target: nil, action: nil)
    private var categories: [PromptCategory] = []
    private var categoryID: String?, newCategoryName: String?
    private var categoryChooser: CategoryPopover?
    private let candidateUndo = UndoManager()
    let validationLabel = Theme.label(size: 12, color: Theme.error)
    private var invalidField: Int?
    private var present = false
    init() {
        super.init(frame: .zero)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        scroll.documentView = body; addSubview(scroll); addSubview(empty)
        labels.forEach(body.addSubview)
        body.addSubview(validationLabel); validationLabel.isHidden = true
        fields.forEach { body.addSubview($0); $0.text.delegate = self }
        body.addSubview(categoryMenu)
        categoryMenu.target = self; categoryMenu.action = #selector(categoryChanged)
        categoryMenu.outlined = true; categoryMenu.alignment = .left
        categoryMenu.setAccessibilityLabel("候选分类")
        set(nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var value: GeneratedPrompt? {
        guard present else { return nil }
        return GeneratedPrompt(title: fields[0].text.string, summary: fields[1].text.string, explanation: fields[2].text.string, prompt: fields[3].text.string, categoryID: categoryID, newCategoryName: newCategoryName)
    }
    func set(_ candidate: GeneratedPrompt?) {
        clearValidation()
        present = candidate != nil
        for (field, text) in zip(fields, [candidate?.title, candidate?.summary, candidate?.explanation, candidate?.prompt]) {
            field.text.string = text ?? ""
        }
        candidateUndo.removeAllActions()
        categoryID = candidate?.categoryID; newCategoryName = candidate?.newCategoryName
        updateCategoryLabel()
        scroll.isHidden = !present; empty.isHidden = present; needsLayout = true
    }
    func setCategories(_ values: [PromptCategory]) {
        categories = values; updateCategoryLabel()
    }
    private func updateCategoryLabel() {
        categoryMenu.title = newCategoryName.map { $0 + "（新）" } ?? categories.first { $0.id == categoryID }?.name ?? "选择分类"
    }
    func setEditingEnabled(_ enabled: Bool) {
        fields.forEach { $0.text.isEditable = enabled }
        categoryMenu.isEnabled = enabled
    }
    func undoManager(for view: NSTextView) -> UndoManager? { candidateUndo }
    func textDidChange(_ notification: Notification) { clearValidation(); onChange?() }
    func controlTextDidChange(_ obj: Notification) { onChange?() }
    @objc private func categoryChanged() {
        let chooser = CategoryPopover(categories: categories, selected: categoryID ?? "") { [weak self] id, name in
            self?.categoryID = id; self?.newCategoryName = name
            self?.updateCategoryLabel(); self?.onChange?()
        }
        categoryChooser = chooser; chooser.show(relativeTo: categoryMenu)
        if let name = newCategoryName { chooser.showCreate(name: name) }
    }
    private func clearValidation() { invalidField = nil; validationLabel.isHidden = true; needsLayout = true }
    func validateFields() -> Bool {
        clearValidation()
        for (index, field) in fields.enumerated() where field.text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            invalidField = index; validationLabel.stringValue = "请填写\(labels[index].stringValue)。"; validationLabel.isHidden = false
            layoutSubtreeIfNeeded(); field.scrollToVisible(field.bounds); window?.makeFirstResponder(field.text)
            return false
        }
        return true
    }
    override func layout() {
        super.layout(); scroll.frame = bounds; empty.frame = bounds.insetBy(dx: 12, dy: 12)
        let w = max(40, scroll.contentSize.width - 24)
        body.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 880)
        var y: CGFloat = 12
        for (index, height) in [CGFloat(60), 84, 140, 240].enumerated() {
            labels[index].frame = NSRect(x: 12, y: y, width: w, height: 18)
            fields[index].frame = NSRect(x: 12, y: y + 24, width: w, height: height)
            y += height + 44
            if invalidField == index {
                validationLabel.frame = NSRect(x: 12, y: y - 16, width: w, height: 18); y += 22
            }
        }
        labels[4].frame = NSRect(x: 12, y: y, width: w, height: 18)
        categoryMenu.frame = NSRect(x: 12, y: y + 24, width: w, height: 32)
        body.frame.size.height = y + 72
    }
}
