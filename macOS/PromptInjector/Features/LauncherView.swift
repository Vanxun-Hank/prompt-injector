import AppKit

final class PromptRow: NSTableRowView {
    var hovered = false { didSet { needsDisplay = true } }
    override var isEmphasized: Bool { get { true } set {} }
    override func drawBackground(in dirtyRect: NSRect) {
        if hovered && !isSelected {
            Theme.band.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
        }
    }
    override func drawSelection(in dirtyRect: NSRect) {
        Theme.selection.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        path.fill()
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
    let title = Theme.label(size: 14, weight: .medium)
    let summary = Theme.label(size: 12, color: Theme.secondary)
    let chevron = NSImageView()
    let count = Theme.label(size: 11, color: Theme.tertiary)
    var category = false
    var compact = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        [title, summary, count, chevron].forEach(addSubview)
        chevron.image = DesignAssets.image("Chevron")
        chevron.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        chevron.contentTintColor = Theme.tertiary
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let start: CGFloat = 12
        chevron.frame = NSRect(x: bounds.width - 22, y: (bounds.height - 10) / 2, width: 6, height: 10)
        count.frame = NSRect(x: bounds.width - 56, y: (bounds.height - 18) / 2, width: 22, height: 18)
        count.isHidden = !category; count.alignment = .right
        Theme.placeLine(count, in: NSRect(x: bounds.width - 56, y: 0, width: 22, height: bounds.height))
        summary.maximumNumberOfLines = compact ? 2 : 1
        summary.lineBreakMode = compact ? .byWordWrapping : .byTruncatingTail
        summary.cell?.wraps = compact
        summary.isHidden = category || summary.stringValue.isEmpty
        let textWidth = max(0, bounds.width - start - 36)
        let titleHeight = ceil(title.cell?.cellSize.height ?? 17)
        let summaryHeight = summary.isHidden ? 0 : min(compact ? 36 : 18, ceil(summary.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: textWidth, height: 36)).height ?? 18))
        let gap: CGFloat = summary.isHidden ? 0 : 4
        let bottom = (bounds.height - titleHeight - gap - summaryHeight) / 2
        Theme.placeLine(title, in: NSRect(x: start, y: category ? 0 : bottom + summaryHeight + gap, width: max(0, bounds.width - start - 64), height: category ? bounds.height : titleHeight))
        Theme.placeLine(summary, in: NSRect(x: start, y: bottom, width: textWidth, height: summaryHeight))
    }
}

