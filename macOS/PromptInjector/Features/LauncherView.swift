import AppKit

final class PromptRow: NSTableRowView {
    var hovered = false { didSet { needsDisplay = true } }
    override var isEmphasized: Bool { get { true } set {} }
    override func drawBackground(in dirtyRect: NSRect) {
        if hovered && !isSelected {
            NSColor(white: 1, alpha: 0.045).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 2), xRadius: 7, yRadius: 7).fill()
        }
    }
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor(white: 1, alpha: 0.09).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 2.5), xRadius: 7, yRadius: 7)
        path.fill()
        if window?.firstResponder is NSTableView {
            Theme.accent.withAlphaComponent(0.65).setStroke(); path.lineWidth = 1; path.stroke()
        }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
}

final class PromptCell: NSTableCellView {
    let icon = NSImageView()
    let title = Theme.label(size: 14, weight: .medium)
    let summary = Theme.label(size: 12, color: Theme.secondary)
    let chevron = NSImageView()
    var category = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        [icon, title, summary, chevron].forEach(addSubview)
        icon.contentTintColor = Theme.secondary
        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevron.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        chevron.contentTintColor = Theme.tertiary
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let start: CGFloat = category ? 36 : 8
        icon.frame = NSRect(x: 8, y: (bounds.height - 17) / 2, width: 17, height: 17)
        chevron.frame = NSRect(x: bounds.width - 30, y: (bounds.height - 12) / 2, width: 10, height: 12)
        title.frame = NSRect(x: start, y: category ? (bounds.height - 20) / 2 : bounds.height / 2 + 1, width: max(0, bounds.width - start - 40), height: 20)
        summary.frame = NSRect(x: start, y: bounds.height / 2 - 20, width: max(0, bounds.width - start - 32), height: 18)
        icon.isHidden = !category
        summary.isHidden = category
    }
}

final class PromptTable: NSTableView {
    var activate: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            activate?(); return
        }
        super.keyDown(with: event)
    }
}

