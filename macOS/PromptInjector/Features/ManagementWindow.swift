import AppKit

final class ManagementWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SidebarItem: NSButton {
    var onPress: (() -> Void)?
    let label: String
    let category: String?
    let asset: String?
    var count: Int? { didSet { needsDisplay = true } }
    var selected = false { didSet { needsDisplay = true; setAccessibilityValue(selected ? 1 : 0) } }
    override var isFlipped: Bool { true }
    init(_ label: String, category: String? = nil, asset: String? = nil) {
        self.label = label; self.category = category; self.asset = asset
        super.init(frame: .zero)
        isBordered = false; title = ""; target = self; action = #selector(press)
        setAccessibilityLabel(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func press() { onPress?() }
    override func draw(_ dirtyRect: NSRect) {
        if selected || isHighlighted {
            (selected ? Theme.selection : Theme.band).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill()
        }
        let color = category.map(Theme.categoryColor) ?? (selected ? Theme.text : Theme.secondary)
        if let category {
            DesignAssets.image("Dot-" + category, template: false)?.draw(in: NSRect(x: 2, y: bounds.midY - 13.5, width: 27, height: 27), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else if let asset, let image = DesignAssets.image(asset) {
            // SVG icons retain the Figma viewBox; tint is applied by AppKit at draw time.
            image.draw(in: NSRect(x: 12, y: bounds.midY - 9, width: 18, height: 18), from: .zero, operation: .sourceOver, fraction: selected ? 1 : 0.68, respectFlipped: true, hints: nil)
        }
        Theme.drawLine(label, font: .systemFont(ofSize: 13), color: color, in: NSRect(x: category == nil ? 38 : 29, y: 0, width: bounds.width - 58, height: bounds.height))
        if let count {
            Theme.drawLine(String(count), font: .systemFont(ofSize: 12), color: Theme.tertiary, in: NSRect(x: bounds.width - 52, y: 0, width: 40, height: bounds.height), alignment: .right)
        }
    }
}

final class SearchBox: SurfaceView {
    let field = NSTextField()
    private let icon = NSImageView()
    init() {
        super.init(color: Theme.hex(0x141414), radius: 10)
        field.isBordered = false; field.drawsBackground = false; field.focusRingType = .none
        field.font = .systemFont(ofSize: 13); field.textColor = Theme.text
        field.placeholderAttributedString = NSAttributedString(string: "搜索标题和简述", attributes: [.foregroundColor: Theme.tertiary, .font: NSFont.systemFont(ofSize: 13)])
        field.setAccessibilityLabel("搜索标题和简述")
        icon.image = DesignAssets.image("Search")
        addSubview(icon); addSubview(field)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout(); icon.frame = NSRect(x: 12, y: 11.5, width: 17, height: 17)
        Theme.placeLine(field, in: NSRect(x: 37, y: 0, width: max(60, bounds.width - 49), height: bounds.height), stableBaseline: true)
    }
}

@MainActor final class ManagementRoot: FlippedView {
    enum Page { case library, editor, statistics }
    var page: Page = .library { didSet { needsLayout = true } }
    let sidebar = SurfaceView(color: Theme.shell, radius: 0, border: nil)
    let logo = LogoView(frame: .zero)
    let brand = Theme.label("Prompt Injector", size: 15, weight: .semibold)
    let all = SidebarItem("全部内容", asset: "Grid"), stats = SidebarItem("使用统计", asset: "Chart")
    let categoryLabel = Theme.label("分类", size: 11, color: Theme.tertiary)
    let categoryItems = PromptCategory.all.map { SidebarItem($0.name, category: $0.id) }
    private let sidebarRule = SurfaceView(color: Theme.hex(0x353535), radius: 0, border: nil)
    private let lowerRule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    private let shortcut = Theme.label("⇧⌥Space", size: 11, color: Theme.tertiary)
    let title = Theme.label("内容库", size: 26, weight: .medium)
    let subtitle = Theme.label(size: 12, color: Theme.secondary)
    let band = SurfaceView(color: Theme.band, radius: 16, border: nil)
    let search = SearchBox()
    let newButton = ActionButton(title: "", symbol: "plus", primary: true, target: nil, action: nil)
    let statusLabel = Theme.label("尚未保存", size: 13)
    private let statusDot = NSImageView()
    let requiredLabel = Theme.label(size: 12, color: Theme.secondary)
    let cancelButton = ActionButton(title: "取消", symbol: nil, target: nil, action: nil)
    let saveButton = ActionButton(title: "保存条目", symbol: "checkmark", primary: true, target: nil, action: nil)
    let libraryView = ManagementLibraryView()
    var editor: PromptEditorView? { didSet { oldValue?.removeFromSuperview(); if let editor { addSubview(editor) }; needsLayout = true } }
    var dashboard: UsageDashboard? { didSet { oldValue?.removeFromSuperview(); if let dashboard { addSubview(dashboard) }; needsLayout = true } }
    let footer = Theme.label(size: 11, color: Theme.tertiary)
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; layer?.backgroundColor = Theme.canvas.cgColor; layer?.cornerRadius = 20; layer?.masksToBounds = true
        [sidebar, title, subtitle, band, libraryView, footer].forEach(addSubview)
        [logo, brand, all, stats, sidebarRule, categoryLabel, lowerRule, shortcut].forEach(sidebar.addSubview)
        categoryItems.forEach(sidebar.addSubview)
        [search, newButton, statusDot, statusLabel, requiredLabel, cancelButton, saveButton].forEach(band.addSubview)
        statusDot.image = DesignAssets.image("Status"); statusDot.contentTintColor = Theme.hex(0xF5D975)
        cancelButton.outlined = true
        newButton.toolTip = "新建条目"; newButton.setAccessibilityLabel("新建条目")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var mouseDownCanMoveWindow: Bool { true }
    override func layout() {
        super.layout(); let w = bounds.width, h = bounds.height, main = w - 280
        sidebar.frame = NSRect(x: 0, y: 0, width: 216, height: h)
        logo.frame = NSRect(x: 20, y: 40, width: 32, height: 32)
        Theme.placeLine(brand, in: NSRect(x: 62, y: 40, width: 140, height: 32))
        all.frame = NSRect(x: 20, y: 90, width: 176, height: 40); stats.frame = NSRect(x: 20, y: 140, width: 176, height: 40)
        sidebarRule.frame = NSRect(x: 20, y: 190, width: 176, height: 1); categoryLabel.frame = NSRect(x: 20, y: 201, width: 176, height: 18)
        for (i, item) in categoryItems.enumerated() { item.frame = NSRect(x: 20, y: 229 + CGFloat(i) * 54, width: 176, height: 44) }
        lowerRule.frame = NSRect(x: 20, y: h - 60, width: 176, height: 1)
        shortcut.frame = NSRect(x: 20, y: h - 43, width: 176, height: 18)
        title.frame = NSRect(x: 248, y: 32, width: main, height: 36); subtitle.frame = NSRect(x: 248, y: 70, width: main, height: 18)
        band.frame = NSRect(x: 248, y: 108, width: main, height: 64)
        search.frame = NSRect(x: 16, y: 12, width: min(360, main - 280), height: 40)
        newButton.frame = NSRect(x: main - 56, y: 12, width: 40, height: 40)
        statusDot.frame = NSRect(x: 16, y: 28.5, width: 7, height: 7)
        statusDot.contentTintColor = statusLabel.stringValue.contains("失败") ? Theme.error : Theme.hex(0xF5D975)
        Theme.placeLine(statusLabel, in: NSRect(x: 35, y: 12, width: 100, height: 40))
        Theme.placeLine(requiredLabel, in: NSRect(x: 145, y: 12, width: max(100, main - 385), height: 40))
        cancelButton.frame = NSRect(x: main - 224, y: 12, width: 76, height: 40); saveButton.frame = NSRect(x: main - 132, y: 12, width: 116, height: 40)
        libraryView.frame = NSRect(x: 248, y: 192, width: main, height: max(360, h - 264))
        editor?.frame = libraryView.frame
        dashboard?.frame = NSRect(x: 216, y: 0, width: w - 216, height: h)
        footer.frame = NSRect(x: 248, y: h - 52, width: main, height: 20)
        let editing = page == .editor, statistics = page == .statistics
        [title, subtitle, band, footer].forEach { $0.isHidden = statistics }
        [search, newButton].forEach { $0.isHidden = editing }
        [statusDot, statusLabel, requiredLabel, cancelButton, saveButton].forEach { $0.isHidden = !editing }
        libraryView.isHidden = page != .library; editor?.isHidden = !editing; dashboard?.isHidden = !statistics
    }
}

final class ManagementSummaryCell: NSTableCellView {
    override var isFlipped: Bool { true }
    let heading = Theme.label(size: 14, weight: .medium), summary = Theme.label(size: 12, color: Theme.secondary), metadata = Theme.label(size: 11, color: Theme.tertiary)
    override init(frame: NSRect) { super.init(frame: frame); [heading, summary, metadata].forEach(addSubview) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func set(_ value: ManagedSummary) {
        heading.stringValue = value.summary.title; summary.stringValue = value.summary.summary
        let name = Theme.categoryName(value.summary.categoryID)
        let text = NSMutableAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Theme.categoryColor(value.summary.categoryID)])
        metadata.attributedStringValue = text
        toolTip = value.summary.title + "\n" + value.summary.summary
    }
    override func layout() {
        super.layout(); heading.frame = NSRect(x: 12, y: 12, width: bounds.width - 24, height: 21)
        summary.frame = NSRect(x: 12, y: 35, width: bounds.width - 24, height: 18); metadata.frame = NSRect(x: 12, y: 55, width: bounds.width - 24, height: 17)
    }
}

@MainActor final class ManagementLibraryView: FlippedView, NSTableViewDataSource, NSTableViewDelegate {
    let listPanel = SurfaceView(), preview = SurfaceView()
    let listLabel = Theme.label("全部条目", size: 12, color: Theme.secondary)
    let table = NSTableView(), listScroll = NSScrollView()
    let categoryLabel = Theme.label(size: 14, weight: .medium)
    let heading = Theme.label(size: 24, weight: .medium), summary = Theme.label(size: 13, color: Theme.secondary)
    private let rule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    let document = TextDocument(), scroll = NSScrollView()
    let sources = ActionButton(title: "原文与来源", symbol: nil, target: nil, action: nil)
    let copyButton = ActionButton(title: "", symbol: "doc.on.doc", target: nil, action: nil), editButton = ActionButton(title: "", symbol: "pencil", target: nil, action: nil)
    var onSelect: ((ManagedSummary) -> Void)?
    private(set) var items: [ManagedSummary] = []
    private var settingSelection = false
    private var entry: PromptEntry?
    private var showingSources = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(listPanel); addSubview(preview); listPanel.addSubview(listLabel); listPanel.addSubview(listScroll)
        [categoryLabel, heading, summary, rule, scroll, sources, copyButton, editButton].forEach(preview.addSubview)
        table.addTableColumn(NSTableColumn(identifier: .init("entry"))); table.headerView = nil; table.style = .plain
        table.backgroundColor = .clear; table.rowHeight = 84; table.intercellSpacing = NSSize(width: 0, height: 4)
        table.focusRingType = .none; table.dataSource = self; table.delegate = self; table.allowsEmptySelection = true
        listScroll.drawsBackground = false; listScroll.hasVerticalScroller = true; listScroll.scrollerStyle = .overlay; listScroll.documentView = table
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay; scroll.documentView = document
        copyButton.outlined = true; editButton.outlined = true; sources.font = .systemFont(ofSize: 12); sources.ink = Theme.secondary
        sources.image = DesignAssets.image("Down"); sources.imagePosition = .imageTrailing; sources.alignment = .left
        copyButton.toolTip = "复制完整 Prompt"; copyButton.setAccessibilityLabel("复制完整 Prompt")
        editButton.toolTip = "编辑条目"; editButton.setAccessibilityLabel("编辑条目")
        sources.onPress = { [weak self] in
            guard let self else { return }; self.showingSources.toggle(); self.updateDocument()
            if self.showingSources { self.document.text.scrollToEndOfDocument(nil) }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setItems(_ items: [ManagedSummary], selecting id: String?) {
        settingSelection = true; self.items = items; table.reloadData()
        if !items.isEmpty {
            let index = id.flatMap { id in items.firstIndex { $0.summary.id == id } } ?? 0
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else { table.deselectAll(nil); setEntry(nil) }
        settingSelection = false
        if items.indices.contains(table.selectedRow) { onSelect?(items[table.selectedRow]) }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { let cell = ManagementSummaryCell(); cell.set(items[row]); return cell }
    func tableViewSelectionDidChange(_ notification: Notification) { if !settingSelection, items.indices.contains(table.selectedRow) { onSelect?(items[table.selectedRow]) } }
    func setEntry(_ value: PromptEntry?) {
        if entry?.id != value?.id { showingSources = false }
        entry = value; copyButton.isEnabled = value != nil; editButton.isEnabled = value != nil; sources.isEnabled = value != nil
        heading.stringValue = value?.title ?? "没有匹配内容"; summary.stringValue = value?.summary ?? ""
        categoryLabel.stringValue = value.map { Theme.categoryName($0.categoryID) } ?? ""
        categoryLabel.textColor = value.map { Theme.categoryColor($0.categoryID) } ?? Theme.text
        updateDocument(); needsLayout = true
    }
    private func updateDocument() {
        let content = NSMutableAttributedString(string: "")
        if let entry {
            content.append(Theme.body("Prompt\n", size: 14, lineHeight: 26, weight: .medium))
            content.append(Theme.body("\n" + entry.prompt, size: 15, lineHeight: 28))
            if !entry.explanation.isEmpty { content.append(Theme.body("\n\n解释\n" + entry.explanation, size: 12, color: Theme.secondary, lineHeight: 24)) }
            if showingSources { content.append(Theme.body("\n\n原始经验\n" + entry.originalExperience + "\n\n来源\n" + entry.source, size: 13, lineHeight: 24)) }
        }
        document.set(content, width: max(100, scroll.contentSize.width))
    }
    override func layout() {
        super.layout(); let listWidth: CGFloat = bounds.width >= 1100 ? 420 : max(280, bounds.width * 0.36)
        listPanel.frame = NSRect(x: 0, y: 0, width: listWidth, height: bounds.height)
        preview.frame = NSRect(x: listWidth + 20, y: 0, width: bounds.width - listWidth - 20, height: bounds.height)
        listLabel.frame = NSRect(x: 16, y: 16, width: listWidth - 32, height: 28)
        listScroll.frame = NSRect(x: 16, y: 48, width: listWidth - 32, height: bounds.height - 64)
        table.tableColumns.first?.width = listScroll.contentSize.width
        let w = preview.bounds.width, h = preview.bounds.height
        categoryLabel.frame = NSRect(x: 24, y: 24, width: w - 48, height: 24)
        heading.frame = NSRect(x: 24, y: 64, width: w - 48, height: 34); summary.frame = NSRect(x: 24, y: 112, width: w - 48, height: 22)
        rule.frame = NSRect(x: 24, y: 150, width: w - 48, height: 1)
        scroll.frame = NSRect(x: 24, y: 166, width: w - 48, height: h - 242)
        sources.frame = NSRect(x: 24, y: h - 64, width: 128, height: 40)
        copyButton.frame = NSRect(x: w - 114, y: h - 64, width: 40, height: 40); editButton.frame = NSRect(x: w - 64, y: h - 64, width: 40, height: 40)
        document.arrange(width: scroll.contentSize.width)
    }
}

@MainActor final class ManagementWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    let library: PromptLibrary
    let root = ManagementRoot(frame: .zero)
    private var selectedCategory: String?
    private(set) var selectedEntry: PromptEntry?
    private var queryGeneration = 0, detailGeneration = 0
    private var navigationGeneration = 0
    private var counts: [PromptCategory] = []
    private(set) var isSaving = false
    private var draftWork: DispatchWorkItem?
    private var afterSave: (() -> Void)?
    var needsTerminationSave: Bool { isSaving || root.editor?.hasChanges == true }
    init(library: PromptLibrary) {
        self.library = library
        let window = ManagementWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 960), styleMask: [.titled, .fullSizeContentView, .resizable, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Prompt Injector · 内容管理"; window.identifier = .init("PromptInjector.Management")
        window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = NSSize(width: 1100, height: 720); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua); window.backgroundColor = .clear; window.isOpaque = false
        window.isMovableByWindowBackground = true; window.hasShadow = true; window.contentView = root
        super.init(window: window); window.delegate = self
        let screen = NSScreen.main.flatMap { $0.visibleFrame.width >= 1472 && $0.visibleFrame.height >= 992 ? $0 : nil }
            ?? NSScreen.screens.first { $0.visibleFrame.width >= 1472 && $0.visibleFrame.height >= 992 } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            window.setContentSize(NSSize(width: min(1440, visible.width - 32), height: min(960, visible.height - 32)))
            window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2, y: visible.midY - window.frame.height / 2))
        }
        root.all.onPress = { [weak self] in self?.showLibrary(category: nil) }
        root.stats.onPress = { [weak self] in self?.showStatistics() }
        for (index, item) in root.categoryItems.enumerated() { item.onPress = { [weak self] in self?.chooseCategory(PromptCategory.all[index].id) } }
        root.newButton.onPress = { [weak self] in self?.newEntry() }
        root.cancelButton.onPress = { [weak self] in self?.leaveEditor() }
        root.saveButton.onPress = { [weak self] in self?.saveEditor() }
        root.search.field.delegate = self
        root.libraryView.onSelect = { [weak self] in self?.select($0) }
        root.libraryView.copyButton.onPress = { [weak self] in self?.copyEntry() }
        root.libraryView.editButton.onPress = { [weak self] in self?.editEntry() }
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: .promptLibraryChanged, object: library)
        reloadCounts(); showLibrary(category: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self); draftWork?.cancel() }
    func show() {
        NSApp.setActivationPolicy(.regular)
        if let icon = DesignAssets.image("AppIcon", template: false) { NSApp.applicationIconImage = icon }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        DiagnosticLog.shared.write(.managementWindowState, fields: .init(stage: "fullscreen-entered"))
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        DiagnosticLog.shared.write(.managementWindowState, fields: .init(stage: "fullscreen-exited"))
    }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        DiagnosticLog.shared.write(.managementWindowState, level: .error, fields: .init(stage: "fullscreen-enter-failed"))
        root.footer.stringValue = "无法进入全屏，请重试。"
    }
    private func chooseCategory(_ category: String) {
        navigationGeneration += 1
        if root.page == .statistics { selectedCategory = category; updateSidebar(); root.dashboard?.category = category }
        else { showLibrary(category: category) }
    }
    func showLibrary(category: String?) {
        guard !isSaving else { return }
        if root.page == .editor, root.editor?.hasChanges == true {
            persistDraft { [weak self] success in if success { self?.root.page = .library; self?.showLibrary(category: category) } }
            return
        }
        selectedCategory = category; root.page = .library
        navigationGeneration += 1
        root.title.stringValue = "内容库"
        root.footer.stringValue = ""
        updateSidebar(); refreshLibrary()
    }
    private func updateSidebar() {
        root.all.selected = root.page != .statistics && selectedCategory == nil
        root.stats.selected = root.page == .statistics
        for item in root.categoryItems { item.selected = item.category == selectedCategory }
    }
    @objc private func changed() { reloadCounts(); if root.page == .library { refreshLibrary() } }
    private func reloadCounts() {
        library.load(.categories) { [weak self] result in
            guard let self else { return }
            if case .success(.categories(let categories)) = result {
                self.counts = categories; self.root.all.count = categories.reduce(0) { $0 + $1.entryCount }
                for item in self.root.categoryItems { item.count = categories.first { $0.id == item.category }?.entryCount ?? 0 }
                if self.root.page == .library { self.root.subtitle.stringValue = "\(self.root.all.count ?? 0) 条内容  ·  \(categories.count) 个分类" }
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) { refreshLibrary() }
    private func refreshLibrary() {
        queryGeneration += 1; let generation = queryGeneration
        detailGeneration += 1
        let preserve = selectedEntry?.id ?? "coding-small-steps"
        selectedEntry = nil; root.libraryView.copyButton.isEnabled = false; root.libraryView.editButton.isEnabled = false
        library.manage(category: selectedCategory, query: root.search.field.stringValue) { [weak self] result in
            guard let self, self.queryGeneration == generation else { return }
            switch result {
            case .success(let values):
                self.root.libraryView.listLabel.stringValue = self.selectedCategory.map(Theme.categoryName) ?? "全部条目"
                self.root.libraryView.setItems(values, selecting: preserve)
                self.root.subtitle.stringValue = "\(values.count) 条内容  ·  \(self.counts.count) 个分类"
            case .failure(let error): self.root.libraryView.setItems([], selecting: nil); self.root.subtitle.stringValue = error.localizedDescription
            }
        }
    }
    private func select(_ value: ManagedSummary) {
        detailGeneration += 1; let generation = detailGeneration
        selectedEntry = nil; root.libraryView.copyButton.isEnabled = false; root.libraryView.editButton.isEnabled = false
        library.load(.detail(value.summary.categoryID, value.summary.id)) { [weak self] result in
            guard let self, self.detailGeneration == generation else { return }
            if case .success(.detail(let entry)) = result { self.selectedEntry = entry; self.root.libraryView.setEntry(entry) }
            else { self.root.libraryView.setEntry(nil) }
        }
    }
    private func copyEntry() {
        guard let entry = selectedEntry else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(entry.prompt, forType: .string) {
            DiagnosticLog.shared.write(.copySucceeded, fields: .init(stage: "management", promptUTF16Count: (entry.prompt as NSString).length))
            library.recordUsage(entry, kind: .copy) { [weak self] result in
                if case .failure = result { self?.root.footer.stringValue = "复制成功，但使用记录未保存。" }
            }
            root.footer.stringValue = "已复制完整 Prompt"
        } else {
            DiagnosticLog.shared.write(.copyFailed, level: .error, fields: .init(stage: "management"))
            root.footer.stringValue = "复制失败，请重试。"
        }
    }
    func newEntry() {
        guard !isSaving else { return }
        navigationGeneration += 1; let generation = navigationGeneration
        library.editorDraft { [weak self] result in
            guard let self, self.navigationGeneration == generation else { return }
            switch result {
            case .success(let draft):
                let empty = PromptEntry(id: UUID().uuidString, categoryID: self.selectedCategory ?? "requirements", title: "", summary: "", originalExperience: "", source: "", explanation: "", prompt: "")
                self.presentEditor(draft ?? EditorDraft(entry: empty, original: nil))
            case .failure(let error): self.root.footer.stringValue = "无法恢复草稿：" + error.localizedDescription
            }
        }
    }
    private func editEntry() {
        guard let selected = selectedEntry else { return }
        navigationGeneration += 1; let generation = navigationGeneration
        library.editorDraft { [weak self] result in
            guard let self, self.navigationGeneration == generation else { return }
            switch result {
            case .success(let draft):
                if let draft, draft.entry.id != selected.id {
                    let alert = NSAlert(); alert.messageText = "存在未完成的草稿"; alert.informativeText = "继续该草稿，或明确放弃后编辑当前条目。"
                    alert.addButton(withTitle: "继续草稿"); alert.addButton(withTitle: "放弃草稿并编辑"); alert.addButton(withTitle: "取消")
                    let choice = alert.runModal()
                    if choice == .alertFirstButtonReturn { self.presentEditor(draft) }
                    else if choice == .alertSecondButtonReturn {
                        self.library.discardDraft { result in
                            if case .success = result { self.presentEditor(EditorDraft(entry: selected, original: selected)) }
                            else { self.root.footer.stringValue = "无法清除旧草稿，当前输入已保留。" }
                        }
                    }
                } else { self.presentEditor(draft ?? EditorDraft(entry: selected, original: selected)) }
            case .failure(let error): self.root.footer.stringValue = error.localizedDescription
            }
        }
    }
    private func presentEditor(_ draft: EditorDraft) {
        draftWork?.cancel(); root.editor = PromptEditorView(draft: draft)
        root.editor?.onChange = { [weak self] in self?.scheduleDraft() }
        root.page = .editor; root.title.stringValue = draft.original == nil ? "新增经验" : "编辑条目"
        root.subtitle.stringValue = ""; root.statusLabel.stringValue = "尚未保存"
        root.requiredLabel.stringValue = ""; root.requiredLabel.textColor = Theme.secondary
        root.footer.stringValue = ""
        root.saveButton.isEnabled = true; updateSidebar(); root.needsLayout = true
    }
    private func scheduleDraft() {
        draftWork?.cancel(); root.statusLabel.stringValue = "尚未保存"
        let work = DispatchWorkItem { [weak self] in self?.persistDraft() }; draftWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    private func persistDraft(updateStatus: Bool = true, completion: ((Bool) -> Void)? = nil) {
        draftWork?.cancel()
        guard let editor = root.editor, editor.hasChanges else { completion?(true); return }
        library.storeDraft(editor.value, original: editor.original) { [weak self] result in
            switch result {
            case .success: if updateStatus { self?.root.statusLabel.stringValue = "草稿已保存" }; completion?(true)
            case .failure(let error): self?.root.statusLabel.stringValue = "草稿保存失败"; self?.root.requiredLabel.stringValue = error.localizedDescription; completion?(false)
            }
        }
    }
    private func leaveEditor() { showLibrary(category: selectedCategory) }
    func saveEditor() {
        guard !isSaving, let editor = root.editor else { return }
        let value = editor.value
        guard !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !value.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            DiagnosticLog.shared.write(.storageFailed, level: .warning, fields: .init(stage: "form-validation", errorCode: "required-fields"))
            root.requiredLabel.stringValue = "请填写标题和 Prompt。"; root.requiredLabel.textColor = Theme.error; return
        }
        draftWork?.cancel(); isSaving = true; setSaving(true); root.statusLabel.stringValue = "正在保存…"
        library.save(value, replacing: editor.original) { [weak self] result in
            guard let self else { return }; self.isSaving = false; self.setSaving(false)
            switch result {
            case .success:
                editor.markSaved(value); self.selectedEntry = value; self.root.editor = nil
                self.showLibrary(category: nil); self.root.footer.stringValue = "已保存"
            case .failure(let error):
                self.root.statusLabel.stringValue = "保存失败"; self.root.requiredLabel.stringValue = error.localizedDescription
                self.root.requiredLabel.textColor = Theme.error; self.persistDraft(updateStatus: false)
            }
            let finish = self.afterSave; self.afterSave = nil; finish?()
        }
    }
    func showStatistics() {
        guard !isSaving else { return }
        if root.page == .editor, root.editor?.hasChanges == true {
            persistDraft { [weak self] success in if success { self?.root.page = .statistics; self?.showStatistics() } }
            return
        }
        selectedCategory = nil
        navigationGeneration += 1
        root.page = .statistics
        if root.dashboard == nil { root.dashboard = UsageDashboard(library: library) }
        root.dashboard?.category = selectedCategory; root.dashboard?.reload(); updateSidebar()
    }
    func prepareForTermination(_ completion: @escaping (Bool) -> Void) {
        if isSaving {
            let previous = afterSave
            afterSave = { [weak self] in previous?(); self?.persistDraft(completion: completion) }
            return
        }
        persistDraft(completion: completion)
    }
    private func setSaving(_ saving: Bool) {
        root.saveButton.isEnabled = !saving; root.cancelButton.isEnabled = !saving
        ([root.all, root.stats] + root.categoryItems).forEach { $0.isEnabled = !saving }
        root.editor?.setEditingEnabled(!saving)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        prepareForTermination { [weak self] success in if success { self?.window?.orderOut(nil) } }
        return false
    }
}
