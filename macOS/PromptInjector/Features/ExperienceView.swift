import AppKit

enum SourceBadge {
    static func set(_ button: ActionButton, source: String, original: Bool = false) {
        let platform = SourceLink.platform(source)
        var name = platform.name
        if platform.name == "X", let url = SourceLink.inSource(source) {
            let path = url.pathComponents.filter { $0 != "/" }
            if path.count >= 3, path[1] == "status", path[0] != "i" { name = path[0] }
        }
        button.title = name + (original ? " · 作者原文" : "")
        button.image = platform.asset.flatMap { DesignAssets.image($0) } ?? NSImage(systemSymbolName: "link", accessibilityDescription: "来源")
        button.image?.size = NSSize(width: 16, height: 16)
        button.imagePosition = .imageLeading; button.imageScaling = .scaleProportionallyDown
        button.toolTip = source; button.setAccessibilityLabel(original ? "查看当前经验的作者原文" : "打开原文来源")
    }
}

final class ExperienceCheckbox: NSButton {
    override var isFlipped: Bool { true }
    var checked = false { didSet { needsDisplay = true; setAccessibilityValue(checked ? 1 : 0) } }
    var onPress: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame); isBordered = false; title = ""; target = self; action = #selector(press)
        setAccessibilityRole(.checkBox); setAccessibilityLabel("勾选经验")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func press() { onPress?() }
    override func draw(_ dirtyRect: NSRect) {
        let rect = NSRect(x: bounds.midX - 9, y: bounds.midY - 9, width: 18, height: 18)
        Theme.tertiary.setStroke(); let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4); path.lineWidth = 1; path.stroke()
        if checked { DesignAssets.image("Check")?.draw(in: rect.insetBy(dx: 2, dy: 2), from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.5, respectFlipped: true, hints: nil) }
        if window?.firstResponder === self { NSFocusRingPlacement.only.set(); path.fill() }
    }
}

final class ExperienceRowCell: NSTableCellView {
    let checkbox = ExperienceCheckbox(frame: .zero)
    let stateLabel = Theme.label(size: 11, color: Theme.secondary)
    let discuss = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    var active = false { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame); addSubview(checkbox); addSubview(discuss); addSubview(stateLabel)
        discuss.alignment = .left; discuss.font = .systemFont(ofSize: 15)
        discuss.cell?.wraps = true; discuss.cell?.lineBreakMode = .byTruncatingTail
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout(); checkbox.frame = NSRect(x: 4, y: 4, width: 44, height: 44)
        discuss.frame = NSRect(x: 48, y: 4, width: bounds.width - 60, height: 28)
        stateLabel.frame = NSRect(x: 60, y: 34, width: bounds.width - 72, height: 18)
    }
    override func draw(_ dirtyRect: NSRect) {
        if active { Theme.selection.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill() }
    }
}