final class LauncherListHeader: NSView {
    override var isFlipped: Bool { true }
    var left = "分类"
    var right = ""
    override func draw(_ dirtyRect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Theme.tertiary]
        (left as NSString).draw(at: NSPoint(x: 0, y: 0), withAttributes: attrs)
        let size = (right as NSString).size(withAttributes: attrs)
        (right as NSString).draw(at: NSPoint(x: bounds.width - size.width - 20, y: 0), withAttributes: attrs)
    }
    override func mouseDown(with event: NSEvent) {}
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
    private(set) var insertionFailure: InjectionService.Failure?
    let header = DragHeader()
    let breadcrumb = Theme.label("Prompt Injector", size: 13, weight: .medium)
    let logo = LogoView(frame: .zero)
    let intro = LauncherListHeader(frame: NSRect(x: 0, y: 0, width: 570, height: 32))
    let table = PromptTable()
    let contentHost = NSView()
    let pageTransition = PageTransition()
    let listScroll = NSScrollView()
    let detailScroll = NSScrollView()
    let detailDocument = DetailDocument()
    var textView: NSTextView { detailDocument.activeTextView }
    let footer = NSView()
    let hint = Theme.label(size: 11, color: Theme.secondary)
    let dismissHint = Theme.label("esc 隐藏", size: 11, color: Theme.secondary)
    let feedback = Theme.label(size: 12)
    let separator = PassiveView()
    lazy var backButton = ActionButton(title: "", symbol: "chevron.left", target: self, action: #selector(goBack))
    lazy var closeButton = ActionButton(title: "", symbol: "xmark", target: self, action: #selector(close))
    lazy var copyButton = ActionButton(title: "", symbol: "doc.on.doc", target: self, action: #selector(copyPrompt))
    lazy var insertButton = ActionButton(title: "", symbol: "arrow.up.right", target: self, action: #selector(insertPrompt))
    lazy var permissionButton = ActionButton(title: "开启权限", target: self, action: #selector(openPermission))
    private var visibleEntries: [PromptSummary] = []
    private var categories: [PromptCategory] = []
    private(set) var isLoading = false
    private var loadGeneration = 0
    private var loadFailed = false
    private var feedbackToken = 0
    private var hasError = false
    private var selectionToRestore: String?
    private var compactRows = false

    init(library: PromptLibrary) {
        self.library = library
        super.init(frame: NSRect(x: 0, y: 0, width: 620, height: 520))
        header.addSubview(backButton); header.addSubview(logo); header.addSubview(breadcrumb); header.addSubview(closeButton)
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
        table.intercellSpacing = NSSize(width: 0, height: 8)
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
        detailScroll.hasVerticalScroller = false
        detailScroll.scrollerStyle = .overlay
        detailScroll.documentView = detailDocument
        [hint, dismissHint, feedback, copyButton, insertButton, permissionButton].forEach(footer.addSubview)
        dismissHint.alignment = .right
        copyButton.outlined = true; insertButton.outlined = true
        feedback.maximumNumberOfLines = 2
        feedback.lineBreakMode = .byWordWrapping
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        contentHost.wantsLayer = true
        contentHost.layer?.masksToBounds = true
        [listScroll, detailScroll, intro].forEach(contentHost.addSubview)
        [header, contentHost, separator, footer].forEach(addSubview)
        finishOutline()
        NotificationCenter.default.addObserver(self, selector: #selector(libraryChanged(_:)), name: .promptLibraryChanged, object: library)
        showPage()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        if compactRows != (w < 450) {
            compactRows = w < 450
            table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<numberOfRows(in: table)))
        }
        let compact = w < 450, edge: CGFloat = compact ? 16 : 24
        let hh: CGFloat = compact ? 52 : 56, fh: CGFloat = hasError ? 104 : compact ? 56 : 60
        header.frame = NSRect(x: 1, y: h - hh - 1, width: w - 2, height: hh)
        backButton.frame = NSRect(x: edge, y: (hh - 32) / 2, width: 32, height: 32)
        logo.frame = NSRect(x: edge, y: (hh - 24) / 2, width: 24, height: 24)
        closeButton.frame = NSRect(x: header.bounds.width - (compact ? 12 : 16) - 32, y: (hh - 32) / 2, width: 32, height: 32)
        let titleX = edge + (navigation.page == .categories ? 34 : 42)
        Theme.placeLine(breadcrumb, in: NSRect(x: titleX, y: 0, width: max(60, header.bounds.width - titleX - 48), height: hh))
        let gap: CGFloat = compact ? 8 : 12
        let content = NSRect(x: edge + 1, y: fh + 2 + gap, width: w - 2 * edge - 2, height: max(80, h - hh - fh - 3 - 2 * gap))
        if contentHost.bounds.size != content.size { pageTransition.cancel() }
        contentHost.frame = content
        intro.frame = NSRect(x: 0, y: contentHost.bounds.height - 32, width: contentHost.bounds.width, height: 32)
        listScroll.frame = NSRect(x: 0, y: 0, width: contentHost.bounds.width, height: max(40, contentHost.bounds.height - 32))
        detailScroll.frame = contentHost.bounds
        table.setFrameSize(NSSize(width: listScroll.contentSize.width, height: table.frame.height))
        table.tableColumns.first?.width = listScroll.contentSize.width
        detailDocument.arrange(width: detailScroll.contentSize.width, height: detailScroll.contentSize.height)
        separator.frame = NSRect(x: 1, y: fh + 1, width: w - 2, height: 1)
        footer.frame = NSRect(x: edge + 1, y: 1, width: w - 2 * edge - 2, height: fh)
        let fw = footer.bounds.width
        insertButton.frame = NSRect(x: fw - 40, y: 10, width: 40, height: 40)
        copyButton.frame = NSRect(x: fw - 90, y: 10, width: 40, height: 40)
        permissionButton.frame = NSRect(x: 0, y: 5, width: 78, height: 34)
        let available = currentEntry == nil ? fw : fw - 92
        hint.frame = NSRect(x: 0, y: (min(60, fh) - 18) / 2, width: max(80, available), height: 18)
        dismissHint.frame = NSRect(x: fw - 72, y: hint.frame.minY, width: 72, height: 18)
        dismissHint.isHidden = navigation.page != .categories || hasError
        feedback.frame = hasError ? NSRect(x: 0, y: 60, width: fw, height: 36) : hint.frame
        window?.invalidateCursorRects(for: self)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        navigation.page == .categories ? categories.count : visibleEntries.count
    }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { navigation.page == .categories ? 44 : bounds.width < 450 ? 80 : 64 }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < numberOfRows(in: tableView) else { return nil }
        let cell = PromptCell()
        cell.compact = bounds.width < 450
        if navigation.page == .categories {
            let category = categories[row]
            cell.category = true
            cell.title.stringValue = category.name
            cell.count.stringValue = String(category.entryCount)
            Theme.glow(cell.title, color: Theme.categoryColor(category.id))
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
        navigation.remember(selection: max(0, table.selectedRow), scrollY: currentEntry == nil ? listScroll.contentView.bounds.origin.y : detailDocument.bodyScroll.contentView.bounds.origin.y)
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
            guard let self, self.loadGeneration == generation, self.navigation.page == page else { return }
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
    private func renderPage() {
        let detail = currentEntry != nil
        intro.isHidden = detail
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
            if count > 0 {
                let restored = selectionToRestore.flatMap { id in visibleEntries.firstIndex { $0.id == id } } ?? min(navigation.restored.selection, count - 1)
                table.selectRowIndexes(IndexSet(integer: restored), byExtendingSelection: false)
            }
            selectionToRestore = nil
            if count == 0 { showFeedback("暂无条目", error: false, persist: true) }
        }
        needsLayout = true; layoutSubtreeIfNeeded()
        let scroll = detail ? detailDocument.bodyScroll : listScroll
        scroll.contentView.scroll(to: NSPoint(x: 0, y: navigation.restored.scrollY))
        scroll.reflectScrolledClipView(scroll.contentView)
        window?.makeFirstResponder(detail ? textView : table)
    }
    private func updateHeader() {
        switch navigation.page {
        case .categories:
            breadcrumb.font = .systemFont(ofSize: 15, weight: .semibold)
            breadcrumb.attributedStringValue = NSAttributedString(string: "Prompt Injector", attributes: [.font: breadcrumb.font!, .foregroundColor: Theme.text])
            breadcrumb.layer?.shadowOpacity = 0
            intro.left = "分类"; intro.right = "\(categories.reduce(0) { $0 + $1.entryCount }) 条内容"
        case .entries(let id), .detail(let id, _):
            breadcrumb.stringValue = Theme.categoryName(id); breadcrumb.font = .systemFont(ofSize: 14, weight: .medium)
            Theme.glow(breadcrumb, color: Theme.categoryColor(id))
            intro.left = "\(visibleEntries.count) 条内容"; intro.right = ""
        }
        logo.isHidden = navigation.page != .categories
        intro.needsDisplay = true
        insertButton.toolTip = targetName.map { "插入到\($0)（⌘Return）" } ?? "插入原输入框（⌘Return）"
    }
    @objc func copyPrompt() {
        guard let entry = currentEntry else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(entry.prompt, forType: .string) {
            DiagnosticLog.shared.write(.copySucceeded, fields: .init(promptUTF16Count: (entry.prompt as NSString).length))
            library.recordUsage(entry, kind: .copy) { [weak self] result in
                if case .failure = result { self?.showFeedback("复制成功，但使用记录未保存。", error: true) }
            }
            showFeedback("已复制", error: false)
        } else {
            DiagnosticLog.shared.write(.copyFailed, level: .error)
            showFeedback("复制失败，请重试。", error: true)
        }
    }
    func setInsertionFailure(_ failure: InjectionService.Failure?) {
        if failure == nil, insertionFailure != nil {
            feedbackToken += 1
            feedback.isHidden = true; permissionButton.isHidden = true; hint.isHidden = false
            hasError = false; needsLayout = true
        }
        insertionFailure = failure; insertButton.isEnabled = failure == nil
    }
    @objc func insertPrompt() {
        guard insertionFailure == nil else {
            DiagnosticLog.shared.write(.insertionBlocked, level: .warning, fields: .init(stage: "ui", errorCode: insertionFailure?.rawValue))
            return
        }
        if let entry = currentEntry { onInsert?(entry) }
    }
    @objc private func libraryChanged(_ notification: Notification) {
        selectionToRestore = visibleEntries.indices.contains(table.selectedRow) ? visibleEntries[table.selectedRow].id : nil
        remember()
        if case .detail(_, let id) = navigation.page, id == notification.userInfo?["id"] as? String,
           let category = notification.userInfo?["category"] as? String { navigation.open(.detail(category, id)) }
        showPage()
    }
    @objc private func openPermission() { onPermission?() }
    func showFeedback(_ message: String, error: Bool, permission: Bool = false, persist: Bool = false) {
        if permission { setInsertionFailure(.permission) }
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
