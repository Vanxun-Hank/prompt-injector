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

final class DiscussionBubble: FlippedView {
    let document = TextDocument()
    let divider = SurfaceView(color: Theme.hex(0x3C3C3C), radius: 0, border: nil)
    let message: DiscussionMessage
    init(_ message: DiscussionMessage) {
        self.message = message; super.init(frame: .zero); addSubview(document); addSubview(divider)
        wantsLayer = true; layer?.cornerRadius = 12
        layer?.backgroundColor = message.role == .user ? Theme.band.cgColor : NSColor.clear.cgColor
        document.set(Theme.body(message.content, size: message.role == .user ? 15 : 16, lineHeight: 28), width: 400)
        divider.isHidden = message.role != .assistant
        setAccessibilityLabel(message.role == .user ? "用户消息" : "DeepSeek 回复")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func arrange(width: CGFloat) {
        let user = message.role == .user, pad: CGFloat = user ? 16 : 0
        document.arrange(width: width - pad * 2); document.frame.origin = NSPoint(x: pad, y: user ? 12 : 0)
        let height = document.frame.maxY + (user ? 12 : 24)
        frame.size = NSSize(width: width, height: height + (user ? 0 : 1))
        divider.frame = NSRect(x: 0, y: height, width: width, height: 1)
    }
}

@MainActor final class ExperienceView: FlippedView, NSTextViewDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let controller: ExperienceController
    let heading = Theme.label(size: 16, weight: .medium)
    let chatScroll = NSScrollView(), chatBody = FlippedView()
    let input = EditorText("", label: "聊天输入", size: 15)
    let sourceField = NSTextField()
    let empty = Theme.label("粘贴原文或链接，开始理解经验。", size: 16, color: Theme.secondary)
    let placeholder = Theme.label("粘贴原文或链接…", size: 15, color: Theme.tertiary)
    let model = Theme.label("DeepSeek", size: 12, color: Theme.tertiary)
    let send = ActionButton(title: "", symbol: "arrow.up", primary: true, target: nil, action: nil)
    let cancel = ActionButton(title: "取消", symbol: nil, target: nil, action: nil)
    let configure = ActionButton(title: "", symbol: "key", target: nil, action: nil)
    let status = Theme.label(size: 12, color: Theme.secondary)
    let panel = SurfaceView(color: Theme.shell, radius: 16, border: nil)
    let count = Theme.label(size: 17, weight: .medium), selectedCount = Theme.label(size: 13, color: Theme.secondary)
    let source = ActionButton(title: "来源 · 作者原文", symbol: nil, target: nil, action: nil)
    private let rule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    let listScroll = NSScrollView(), table = NSTableView()
    let organize = ActionButton(title: "整理已勾选", symbol: nil, primary: true, target: nil, action: nil)
    private(set) var bubbles: [DiscussionBubble] = []
    private var displayed: [DiscussionMessage] = []
    private var displayedID: String?
    private var popover: NSPopover?
    var onConfigure: (() -> Void)?
    init(controller: ExperienceController) {
        self.controller = controller; super.init(frame: .zero)
        [heading, chatScroll, input, model, send, cancel, configure, status, panel, empty, sourceField].forEach(addSubview)
        [count, source, rule, listScroll, selectedCount, organize].forEach(panel.addSubview)
        input.text.delegate = self; input.reservedBottom = 50
        input.addSubview(placeholder, positioned: .below, relativeTo: input.scroll); placeholder.setAccessibilityElement(false)
        sourceField.placeholderString = "来源或链接（可选）"; sourceField.delegate = self
        sourceField.font = .systemFont(ofSize: 13); sourceField.textColor = Theme.secondary
        sourceField.isBordered = false; sourceField.drawsBackground = false; sourceField.setAccessibilityLabel("经验来源")
        chatScroll.drawsBackground = false; chatScroll.hasVerticalScroller = true; chatScroll.scrollerStyle = .overlay; chatScroll.documentView = chatBody
        table.addTableColumn(NSTableColumn(identifier: .init("experience"))); table.headerView = nil; table.style = .plain
        table.backgroundColor = .clear; table.rowHeight = 52; table.intercellSpacing = NSSize(width: 0, height: 4)
        table.selectionHighlightStyle = .none; table.dataSource = self; table.delegate = self
        listScroll.drawsBackground = false; listScroll.hasVerticalScroller = true; listScroll.scrollerStyle = .overlay; listScroll.documentView = table
        status.maximumNumberOfLines = 2; status.lineBreakMode = .byWordWrapping
        send.toolTip = "发送"; send.setAccessibilityLabel("发送消息")
        configure.toolTip = "配置 DeepSeek API key"; configure.setAccessibilityLabel("配置 DeepSeek API key")
        send.onPress = { [weak controller] in controller?.send() }; cancel.onPress = { [weak controller] in controller?.cancel() }
        organize.onPress = { [weak controller] in controller?.organize() }
        configure.onPress = { [weak self] in self?.onConfigure?() }
        source.onPress = { [weak self] in self?.showOriginal() }
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func textDidChange(_ notification: Notification) { controller.changeInput(input.text.string); updateActions() }
    func controlTextDidChange(_ obj: Notification) { controller.changeSource(sourceField.stringValue) }
    func numberOfRows(in tableView: NSTableView) -> Int { controller.session.items.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = controller.session.items[row], cell = ExperienceRowCell()
        cell.checkbox.checked = item.selected; cell.checkbox.isEnabled = !controller.saving
        cell.checkbox.setAccessibilityLabel("勾选经验：" + item.title)
        cell.discuss.title = "\(row + 1). " + item.title; cell.discuss.toolTip = item.title; cell.active = controller.session.currentID == item.id
        cell.discuss.isEnabled = !controller.saving
        cell.checkbox.onPress = { [weak controller] in controller?.toggle(item.id) }
        cell.discuss.onPress = { [weak controller] in controller?.choose(item.id) }
        return cell
    }
    func update() {
        let session = controller.session, current = controller.current
        let switched = displayedID != current?.id
        heading.stringValue = current?.title ?? ""
        empty.isHidden = !session.items.isEmpty
        if switched || displayed != (current?.messages ?? []) {
            bubbles.forEach { $0.removeFromSuperview() }
            displayed = current?.messages ?? []; displayedID = current?.id
            bubbles = displayed.map(DiscussionBubble.init); bubbles.forEach(chatBody.addSubview)
        }
        let value = current?.input ?? session.input
        if input.text.string != value { input.text.string = value; input.text.undoManager?.removeAllActions() }
        if sourceField.stringValue != session.source { sourceField.stringValue = session.source }
        sourceField.isHidden = !session.items.isEmpty
        count.stringValue = session.items.isEmpty ? "识别出的经验" : "识别出 \(session.items.count) 条经验"
        selectedCount.stringValue = "已勾选 \(session.selected.count) / \(session.items.count)"
        source.isHidden = current == nil; SourceBadge.set(source, source: session.source, original: true)
        status.stringValue = controller.status; status.textColor = controller.failed ? Theme.error : Theme.secondary; status.toolTip = controller.status
        table.reloadData(); updateActions(); needsLayout = true; layoutSubtreeIfNeeded()
        if switched { chatScroll.contentView.scroll(to: .zero) }
    }
    private func updateActions() {
        placeholder.stringValue = controller.session.items.isEmpty ? "粘贴原文或链接…" : "继续问，或说说你的理解…"
        placeholder.isHidden = !input.text.string.isEmpty
        send.isEnabled = !controller.busy && !controller.saving && (!input.text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.canRetry)
        send.image = NSImage(systemSymbolName: controller.canRetry && input.text.string.isEmpty ? "arrow.clockwise" : "arrow.up", accessibilityDescription: "发送或重试")
        send.setAccessibilityLabel(controller.canRetry && input.text.string.isEmpty ? "重试当前问题" : "发送消息")
        cancel.isHidden = !controller.busy; configure.isEnabled = !controller.busy && !controller.saving
        organize.isEnabled = !controller.busy && !controller.saving && !controller.session.selected.isEmpty
        input.text.isEditable = !controller.saving; sourceField.isEditable = !controller.busy && !controller.saving
    }
    func showOriginal() {
        guard let item = controller.current else { return }
        let vc = NSViewController(); let body = FlippedView(frame: NSRect(x: 0, y: 0, width: 540, height: 380)); vc.view = body
        let scroll = NSScrollView(frame: NSRect(x: 24, y: 24, width: 492, height: 280)), text = TextDocument()
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.documentView = text
        text.set(Theme.body("作者原文\n\n" + item.original, size: 16, lineHeight: 30), width: 476); body.addSubview(scroll)
        let link = ActionButton(title: "查看完整来源", symbol: "arrow.up.right", target: nil, action: nil)
        link.frame = NSRect(x: 24, y: 320, width: 180, height: 36); link.isEnabled = SourceLink.inSource(controller.session.source) != nil
        link.onPress = { [weak self] in if let url = self.flatMap({ SourceLink.inSource($0.controller.session.source) }) { NSWorkspace.shared.open(url) } }
        body.addSubview(link)
        let popover = NSPopover(); popover.behavior = .transient; popover.contentViewController = vc; popover.contentSize = body.frame.size
        self.popover = popover; popover.show(relativeTo: source.bounds, of: source, preferredEdge: .minY)
    }
    override func layout() {
        super.layout(); let col = (bounds.width - 24) / 2, h = bounds.height
        heading.frame = NSRect(x: 0, y: 0, width: col, height: 28)
        let initial = controller.session.items.isEmpty
        sourceField.frame = NSRect(x: 0, y: h - 176, width: col, height: 28)
        chatScroll.frame = NSRect(x: 0, y: 48, width: col, height: max(80, h - (status.stringValue.isEmpty ? 208 : 244)))
        input.frame = NSRect(x: 0, y: h - 128, width: col, height: 128)
        placeholder.frame = NSRect(x: 12, y: 10, width: col - 24, height: 28)
        model.frame = NSRect(x: 20, y: h - 40, width: 86, height: 20)
        configure.frame = NSRect(x: 100, y: h - 50, width: 36, height: 36)
        send.frame = NSRect(x: col - 56, y: h - 52, width: 36, height: 36)
        cancel.frame = NSRect(x: col - 136, y: h - 52, width: 68, height: 36)
        status.frame = NSRect(x: 0, y: h - (initial ? 222 : 176), width: col, height: 36)
        empty.frame = NSRect(x: 0, y: 80, width: col, height: 28)
        var y: CGFloat = 0
        for bubble in bubbles {
            let user = bubble.message.role == .user, width = max(40, chatScroll.contentSize.width - (user ? 32 : 0))
            bubble.arrange(width: width); bubble.frame.origin = NSPoint(x: user ? 32 : 0, y: y); y += bubble.frame.height + 24
        }
        chatBody.frame = NSRect(x: 0, y: 0, width: chatScroll.contentSize.width, height: max(chatScroll.contentSize.height, y))
        panel.frame = NSRect(x: col + 24, y: 0, width: col, height: h)
        count.frame = NSRect(x: 24, y: 20, width: col - 48, height: 28)
        source.frame = NSRect(x: 16, y: 60, width: col - 32, height: 28); source.alignment = .left; source.font = .systemFont(ofSize: 13)
        rule.frame = NSRect(x: 24, y: 104, width: col - 48, height: 1)
        listScroll.frame = NSRect(x: 12, y: 120, width: col - 24, height: h - 220); table.tableColumns.first?.width = listScroll.contentSize.width
        selectedCount.frame = NSRect(x: 24, y: h - 60, width: col - 190, height: 24)
        organize.frame = NSRect(x: col - 148, y: h - 68, width: 124, height: 36)
    }
}