@MainActor final class ExperienceView: FlippedView, NSTextViewDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let controller: ExperienceController
    let panel = SurfaceView(color: Theme.shell, radius: 16)
    let content = SurfaceView(color: Theme.shell, radius: 16)
    let heading = Theme.label("原文或链接", size: 16, weight: .medium)
    let promptHeading = Theme.label("Prompt", size: 16, weight: .medium)
    let input = EditorText("", label: "作者原文或链接", size: 15)
    private let manualPrompt = EditorText("", label: "可编辑 Prompt", size: 15)
    var prompt: EditorText { editor?.promptText ?? manualPrompt }
    let sourceField = NSTextField()
    let send = ActionButton(title: "整理", symbol: "sparkles", primary: true, target: nil, action: nil)
    let manual = ActionButton(title: "手动填写", symbol: nil, target: nil, action: nil)
    let automatic = ActionButton(title: "原文或链接", symbol: nil, target: nil, action: nil)
    private let sourceBox = SurfaceView(color: Theme.shell, radius: 9)
    private let sourceLabel = Theme.label("来源（可选）", size: 12, color: Theme.secondary)
    let inputError = Theme.label(size: 11, color: Theme.error), manualPromptError = Theme.label(size: 11, color: Theme.error)
    let generate = ActionButton(title: "生成所选", symbol: nil, target: nil, action: nil)
    let cancel = ActionButton(title: "取消", symbol: nil, target: nil, action: nil)
    let configure = ActionButton(title: "", symbol: "key", target: nil, action: nil)
    let backButton = ActionButton(title: "返回内容库", symbol: nil, target: nil, action: nil)
    let status = Theme.label(size: 12, color: Theme.secondary)
    let count = Theme.label("识别出的经验", size: 14, weight: .medium)
    let selectedCount = Theme.label(size: 12, color: Theme.secondary)
    let listScroll = NSScrollView(), table = NSTableView()
    let organize = ActionButton(title: "确认并下一条", symbol: nil, primary: true, target: nil, action: nil)
    private let completed = Theme.label(size: 20, weight: .medium)
    private(set) var editor: PromptEditorView?
    private var displayedID: String?, displayedCandidate: GeneratedPrompt?
    private(set) var completedCount = 0
    var categories: [PromptCategory] { didSet { editor?.setCategories(categories) } }
    var onConfigure: (() -> Void)?, onBack: (() -> Void)?
    init(controller: ExperienceController, categories: [PromptCategory] = []) {
        self.controller = controller; self.categories = categories; super.init(frame: .zero)
        [panel, content, status, cancel, configure, generate, organize, backButton, send].forEach(addSubview)
        [count, listScroll, selectedCount].forEach(panel.addSubview)
        [heading, input, sourceBox, sourceLabel, promptHeading, manualPrompt, manual, automatic, completed, inputError, manualPromptError].forEach(content.addSubview)
        inputError.isHidden = true; manualPromptError.isHidden = true
        sourceBox.addSubview(sourceField); automatic.outlined = true; manual.outlined = true
        input.text.delegate = self; manualPrompt.text.delegate = self
        sourceField.delegate = self
        sourceField.font = .systemFont(ofSize: 13); sourceField.textColor = Theme.secondary
        sourceField.isBordered = false; sourceField.drawsBackground = false; sourceField.setAccessibilityLabel("经验来源")
        sourceField.focusRingType = .none
        table.addTableColumn(NSTableColumn(identifier: .init("experience"))); table.headerView = nil; table.style = .plain
        table.backgroundColor = .clear; table.rowHeight = 70; table.intercellSpacing = NSSize(width: 0, height: 4)
        table.selectionHighlightStyle = .none; table.dataSource = self; table.delegate = self
        listScroll.drawsBackground = false; listScroll.hasVerticalScroller = true; listScroll.scrollerStyle = .overlay; listScroll.documentView = table
        status.maximumNumberOfLines = 2; status.lineBreakMode = .byWordWrapping
        configure.toolTip = "配置 DeepSeek API key"; configure.setAccessibilityLabel("配置 DeepSeek API key")
        send.onPress = { [weak self] in self?.submitInput() }
        manual.onPress = { [weak self] in self?.clearInputErrors(); self?.controller.beginManual() }
        automatic.onPress = { [weak self] in self?.clearInputErrors(); self?.controller.beginAutomatic() }
        cancel.onPress = { [weak controller] in controller?.cancel() }
        generate.outlined = true; backButton.outlined = true
        generate.onPress = { [weak self] in self?.stashEditor(); self?.controller.generateSelected() }
        organize.onPress = { [weak self] in self?.confirmCurrent() }
        configure.onPress = { [weak self] in self?.onConfigure?() }
        backButton.onPress = { [weak self] in self?.stashEditor(); self?.onBack?() }
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func textDidChange(_ notification: Notification) {
        clearInputErrors()
        if notification.object as? NSTextView === manualPrompt.text { controller.changePrompt(manualPrompt.text.string) }
        else { controller.changeInput(input.text.string) }
    }
    private func clearInputErrors() {
        inputError.isHidden = true; manualPromptError.isHidden = true
        input.layer?.borderColor = Theme.border.cgColor; manualPrompt.layer?.borderColor = Theme.border.cgColor
        needsLayout = true
    }
    private func submitInput() {
        if controller.busy { controller.cancel(); return }
        clearInputErrors()
        let field: EditorText?, label: NSTextField?
        if controller.session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            field = input; label = inputError; inputError.stringValue = "请先粘贴作者原文或链接。"
        } else if controller.isManualEntry && (controller.session.manualPrompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            field = manualPrompt; label = manualPromptError; manualPromptError.stringValue = "请填写 Prompt。"
        } else { field = nil; label = nil }
        if let field, let label {
            label.isHidden = false; field.layer?.borderColor = Theme.error.cgColor; window?.makeFirstResponder(field.text)
            needsLayout = true
            DiagnosticLog.shared.write(.generationFailed, fields: .init(stage: "experience-input-validation")); return
        }
        if controller.isManualEntry { controller.continueManual() } else { controller.send() }
    }
    func controlTextDidChange(_ obj: Notification) { controller.changeSource(sourceField.stringValue) }
    func numberOfRows(in tableView: NSTableView) -> Int { controller.session.items.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = controller.session.items[row], cell = ExperienceRowCell()
        cell.checkbox.checked = item.selected; cell.checkbox.isEnabled = !controller.saving
        cell.checkbox.setAccessibilityLabel("选择用于生成：" + item.title)
        cell.stateLabel.stringValue = controller.activeItemID == item.id ? "生成中" : controller.failed && controller.failedItemID == item.id ? "失败，可重试" : item.confirmed == true ? "已确认" : item.suggestion != nil ? "有新建议" : item.candidate?.prompt.isEmpty == false ? "待确认" : "未生成"
        cell.discuss.title = item.candidate?.title.isEmpty == false ? item.candidate!.title : item.title
        cell.discuss.toolTip = cell.discuss.title; cell.active = controller.session.currentID == item.id
        cell.discuss.setAccessibilityLabel("查看经验：" + item.title); cell.discuss.isEnabled = !controller.saving
        cell.checkbox.onPress = { [weak controller] in controller?.toggle(item.id) }
        cell.discuss.onPress = { [weak self] in self?.choose(item.id) }
        return cell
    }
    func choose(_ id: String) { stashEditor(); controller.choose(id) }
    func stashEditor() {
        guard let editor, let current = controller.current, editor.id == current.id else { return }
        let draft = editor.draft, e = draft.entry
        let value = GeneratedPrompt(title: e.title, summary: e.summary, explanation: e.explanation, prompt: e.prompt,
                                    categoryID: draft.newCategoryName == nil ? e.categoryID : nil, newCategoryName: draft.newCategoryName)
        // A pristine skeleton is not a generated candidate; edits explicitly create one.
        if value != current.candidate, (current.candidate != nil || displayedCandidate != nil) {
            displayedCandidate = value; controller.updateCandidate(current.id, value); controller.onChange?()
        }
    }
    func confirmCurrent() {
        guard let editor, let item = controller.current, editor.validateFields() else { return }
        stashEditor(); controller.confirm(item.id)
        guard controller.current?.confirmed == true else { return }
        if let index = controller.session.items.firstIndex(where: { $0.id == item.id }), index + 1 < controller.session.items.count {
            controller.choose(controller.session.items[index + 1].id)
        }
    }
    func showCompletion(_ count: Int) { completedCount = count; update() }
    func update() {
        let session = controller.session, current = controller.current, initial = session.items.isEmpty && completedCount == 0
        let manualMode = initial && controller.isManualEntry
        panel.isHidden = initial; content.isHidden = false
        [heading, input, sourceBox, sourceLabel, send, automatic].forEach { $0.isHidden = !initial }
        [promptHeading, manualPrompt].forEach { $0.isHidden = !manualMode }
        manual.isHidden = !initial; manual.selectedStyle = manualMode; automatic.selectedStyle = !manualMode
        completed.isHidden = completedCount == 0 || !session.items.isEmpty
        completed.stringValue = "已保存 \(completedCount) 条经验"
        if initial, input.text.string != session.input { input.text.string = session.input; input.text.undoManager?.removeAllActions() }
        if initial, manualPrompt.text.string != (session.manualPrompt ?? "") { manualPrompt.text.string = session.manualPrompt ?? "" }
        if sourceField.stringValue != session.source { sourceField.stringValue = session.source }
        heading.stringValue = manualMode ? "作者原文" : "作者原文或链接"
        send.title = controller.busy ? "取消识别" : manualMode ? "继续编辑" : "识别经验"
        if let current, displayedID != current.id || displayedCandidate != current.candidate {
            let c = current.candidate
            let entry = PromptEntry(id: current.id, categoryID: c?.categoryID ?? "", title: c?.title ?? current.title,
                                    summary: c?.summary ?? "", originalExperience: current.original, source: session.source,
                                    explanation: c?.explanation ?? "", prompt: c?.prompt ?? "")
            editor?.removeFromSuperview()
            let next = PromptEditorView(draft: EditorDraft(entry: entry, original: nil, newCategoryName: c?.newCategoryName), categories: categories, workbenchMode: true)
            editor = next; addSubview(next); displayedID = current.id; displayedCandidate = c
            next.onChange = { [weak self, weak next] in
                guard let self, let next, self.editor === next else { return }
                if self.displayedCandidate == nil {
                    let d = next.draft, e = d.entry
                    self.displayedCandidate = GeneratedPrompt(title: e.title, summary: e.summary, explanation: e.explanation, prompt: e.prompt, categoryID: d.newCategoryName == nil ? e.categoryID : nil, newCategoryName: d.newCategoryName)
                }
                self.stashEditor()
            }
            next.generateButton.onPress = { [weak self] in
                guard let self else { return }; self.stashEditor()
                if self.controller.busy { self.controller.cancel() } else { self.controller.generateCurrent() }
            }
        }
        if current == nil { editor?.removeFromSuperview(); editor = nil; displayedID = nil; displayedCandidate = nil }
        editor?.setEditingEnabled(!controller.saving)
        editor?.generateButton.isEnabled = !controller.saving && (!controller.busy || controller.activeItemID == current?.id)
        editor?.generateButton.title = controller.activeItemID == current?.id && controller.busy ? "取消生成" : current?.candidate?.prompt.isEmpty == false ? "重新生成" : "DeepSeek 生成"
        count.stringValue = "识别出的经验"
        selectedCount.stringValue = "已勾选 \(session.selected.count) / \(session.items.count)"
        status.stringValue = controller.status; status.textColor = controller.failed ? Theme.error : Theme.secondary
        status.toolTip = controller.status
        table.reloadData()
        [send, generate, manual, automatic, configure].forEach { $0.isEnabled = !controller.busy && !controller.saving }
        send.isEnabled = !controller.saving
        generate.isEnabled = generate.isEnabled && !session.selected.isEmpty
        organize.isEnabled = current != nil && !controller.busy && !controller.saving && current?.confirmed != true
        organize.title = current?.confirmed == true ? "已确认" : session.items.last?.id == current?.id ? "确认此条" : "确认并下一条"
        [generate, organize].forEach { $0.isHidden = session.items.isEmpty }
        backButton.isHidden = initial; cancel.isHidden = initial || !controller.busy
        input.text.isEditable = !controller.saving; manualPrompt.text.isEditable = !controller.saving
        sourceField.isEditable = !controller.busy && !controller.saving
        needsLayout = true; layoutSubtreeIfNeeded()
    }
    override func layout() {
        super.layout(); let w = bounds.width, h = bounds.height - 56
        let initial = controller.session.items.isEmpty && completedCount == 0
        let manualMode = initial && controller.isManualEntry
        let left: CGFloat = initial ? 0 : min(300, w * 0.30)
        panel.frame = NSRect(x: 0, y: 0, width: left, height: h)
        content.frame = NSRect(x: initial ? 0 : left + 20, y: 0, width: initial ? w : w - left - 20, height: h)
        let cw = content.bounds.width
        editor?.frame = content.frame; content.isHidden = editor != nil
        configure.frame = NSRect(x: w - 36, y: h + 12, width: 36, height: 36)
        cancel.frame = NSRect(x: w - 116, y: h + 12, width: 68, height: 36)
        status.frame = NSRect(x: initial ? 0 : 144, y: h + 12, width: max(80, w - 500), height: 36)
        if initial {
            let col = manualMode ? (cw - 76) / 2 : cw - 56
            automatic.frame = NSRect(x: 28, y: 24, width: 128, height: 40)
            manual.frame = NSRect(x: 164, y: 24, width: 128, height: 40)
            heading.frame = NSRect(x: 28, y: 80, width: col, height: 20)
            input.frame = NSRect(x: 28, y: 106, width: col, height: h - (manualMode ? 224 : 216) - (inputError.isHidden ? 0 : 20))
            sourceLabel.frame = NSRect(x: 28, y: h - (manualMode ? 102 : 94), width: cw - 56, height: 20)
            sourceBox.frame = NSRect(x: 28, y: h - (manualMode ? 76 : 68), width: cw - 56, height: 40)
            Theme.placeLine(sourceField, in: NSRect(x: 12, y: 0, width: cw - 80, height: 40), stableBaseline: true)
            promptHeading.frame = NSRect(x: col + 48, y: 80, width: col, height: 20)
            manualPrompt.frame = NSRect(x: col + 48, y: 106, width: col, height: h - 224 - (manualPromptError.isHidden ? 0 : 20))
            inputError.frame = NSRect(x: 28, y: input.frame.maxY + 2, width: col, height: 16)
            manualPromptError.frame = NSRect(x: col + 48, y: manualPrompt.frame.maxY + 2, width: col, height: 16)
            send.frame = NSRect(x: w - 144, y: h + 16, width: 144, height: 40)
            configure.frame = NSRect(x: w - 192, y: h + 18, width: 36, height: 36)
        } else {
            count.frame = NSRect(x: 16, y: 20, width: left - 32, height: 24)
            listScroll.frame = NSRect(x: 8, y: 58, width: left - 16, height: h - 108)
            table.tableColumns.first?.width = listScroll.contentSize.width
            selectedCount.frame = NSRect(x: 16, y: h - 36, width: left - 32, height: 20)
            backButton.frame = NSRect(x: 0, y: h + 12, width: 128, height: 40)
            generate.frame = NSRect(x: w - 312, y: h + 12, width: 128, height: 40)
            organize.frame = NSRect(x: w - 172, y: h + 12, width: 172, height: 40)
            configure.frame = NSRect(x: w - 356, y: h + 14, width: 36, height: 36)
            cancel.frame = NSRect(x: w - 436, y: h + 14, width: 72, height: 36)
            completed.frame = NSRect(x: 32, y: 48, width: cw - 64, height: 40)
        }
    }
}
