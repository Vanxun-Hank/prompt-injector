import AppKit

enum SourceBadge {
    static func set(_ button: ActionButton, source: String, original: Bool = false) {
        let platform = SourceLink.platform(source)
        var name = platform.name
        if platform.name == "X", let url = SourceLink.inSource(source) {
            let path = url.pathComponents.filter { $0 != "/" }
            if path.count >= 3, path[1] == "status", path[0] != "i" { name += " · " + path[0] }
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
    let discuss = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    var active = false { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame); addSubview(checkbox); addSubview(discuss)
        discuss.alignment = .left; discuss.font = .systemFont(ofSize: 15)
        discuss.cell?.wraps = true; discuss.cell?.lineBreakMode = .byTruncatingTail
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout(); checkbox.frame = NSRect(x: 4, y: 4, width: 44, height: 44)
        discuss.frame = NSRect(x: 48, y: 4, width: bounds.width - 60, height: 44)
    }
    override func draw(_ dirtyRect: NSRect) {
        if active { Theme.selection.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill() }
    }
}

@MainActor final class ExperienceView: FlippedView, NSTextViewDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let controller: ExperienceController
    let panel = SurfaceView(color: Theme.shell, radius: 16)
    let content = SurfaceView(color: Theme.shell, radius: 16)
    let heading = Theme.label("作者原文", size: 16, weight: .medium)
    let promptHeading = Theme.label("Prompt", size: 16, weight: .medium)
    let input = EditorText("", label: "作者原文或链接", size: 15)
    let prompt = EditorText("", label: "可编辑 Prompt", size: 15)
    let sourceField = NSTextField()
    let source = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    let send = ActionButton(title: "整理", symbol: "sparkles", primary: true, target: nil, action: nil)
    let manual = ActionButton(title: "手动填写", symbol: nil, target: nil, action: nil)
    let generate = ActionButton(title: "DeepSeek 生成", symbol: "sparkles", target: nil, action: nil)
    let cancel = ActionButton(title: "取消", symbol: nil, target: nil, action: nil)
    let configure = ActionButton(title: "", symbol: "key", target: nil, action: nil)
    let status = Theme.label(size: 12, color: Theme.secondary)
    let count = Theme.label(size: 17, weight: .medium)
    let selectedCount = Theme.label(size: 13, color: Theme.secondary)
    let listScroll = NSScrollView(), table = NSTableView()
    let organize = ActionButton(title: "审核已勾选", symbol: nil, primary: true, target: nil, action: nil)
    private let originalScroll = NSScrollView(), original = TextDocument()
    private let rule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    private var displayedID: String?
    var onConfigure: (() -> Void)?
    init(controller: ExperienceController) {
        self.controller = controller; super.init(frame: .zero)
        [panel, content, status, cancel, configure].forEach(addSubview)
        [count, listScroll, selectedCount, organize].forEach(panel.addSubview)
        [heading, input, sourceField, source, originalScroll, promptHeading, prompt, generate, send, manual, rule].forEach(content.addSubview)
        input.text.delegate = self; prompt.text.delegate = self
        prompt.layer?.borderColor = Theme.hex(0x626262).cgColor
        sourceField.placeholderAttributedString = NSAttributedString(string: "来源或链接（可选）", attributes: [.foregroundColor: Theme.tertiary]); sourceField.delegate = self
        sourceField.font = .systemFont(ofSize: 13); sourceField.textColor = Theme.secondary
        sourceField.isBordered = false; sourceField.drawsBackground = false; sourceField.setAccessibilityLabel("经验来源")
        sourceField.focusRingType = .none
        originalScroll.drawsBackground = false; originalScroll.hasVerticalScroller = true
        originalScroll.scrollerStyle = .overlay; originalScroll.documentView = original
        table.addTableColumn(NSTableColumn(identifier: .init("experience"))); table.headerView = nil; table.style = .plain
        table.backgroundColor = .clear; table.rowHeight = 52; table.intercellSpacing = NSSize(width: 0, height: 4)
        table.selectionHighlightStyle = .none; table.dataSource = self; table.delegate = self
        listScroll.drawsBackground = false; listScroll.hasVerticalScroller = true; listScroll.scrollerStyle = .overlay; listScroll.documentView = table
        status.maximumNumberOfLines = 2; status.lineBreakMode = .byWordWrapping
        configure.toolTip = "配置 DeepSeek API key"; configure.setAccessibilityLabel("配置 DeepSeek API key")
        send.onPress = { [weak controller] in
            guard let controller else { return }
            if controller.session.manualPrompt != nil { controller.continueManual() } else { controller.send() }
        }
        manual.onPress = { [weak controller] in controller?.beginManual() }
        cancel.onPress = { [weak controller] in controller?.cancel() }
        generate.onPress = { [weak controller] in controller?.generateCurrent() }
        organize.onPress = { [weak controller] in controller?.organize() }
        configure.onPress = { [weak self] in self?.onConfigure?() }
        source.onPress = { [weak controller] in
            if let url = controller.flatMap({ SourceLink.inSource($0.session.source) }) { NSWorkspace.shared.open(url) }
        }
        source.alignment = .left; source.font = .systemFont(ofSize: 13)
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func textDidChange(_ notification: Notification) {
        if notification.object as? NSTextView === prompt.text { controller.changePrompt(prompt.text.string) }
        else { controller.changeInput(input.text.string) }
    }
    func controlTextDidChange(_ obj: Notification) { controller.changeSource(sourceField.stringValue) }
    func numberOfRows(in tableView: NSTableView) -> Int { controller.session.items.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = controller.session.items[row], cell = ExperienceRowCell()
        cell.checkbox.checked = item.selected; cell.checkbox.isEnabled = !controller.saving
        cell.checkbox.setAccessibilityLabel("勾选经验：" + item.title)
        cell.discuss.title = "\(row + 1). " + item.title; cell.discuss.toolTip = item.title; cell.active = controller.session.currentID == item.id
        cell.discuss.setAccessibilityLabel("查看经验：" + item.title); cell.discuss.isEnabled = !controller.saving
        cell.checkbox.onPress = { [weak controller] in controller?.toggle(item.id) }
        cell.discuss.onPress = { [weak controller] in controller?.choose(item.id) }
        return cell
    }
    func update() {
        let session = controller.session, current = controller.current, initial = session.items.isEmpty
        let manualMode = initial && session.manualPrompt != nil
        panel.isHidden = initial; heading.stringValue = initial && !manualMode ? "原文或链接" : "作者原文"
        if initial, input.text.string != session.input { input.text.string = session.input; input.text.undoManager?.removeAllActions() }
        let value = current?.candidate?.prompt ?? session.manualPrompt ?? ""
        if prompt.text.string != value { prompt.text.string = value; prompt.text.undoManager?.removeAllActions() }
        if sourceField.stringValue != session.source { sourceField.stringValue = session.source }
        if displayedID != current?.id {
            original.set(Theme.body(current?.original ?? "", size: 16, lineHeight: 32), width: max(100, content.bounds.width - 48))
            originalScroll.contentView.scroll(to: .zero)
            prompt.scroll.contentView.scroll(to: .zero)
            if displayedID != nil { PageTransition.fade(content, duration: 0.12) }
            displayedID = current?.id
        }
        input.isHidden = !initial; sourceField.isHidden = !initial
        originalScroll.isHidden = initial; source.isHidden = initial || session.source.isEmpty
        SourceBadge.set(source, source: session.source)
        source.isEnabled = SourceLink.inSource(session.source) != nil
        [promptHeading, prompt].forEach { $0.isHidden = initial && !manualMode }
        generate.isHidden = initial; send.isHidden = !initial; manual.isHidden = !initial || manualMode
        rule.isHidden = initial
        send.title = manualMode ? "继续审核" : "整理"
        count.stringValue = "识别出 \(session.items.count) 条经验"
        selectedCount.stringValue = "已勾选 \(session.selected.count) / \(session.items.count)"
        status.stringValue = controller.status; status.textColor = controller.failed ? Theme.error : Theme.secondary
        status.toolTip = controller.status
        table.reloadData()
        [send, generate, organize, manual, configure].forEach { $0.isEnabled = !controller.busy && !controller.saving }
        cancel.isHidden = !controller.busy
        input.text.isEditable = !controller.saving; prompt.text.isEditable = !controller.saving
        sourceField.isEditable = !controller.busy && !controller.saving
        needsLayout = true; layoutSubtreeIfNeeded()
    }
    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height - 52, initial = controller.session.items.isEmpty
        let manualMode = initial && controller.session.manualPrompt != nil
        let left: CGFloat = initial ? 0 : min(352, w * 0.34)
        panel.frame = NSRect(x: 0, y: 0, width: left, height: h)
        content.frame = NSRect(x: initial ? 0 : left + 20, y: 0, width: initial ? w : w - left - 20, height: h)
        let cw = content.bounds.width
        heading.frame = NSRect(x: 24, y: 24, width: cw - 48, height: 28)
        configure.frame = NSRect(x: w - 36, y: h + 12, width: 36, height: 36)
        cancel.frame = NSRect(x: w - 116, y: h + 12, width: 68, height: 36)
        status.frame = NSRect(x: 0, y: h + 12, width: max(100, w - 140), height: 36)
        if initial {
            let col = manualMode ? (cw - 72) / 2 : cw - 48
            input.frame = NSRect(x: 24, y: 68, width: col, height: h - 192)
            sourceField.frame = NSRect(x: 36, y: h - 112, width: col - 24, height: 28)
            promptHeading.frame = NSRect(x: col + 48, y: 24, width: col, height: 28)
            prompt.frame = NSRect(x: col + 48, y: 68, width: col, height: h - 148)
            manual.frame = NSRect(x: 24, y: h - 60, width: 100, height: 36)
            send.frame = NSRect(x: cw - 148, y: h - 60, width: 124, height: 36)
        } else {
            let oh = max(100, min(228, (h - 180) * 0.4))
            source.frame = NSRect(x: cw - 224, y: 20, width: 200, height: 36)
            heading.frame.size.width = max(100, cw - 260)
            originalScroll.frame = NSRect(x: 24, y: 68, width: cw - 48, height: oh)
            original.arrange(width: originalScroll.contentSize.width)
            rule.frame = NSRect(x: 24, y: originalScroll.frame.maxY + 16, width: cw - 48, height: 1)
            promptHeading.frame = NSRect(x: 24, y: rule.frame.maxY + 20, width: 120, height: 28)
            generate.frame = NSRect(x: cw - 172, y: rule.frame.maxY + 16, width: 148, height: 36)
            prompt.frame = NSRect(x: 24, y: promptHeading.frame.maxY + 16, width: cw - 48, height: h - promptHeading.frame.maxY - 40)
            count.frame = NSRect(x: 24, y: 24, width: left - 48, height: 28)
            listScroll.frame = NSRect(x: 12, y: 68, width: left - 24, height: h - 160)
            table.tableColumns.first?.width = listScroll.contentSize.width
            selectedCount.frame = NSRect(x: 24, y: h - 68, width: left - 48, height: 20)
            organize.frame = NSRect(x: 24, y: h - 40, width: left - 48, height: 32)
        }
    }
}
