import AppKit

@MainActor final class GeneratedPromptEditor: FlippedView, NSTextViewDelegate, NSTextFieldDelegate {
    var onChange: (() -> Void)?
    private let scroll = NSScrollView(), body = FlippedView()
    private let empty = Theme.label("尚无整理候选", size: 14, color: Theme.secondary)
    private let labels = ["标题", "简述", "解释", "Prompt", "分类"].map { Theme.label($0, size: 12, color: Theme.secondary) }
    let fields = [EditorText("", label: "候选标题"), EditorText("", label: "候选简述"), EditorText("", label: "候选解释"), EditorText("", label: "候选 Prompt")]
    let categoryMenu = NSPopUpButton(frame: .zero, pullsDown: false), newCategoryField = NSTextField()
    private let candidateUndo = UndoManager()
    private var present = false
    init() {
        super.init(frame: .zero)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        scroll.documentView = body; addSubview(scroll); addSubview(empty)
        labels.forEach(body.addSubview)
        fields.forEach { body.addSubview($0); $0.text.delegate = self }
        body.addSubview(categoryMenu); body.addSubview(newCategoryField)
        categoryMenu.target = self; categoryMenu.action = #selector(categoryChanged)
        categoryMenu.setAccessibilityLabel("候选分类")
        newCategoryField.placeholderString = "新分类名称"; newCategoryField.setAccessibilityLabel("候选新分类名称")
        newCategoryField.delegate = self
        newCategoryField.font = .systemFont(ofSize: 14)
        set(nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var value: GeneratedPrompt? {
        guard present else { return nil }
        let id = categoryMenu.selectedItem?.representedObject as? String
        return GeneratedPrompt(title: fields[0].text.string, summary: fields[1].text.string, explanation: fields[2].text.string, prompt: fields[3].text.string, categoryID: id, newCategoryName: id == nil ? newCategoryField.stringValue : nil)
    }
    func set(_ candidate: GeneratedPrompt?) {
        present = candidate != nil
        for (field, text) in zip(fields, [candidate?.title, candidate?.summary, candidate?.explanation, candidate?.prompt]) {
            field.text.string = text ?? ""
        }
        candidateUndo.removeAllActions()
        newCategoryField.stringValue = candidate?.newCategoryName ?? ""
        selectCategory(candidate?.categoryID)
        scroll.isHidden = !present; empty.isHidden = present; needsLayout = true
    }
    func setCategories(_ values: [PromptCategory]) {
        let selected = value?.categoryID
        categoryMenu.removeAllItems()
        for category in values {
            categoryMenu.addItem(withTitle: category.name); categoryMenu.lastItem?.representedObject = category.id
        }
        categoryMenu.addItem(withTitle: "新增分类…")
        selectCategory(selected)
    }
    private func selectCategory(_ id: String?) {
        let index = categoryMenu.itemArray.firstIndex { ($0.representedObject as? String) == id }
        if let index { categoryMenu.selectItem(at: index) }
        newCategoryField.isHidden = categoryMenu.selectedItem?.representedObject is String
        needsLayout = true
    }
    func setEditingEnabled(_ enabled: Bool) {
        fields.forEach { $0.text.isEditable = enabled }
        categoryMenu.isEnabled = enabled; newCategoryField.isEditable = enabled
    }
    func undoManager(for view: NSTextView) -> UndoManager? { candidateUndo }
    func textDidChange(_ notification: Notification) { onChange?() }
    func controlTextDidChange(_ obj: Notification) { onChange?() }
    @objc private func categoryChanged() {
        newCategoryField.isHidden = categoryMenu.selectedItem?.representedObject is String
        needsLayout = true; onChange?()
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
        }
        labels[4].frame = NSRect(x: 12, y: y, width: w, height: 18)
        categoryMenu.frame = NSRect(x: 12, y: y + 24, width: w, height: 32)
        newCategoryField.frame = NSRect(x: 12, y: y + 68, width: w, height: 28)
        body.frame.size.height = y + (newCategoryField.isHidden ? 72 : 116)
    }
}