@MainActor final class LauncherView: MaterialSurface, NSTableViewDataSource, NSTableViewDelegate {
    let library: PromptLibrary
    var navigation = NavigationState()
    var onClose: (() -> Void)?
    var onInsert: ((PromptEntry) -> Void)?
    var onPermission: (() -> Void)?
    var targetName: String? { didSet { updateHeader() } }
    private(set) var currentEntry: PromptEntry?
    let header = DragHeader()
    let breadcrumb = Theme.label("Prompt Injector", size: 13, weight: .medium)
    let table = PromptTable()
    let contentHost = NSView()
    let pageTransition = PageTransition()
    let listScroll = NSScrollView()
    let detailScroll = NSScrollView()
    let detailDocument = DetailDocument()
    var textView: NSTextView { detailDocument.promptTextView }
    let footer = NSView()
    let hint = Theme.label(size: 11, color: Theme.secondary)
    let feedback = Theme.label(size: 12)
    let separator = PassiveView()
    lazy var backButton = ActionButton(title: "", symbol: "chevron.left", target: self, action: #selector(goBack))
    lazy var closeButton = ActionButton(title: "", symbol: "xmark", target: self, action: #selector(close))
    lazy var copyButton = ActionButton(title: "", symbol: "doc.on.doc", target: self, action: #selector(copyPrompt))
    lazy var insertButton = ActionButton(title: "", symbol: "arrow.up.right", primary: true, target: self, action: #selector(insertPrompt))
    lazy var permissionButton = ActionButton(title: "开启权限", target: self, action: #selector(openPermission))
    private var visibleEntries: [PromptSummary] = []
    private var categories: [PromptCategory] = []
    private(set) var isLoading = false
    private var loadGeneration = 0
    private var loadFailed = false
    private var feedbackToken = 0
    private var hasError = false

    init(library: PromptLibrary) {
        self.library = library
        super.init(frame: NSRect(x: 0, y: 0, width: 620, height: 520))
        header.addSubview(backButton); header.addSubview(breadcrumb); header.addSubview(closeButton)
        backButton.toolTip = "返回（⇧Return / Esc）"; backButton.setAccessibilityLabel("返回上一级")
        closeButton.toolTip = "关闭浮窗"; closeButton.setAccessibilityLabel("关闭浮窗")
        insertButton.toolTip = "插入原输入框（⌘Return）"; insertButton.setAccessibilityLabel("插入 Prompt")
        copyButton.toolTip = "复制完整 Prompt"; copyButton.setAccessibilityLabel("复制 Prompt")
        let column = NSTableColumn(identifier: .init("prompt"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.focusRingType = .none
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.dataSource = self; table.delegate = self
        table.target = self; table.action = #selector(rowClicked)
        table.activate = { [weak self] in self?.openSelection() }
        table.allowsEmptySelection = false
        listScroll.drawsBackground = false
        listScroll.automaticallyAdjustsContentInsets = false
        listScroll.hasVerticalScroller = true
        listScroll.scrollerStyle = .overlay
        listScroll.documentView = table
        detailScroll.drawsBackground = false
        detailScroll.automaticallyAdjustsContentInsets = false
        detailScroll.hasVerticalScroller = true
        detailScroll.scrollerStyle = .overlay
        detailScroll.documentView = detailDocument
        [hint, feedback, copyButton, insertButton, permissionButton].forEach(footer.addSubview)
        feedback.maximumNumberOfLines = 2
        feedback.lineBreakMode = .byWordWrapping
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        contentHost.wantsLayer = true
        contentHost.layer?.masksToBounds = true
        [listScroll, detailScroll].forEach(contentHost.addSubview)
        [header, contentHost, separator, footer].forEach(addSubview)
        finishOutline()
        NotificationCenter.default.addObserver(self, selector: #selector(libraryChanged(_:)), name: PromptLibrary.didChange, object: nil)
        showPage()
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        header.frame = NSRect(x: 16, y: h - 54, width: w - 32, height: 42)
        backButton.frame = NSRect(x: 0, y: 5, width: 30, height: 30)
        closeButton.frame = NSRect(x: header.bounds.width - 30, y: 5, width: 30, height: 30)
        let titleX: CGFloat = navigation.page == .categories ? 8 : 38
        breadcrumb.frame = NSRect(x: titleX, y: 12, width: max(60, header.bounds.width - titleX - 46), height: 20)
        let bottom: CGFloat = hasError ? 112 : 76
        let content = NSRect(x: 16, y: bottom, width: w - 32, height: max(100, h - bottom - 62))
        if contentHost.bounds.size != content.size { pageTransition.cancel() }
        contentHost.frame = content
        listScroll.frame = contentHost.bounds
        detailScroll.frame = NSRect(x: 8, y: 0, width: w - 48, height: content.height)
        table.setFrameSize(NSSize(width: listScroll.contentSize.width, height: table.frame.height))
        table.tableColumns.first?.width = listScroll.contentSize.width
        detailDocument.arrange(width: detailScroll.contentSize.width)
        separator.frame = NSRect(x: 24, y: bottom - 12, width: w - 48, height: 1)
        footer.frame = NSRect(x: 24, y: 12, width: w - 48, height: hasError ? 80 : 44)
        let fw = footer.bounds.width
        insertButton.frame = NSRect(x: fw - 34, y: 5, width: 34, height: 34)
        copyButton.frame = NSRect(x: fw - 76, y: 5, width: 34, height: 34)
        permissionButton.frame = NSRect(x: 0, y: 5, width: 78, height: 34)
        let available = currentEntry == nil ? fw : fw - 92
        hint.frame = NSRect(x: 0, y: 13, width: max(80, available), height: 18)
        feedback.frame = hasError ? NSRect(x: 0, y: 44, width: fw, height: 34) : NSRect(x: 0, y: 13, width: max(80, available), height: 18)
        window?.invalidateCursorRects(for: self)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        navigation.page == .categories ? categories.count : visibleEntries.count
    }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { navigation.page == .categories ? 44 : 64 }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < numberOfRows(in: tableView) else { return nil }
        let cell = PromptCell()
        if navigation.page == .categories {
            let category = categories[row]
            cell.category = true
            cell.title.stringValue = category.name
            cell.icon.image = NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil)
            cell.icon.symbolConfiguration = .init(pointSize: 15, weight: .regular)
            cell.setAccessibilityLabel(category.name)
        } else {
            let entry = visibleEntries[row]
            cell.title.stringValue = entry.title
            cell.summary.stringValue = entry.summary
            cell.toolTip = entry.title + "\n" + entry.summary
            cell.setAccessibilityLabel(entry.title + "。" + entry.summary)
        }
        return cell
    }
    @objc private func rowClicked() { if table.clickedRow >= 0 { openSelection() } }
    func remember() {
        guard !isLoading else { return }
        let index = table.selectedRow
        let id = navigation.page == .categories ? (categories.indices.contains(index) ? categories[index].id : nil) : (visibleEntries.indices.contains(index) ? visibleEntries[index].id : nil)
        navigation.remember(selection: max(0, index), scrollY: currentEntry == nil ? listScroll.contentView.bounds.origin.y : detailScroll.contentView.bounds.origin.y, selectionID: id)
    }
    func navigate(to page: LauncherPage, animate: Bool = true) {
        guard page != navigation.page else { return }
        DiagnosticLog.shared.write(.pageChanged, fields: .init(fromLevel: navigation.page.level, toLevel: page.level))
        remember()
        let direction: PageTransition.Direction = page.level < navigation.page.level ? .backward : .forward
        let previous = currentEntry == nil ? listScroll : detailScroll
        pageTransition.prepare(outgoing: previous, in: contentHost, animated: animate)
        navigation.open(page)
        showPage(direction: direction, animate: animate)

    }
    func openSelection() {
        let index = table.selectedRow
        guard !isLoading, index >= 0 else { return }
        switch navigation.page {
        case .categories:
            guard categories.indices.contains(index) else { return }
            navigate(to: .entries(categories[index].id))
        case .entries(let category):
            guard visibleEntries.indices.contains(index) else { return }
            navigate(to: .detail(category, visibleEntries[index].id))
        case .detail: break
        }
    }
    @objc func goBack() {
        var destination = navigation
        if destination.back() { navigate(to: destination.page) } else { onClose?() }
    }
    @objc private func close() { onClose?() }

    private func showPage(direction: PageTransition.Direction = .forward, animate: Bool = false) {
        loadGeneration += 1
        let generation = loadGeneration
        let page = navigation.page
        isLoading = true
        loadFailed = false
        feedbackToken += 1
        hasError = false
        feedback.isHidden = true; permissionButton.isHidden = true; hint.isHidden = false
        currentEntry = nil
        visibleEntries = []
        table.isEnabled = false
        copyButton.isHidden = true; insertButton.isHidden = true
        backButton.isHidden = page == .categories
        updateHeader()
        library.load(page) { [weak self] result in
            guard let self else { return }
            guard self.loadGeneration == generation, self.navigation.page == page else {
                DiagnosticLog.shared.write(.libraryLoadDiscarded, fields: .init(toLevel: page.level))
                return
            }
            self.isLoading = false
            self.table.isEnabled = true
            switch result {
            case .success(let content):
                switch content {
                case .categories(let values): self.categories = values
                case .entries(let values): self.visibleEntries = values
                case .detail(let value): self.currentEntry = value
                }
                self.renderPage()
            case .failure(let error):
                self.loadFailed = true
                if page == .categories { self.categories = [] }
                self.renderPage()
                self.showFeedback((error as? LocalizedError)?.errorDescription ?? "无法读取资料库，请重试。", error: true, persist: true)
            }
            self.pageTransition.play(incoming: self.currentEntry == nil ? self.listScroll : self.detailScroll, direction: direction, animated: animate)
        }
    }
    func retryFailedLoad() { if loadFailed && !isLoading { showPage() } }
    @objc private func libraryChanged(_ notification: Notification) {
        guard let library = notification.object as? PromptLibrary, library === self.library,
              let category = notification.userInfo?["categoryID"] as? String else { return }
        refresh(category: category)
    }
    private func refresh(category: String) {
        switch navigation.page {
        case .categories: return // Fixed categories have no counts or body data to refresh.
        case .entries(let id), .detail(let id, _): guard id == category else { return }
        }
        remember()
        pageTransition.cancel()
        DiagnosticLog.shared.write(.libraryRefreshed, fields: .init(toLevel: navigation.page.level))
        showPage()
    }
    private func renderPage() {
        let detail = currentEntry != nil
        detailScroll.isHidden = !detail; listScroll.isHidden = detail
        insertButton.isHidden = !detail; copyButton.isHidden = !detail
        backButton.isHidden = navigation.page == .categories
        hint.stringValue = detail ? "⇧↵ 返回   ⌘↵ 插入" : navigation.page == .categories ? "↑↓ 选择   ↵ 打开" : "↑↓ 选择   ↵ 打开   ⇧↵ 返回"
        updateHeader()
        if let entry = currentEntry {
            detailDocument.setEntry(entry)
        } else {
            table.reloadData()
            let count = numberOfRows(in: table)
            let ids = navigation.page == .categories ? categories.map(\.id) : visibleEntries.map(\.id)
            let selected = navigation.restored.selectionID.flatMap { ids.firstIndex(of: $0) } ?? min(navigation.restored.selection, count - 1)
            if count > 0 { table.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false) }
            if count == 0 { showFeedback("暂无条目", error: false, persist: true) }
        }
        needsLayout = true; layoutSubtreeIfNeeded()
        let scroll = detail ? detailScroll : listScroll
        scroll.contentView.scroll(to: NSPoint(x: 0, y: navigation.restored.scrollY))
        scroll.reflectScrolledClipView(scroll.contentView)
        window?.makeFirstResponder(detail ? textView : table)
    }
    private func updateHeader() {
        switch navigation.page {
        case .categories: breadcrumb.stringValue = "Prompt Injector"
        case .entries(let id), .detail(let id, _): breadcrumb.stringValue = categories.first { $0.id == id }?.name ?? "Prompt"
        }
        insertButton.toolTip = targetName.map { "插入到\($0)（⌘Return）" } ?? "插入原输入框（⌘Return）"
    }
    @objc func copyPrompt() {
        guard let entry = currentEntry else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(entry.prompt, forType: .string) {
            DiagnosticLog.shared.write(.copySucceeded, fields: .init(promptUTF16Count: (entry.prompt as NSString).length))
            showFeedback("已复制", error: false)
        } else {
            DiagnosticLog.shared.write(.copyFailed, level: .error)
            showFeedback("复制失败，请重试。", error: true)
        }
    }
    @objc func insertPrompt() { if let entry = currentEntry { onInsert?(entry) } }
    @objc private func openPermission() { onPermission?() }
    func showFeedback(_ message: String, error: Bool, permission: Bool = false, persist: Bool = false) {
        feedbackToken += 1; let token = feedbackToken
        hasError = error
        feedback.stringValue = message; feedback.toolTip = message
        feedback.textColor = error ? Theme.error : Theme.secondary
        feedback.isHidden = false; hint.isHidden = true; permissionButton.isHidden = !permission
        needsLayout = true
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        guard !persist else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (error ? 8 : 2)) { [weak self] in
            guard let self, self.feedbackToken == token else { return }
            self.feedback.isHidden = true; self.permissionButton.isHidden = true; self.hint.isHidden = false; self.hasError = false; self.needsLayout = true
        }
    }
}
