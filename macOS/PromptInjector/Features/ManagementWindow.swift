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
    let categories: [PromptCategory]
    var count: Int? { didSet { needsDisplay = true } }
    var selected = false { didSet { needsDisplay = true; setAccessibilityValue(selected ? 1 : 0) } }
    override var isFlipped: Bool { true }
    init(_ label: String, category: String? = nil, asset: String? = nil, categories: [PromptCategory] = []) {
        self.label = label; self.category = category; self.asset = asset; self.categories = categories
        super.init(frame: .zero)
        isBordered = false; title = ""; target = self; action = #selector(press)
        setAccessibilityLabel(label); toolTip = label
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func press() { onPress?() }
    override func draw(_ dirtyRect: NSRect) {
        if selected || isHighlighted {
            (selected ? Theme.selection : Theme.band).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill()
        }
        let color = category.map { Theme.categoryColor($0, in: categories) } ?? (selected ? Theme.text : Theme.secondary)
        if let category {
            DesignAssets.categoryDot(category, in: categories).draw(in: NSRect(x: 2, y: bounds.midY - 13.5, width: 27, height: 27), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else if let asset, let image = DesignAssets.image(asset) {
            // SVG icons retain the Figma viewBox; tint is applied by AppKit at draw time.
            image.draw(in: NSRect(x: 12, y: bounds.midY - 9, width: 18, height: 18), from: .zero, operation: .sourceOver, fraction: selected ? 1 : 0.68, respectFlipped: true, hints: nil)
        }
        let countWidth = count.map { max(16, (String($0) as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width) } ?? 0
        let labelX: CGFloat = category == nil ? 38 : 29
        Theme.drawLine(label, font: .systemFont(ofSize: 13), color: color, in: NSRect(x: labelX, y: 0, width: bounds.width - labelX - 12 - countWidth - 8, height: bounds.height))
        if let count {
            Theme.drawLine(String(count), font: .systemFont(ofSize: 12), color: Theme.tertiary, in: NSRect(x: bounds.width - 12 - countWidth, y: 0, width: countWidth, height: bounds.height), alignment: .right)
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
    enum Page { case library, editor, statistics, experience }
    var page: Page = .library { didSet { if oldValue != page { PageTransition.fade(self, duration: page == .library ? 0.14 : 0.18) }; needsLayout = true } }
    let sidebar = SurfaceView(color: Theme.shell, radius: 0, border: nil)
    let logo = LogoView(frame: .zero)
    let brand = Theme.label("Prompt Injector", size: 15, weight: .semibold)
    let all = SidebarItem("全部内容", asset: "Grid"), stats = SidebarItem("使用统计", asset: "Chart")
    let categoryLabel = Theme.label("分类", size: 11, color: Theme.tertiary)
    private(set) var categoryItems: [SidebarItem] = []
    private let categoryScroll = NSScrollView(), categoryBody = FlippedView()
    func setCategories(_ categories: [PromptCategory]) {
        categoryItems.forEach { $0.removeFromSuperview() }
        categoryItems = categories.map { SidebarItem($0.name, category: $0.id, categories: categories) }
        for (item, category) in zip(categoryItems, categories) { item.count = category.entryCount; categoryBody.addSubview(item) }
        needsLayout = true
    }
    private let sidebarRule = SurfaceView(color: Theme.hex(0x353535), radius: 0, border: nil)
    private let lowerRule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    private let shortcut = Theme.label("⇧⌥Space", size: 11, color: Theme.tertiary)
    let title = Theme.label("内容库", size: 26, weight: .medium)
    let subtitle = Theme.label(size: 12, color: Theme.secondary)
    let band = SurfaceView(color: Theme.band, radius: 16, border: nil)
    let search = SearchBox()
    let newButton = ActionButton(title: "新增经验", symbol: nil, primary: true, target: nil, action: nil)
    let gridButton = ActionButton(title: "", symbol: "square.grid.2x2", target: nil, action: nil)
    let listButton = ActionButton(title: "", symbol: "list.bullet", target: nil, action: nil)
    let backButton = ActionButton(title: "返回全部内容", symbol: nil, target: nil, action: nil)
    let statusLabel = Theme.label("尚未保存", size: 13)
    private let statusDot = NSImageView()
    let requiredLabel = Theme.label(size: 12, color: Theme.secondary)
    let cancelButton = ActionButton(title: "取消", symbol: nil, target: nil, action: nil)
    let saveButton = ActionButton(title: "保存条目", symbol: "checkmark", primary: true, target: nil, action: nil)
    let libraryView = ManagementLibraryView()
    var editor: PromptEditorView? {
        didSet {
            [cancelButton, saveButton, requiredLabel].forEach(band.addSubview)
            oldValue?.inlineActions = nil
            oldValue?.removeFromSuperview()
            if let editor {
                if editor.inlineMode {
                    libraryView.preview.addSubview(editor); [cancelButton, saveButton, requiredLabel].forEach(editor.content.addSubview)
                    editor.inlineActions = (cancelButton, saveButton, requiredLabel)
                }
                else { addSubview(editor) }
            }
            needsLayout = true
        }
    }
    var experienceView: ExperienceView? { didSet { oldValue?.removeFromSuperview(); if let experienceView { addSubview(experienceView) }; needsLayout = true } }
    var dashboard: UsageDashboard? { didSet { oldValue?.removeFromSuperview(); if let dashboard { addSubview(dashboard) }; needsLayout = true } }
    let footer = Theme.label(size: 11, color: Theme.tertiary)
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; layer?.backgroundColor = Theme.canvas.cgColor; layer?.cornerRadius = 20; layer?.masksToBounds = true
        [sidebar, title, subtitle, band, libraryView, footer, backButton].forEach(addSubview)
        [logo, brand, all, stats, sidebarRule, categoryLabel, lowerRule, shortcut].forEach(sidebar.addSubview)
        sidebar.addSubview(categoryScroll); categoryScroll.drawsBackground = false
        categoryScroll.hasVerticalScroller = true; categoryScroll.scrollerStyle = .overlay; categoryScroll.documentView = categoryBody
        [search, newButton, gridButton, listButton, statusDot, statusLabel, requiredLabel, cancelButton, saveButton].forEach(band.addSubview)
        gridButton.outlined = true; listButton.outlined = true; backButton.outlined = true
        gridButton.setAccessibilityLabel("卡片视图"); listButton.setAccessibilityLabel("列表视图")
        statusDot.image = DesignAssets.image("Status"); statusDot.contentTintColor = Theme.hex(0xF5D975)
        requiredLabel.lineBreakMode = .byWordWrapping; requiredLabel.maximumNumberOfLines = 2
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
        categoryScroll.frame = NSRect(x: 10, y: 229, width: 196, height: max(0, h - 301))
        categoryBody.frame = NSRect(x: 0, y: 0, width: 196, height: CGFloat(categoryItems.count) * 54)
        for (i, item) in categoryItems.enumerated() { item.frame = NSRect(x: 10, y: CGFloat(i) * 54, width: 176, height: 44) }
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
        if page == .library {
            subtitle.isHidden = true
            band.layer?.backgroundColor = NSColor.clear.cgColor
            band.frame = NSRect(x: w - 448, y: 32, width: 416, height: 44)
            search.frame = NSRect(x: 0, y: 0, width: 360, height: 40)
            newButton.frame = NSRect(x: 376, y: 0, width: 40, height: 40)
            title.frame.size.width = max(100, main - 440)
            libraryView.frame = NSRect(x: 248, y: 112, width: main, height: h - 144)
            footer.frame = NSRect(x: 248, y: h - 26, width: main, height: 20)
        } else { band.layer?.backgroundColor = Theme.band.cgColor }
        libraryView.isHidden = page != .library; editor?.isHidden = !editing; dashboard?.isHidden = !statistics
        experienceView?.isHidden = page != .experience
        if page == .experience {
            subtitle.isHidden = false; footer.isHidden = true
            band.frame = NSRect(x: 248, y: 32, width: main, height: 40); band.layer?.backgroundColor = NSColor.clear.cgColor
            [search, newButton, statusDot, statusLabel, requiredLabel, saveButton].forEach { $0.isHidden = true }
            cancelButton.isHidden = false; cancelButton.title = "返回内容库"; cancelButton.outlined = true
            cancelButton.frame = NSRect(x: main - 128, y: 0, width: 128, height: 40)
            title.frame.size.width = main - 100
            experienceView?.frame = NSRect(x: 248, y: 134, width: main, height: h - 166)
            if let experienceView, !experienceView.controller.session.items.isEmpty || experienceView.completedCount > 0 {
                title.frame = NSRect(x: 248, y: 36, width: main - 240, height: 38)
                subtitle.isHidden = false
                subtitle.frame = NSRect(x: 248, y: 82, width: main, height: 22)
                cancelButton.isHidden = true; saveButton.isHidden = false
                saveButton.frame = NSRect(x: main - 172, y: 0, width: 172, height: 40)
                experienceView.frame = NSRect(x: 248, y: 134, width: main, height: h - 166)
            }
        } else { cancelButton.outlined = true }
        if editing, editor?.reviewMode == true {
            subtitle.isHidden = true; footer.isHidden = true
            band.frame = NSRect(x: 248, y: 32, width: main, height: 40); band.layer?.backgroundColor = NSColor.clear.cgColor
            statusDot.isHidden = true; statusLabel.isHidden = true
            requiredLabel.frame = NSRect(x: 0, y: 44, width: main, height: 24)
            cancelButton.frame = NSRect(x: main - 260, y: 0, width: 100, height: 40)
            saveButton.frame = NSRect(x: main - 144, y: 0, width: 144, height: 40)
            title.frame.size.width = main - 320
            editor?.frame = NSRect(x: 248, y: 112, width: main, height: h - 144)
        }
        gridButton.isHidden = page != .library; listButton.isHidden = page != .library
        backButton.isHidden = true
        if page == .library || (editing && editor?.inlineMode == true) {
            let grid = libraryView.presentation == .grid && !editing
            title.isHidden = !grid; subtitle.isHidden = !grid; band.isHidden = !grid
            backButton.isHidden = grid; backButton.frame = NSRect(x: 248, y: 36, width: 150, height: 40)
            band.frame = NSRect(x: w - 556, y: 36, width: 524, height: 40)
            search.frame = NSRect(x: 0, y: 0, width: 260, height: 40)
            gridButton.frame = NSRect(x: 272, y: 0, width: 40, height: 40)
            listButton.frame = NSRect(x: 322, y: 0, width: 40, height: 40)
            newButton.frame = NSRect(x: 372, y: 0, width: 140, height: 40)
            title.frame = NSRect(x: 248, y: 36, width: max(150, main - 580), height: 38)
            subtitle.frame = NSRect(x: 248, y: 82, width: main, height: 22)
            gridButton.selectedStyle = grid; listButton.selectedStyle = !grid
            libraryView.frame = NSRect(x: 248, y: 134, width: main, height: h - 166)
            libraryView.isHidden = false; libraryView.isEditing = editing
            if editing, let editor {
                editor.frame = libraryView.preview.bounds
                saveButton.title = "保存修改"
                requiredLabel.isHidden = false
            }
        }
    }
}

final class ManagementSummaryCell: NSTableCellView {
    override var isFlipped: Bool { true }
    let heading = Theme.label(size: 14, weight: .medium), summary = Theme.label(size: 12, color: Theme.secondary)
    override init(frame: NSRect) { super.init(frame: frame); [heading, summary].forEach(addSubview) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func set(_ value: ManagedSummary) {
        heading.stringValue = value.summary.title; summary.stringValue = value.summary.summary
        toolTip = value.summary.title + "\n" + value.summary.summary
    }
    override func layout() {
        super.layout(); heading.frame = NSRect(x: 16, y: 16, width: bounds.width - 32, height: 22)
        summary.frame = NSRect(x: 16, y: 44, width: bounds.width - 32, height: 20)
    }
}

@MainActor final class ManagementLibraryView: FlippedView, NSTableViewDataSource, NSTableViewDelegate {
    enum Presentation { case grid, detail }
    var presentation: Presentation = .grid { didSet { needsLayout = true; onPresentationChange?() } }
    var onPresentationChange: (() -> Void)?
    var isEditing = false { didSet { if oldValue != isEditing { needsLayout = true } } }
    var navigationEnabled = true
    let grid = ManagementGrid(frame: .zero)
    let listPanel = SurfaceView(color: Theme.shell), preview = SurfaceView(color: Theme.shell)
    let table = NSTableView(), listScroll = NSScrollView()
    let categoryLabel = Theme.label(size: 13, weight: .medium)
    let heading = Theme.label(size: 22, weight: .medium), summary = Theme.label(size: 13, color: Theme.secondary)
    private let rule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    let document = TextDocument(), scroll = NSScrollView()
    let segments = ChoiceSegments(["Prompt", "作者原文", "整理说明"])
    let copyButton = ActionButton(title: "", symbol: "doc.on.doc", target: nil, action: nil), editButton = ActionButton(title: "", symbol: "pencil", target: nil, action: nil)
    let moreButton = ActionButton(title: "", symbol: "ellipsis", target: nil, action: nil)
    var onDelete: (() -> Void)?
    let sourceButton = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    var onSelect: ((ManagedSummary) -> Void)?
    private(set) var items: [ManagedSummary] = []
    private var settingSelection = false
    private var entry: PromptEntry?
    var categories: [PromptCategory] = [] { didSet { grid.categories = categories; table.reloadData(); setEntry(entry) } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(listPanel); addSubview(preview); addSubview(grid); listPanel.addSubview(listScroll)
        grid.onOpen = { [weak self] item in self?.openItem(id: item.summary.id) }
        [categoryLabel, heading, summary, rule, scroll, segments, copyButton, editButton, moreButton, sourceButton].forEach(preview.addSubview)
        for field in [heading, summary] { field.maximumNumberOfLines = 2; field.lineBreakMode = .byTruncatingTail; field.cell?.wraps = true; field.cell?.isScrollable = false }
        table.addTableColumn(NSTableColumn(identifier: .init("entry"))); table.headerView = nil; table.style = .plain
        table.backgroundColor = .clear; table.rowHeight = 80; table.intercellSpacing = NSSize(width: 0, height: 4)
        table.focusRingType = .none; table.dataSource = self; table.delegate = self; table.allowsEmptySelection = true
        listScroll.drawsBackground = false; listScroll.hasVerticalScroller = true; listScroll.scrollerStyle = .overlay; listScroll.documentView = table
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay; scroll.documentView = document
        copyButton.outlined = true; editButton.outlined = true
        copyButton.toolTip = "复制完整 Prompt"; copyButton.setAccessibilityLabel("复制完整 Prompt")
        editButton.toolTip = "编辑条目"; editButton.setAccessibilityLabel("编辑条目")
        moreButton.toolTip = "更多操作"; moreButton.outlined = true; moreButton.setAccessibilityLabel("更多操作")
        moreButton.onPress = { [weak self] in self?.showMore() }
        copyButton.title = "复制 Prompt"; copyButton.imagePosition = .imageLeading; copyButton.primary = true
        sourceButton.onPress = { [weak self] in if let url = self?.entry.flatMap({ SourceLink.inSource($0.source) }) { NSWorkspace.shared.open(url) } }
        segments.onSelect = { [weak self] _ in
            guard let self else { return }; PageTransition.fade(self.scroll, duration: 0.12); self.updateDocument(); self.scroll.contentView.scroll(to: .zero); self.scroll.reflectScrolledClipView(self.scroll.contentView)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func showMore() {
        let menu = NSMenu()
        let item = NSMenuItem(title: "删除这条经验…", action: #selector(deleteFromMenu), keyEquivalent: "")
        item.target = self; menu.addItem(item)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 40), in: moreButton)
    }
    @objc private func deleteFromMenu() { onDelete?() }
    func setItems(_ items: [ManagedSummary], selecting id: String?) {
        settingSelection = true; self.items = items; table.reloadData()
        if !items.isEmpty {
            let index = id.flatMap { id in items.firstIndex { $0.summary.id == id } } ?? 0
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else { table.deselectAll(nil); setEntry(nil) }
        settingSelection = false
        grid.setItems(items, selected: id)
        if presentation == .detail, items.indices.contains(table.selectedRow) { onSelect?(items[table.selectedRow]) }
    }
    func openItem(id: String) {
        guard let index = items.firstIndex(where: { $0.summary.id == id }) else { return }
        presentation = .detail; settingSelection = true
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false); table.scrollRowToVisible(index)
        settingSelection = false; onSelect?(items[index])
    }
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { navigationEnabled }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { let cell = ManagementSummaryCell(); cell.set(items[row]); return cell }
    func tableViewSelectionDidChange(_ notification: Notification) { if !settingSelection, items.indices.contains(table.selectedRow) { onSelect?(items[table.selectedRow]) } }
    func setEntry(_ value: PromptEntry?) {
        let changedID = entry?.id != value?.id
        if changedID { segments.selectedIndex = 0 }
        entry = value; copyButton.isEnabled = value != nil; editButton.isEnabled = value != nil; moreButton.isEnabled = value != nil
        sourceButton.isHidden = value?.source.isEmpty != false; sourceButton.isEnabled = value.flatMap { SourceLink.inSource($0.source) } != nil
        SourceBadge.set(sourceButton, source: value?.source ?? "")
        segments.buttons.forEach { $0.isEnabled = value != nil }
        heading.stringValue = value?.title ?? "没有匹配内容"; summary.stringValue = value?.summary ?? ""
        heading.toolTip = value?.title; summary.toolTip = value?.summary
        categoryLabel.stringValue = value.map { Theme.categoryName($0.categoryID, in: categories) } ?? ""
        categoryLabel.textColor = value.map { Theme.categoryColor($0.categoryID, in: categories) } ?? Theme.text
        updateDocument(); needsLayout = true
        if changedID { scroll.contentView.scroll(to: .zero) }
    }
    private func updateDocument() {
        let content = NSMutableAttributedString(string: "")
        if let entry {
            switch segments.selectedIndex {
            case 1:
                if !entry.source.isEmpty {
                    let source = NSMutableAttributedString(attributedString: Theme.body(entry.source, size: 13, color: Theme.secondary, lineHeight: 24))
                    if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                        for match in detector.matches(in: entry.source, range: NSRange(location: 0, length: (entry.source as NSString).length)) {
                            if let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { source.addAttribute(.link, value: url, range: match.range) }
                        }
                    }
                    content.append(source); content.append(Theme.body("\n\n"))
                }
                content.append(Theme.body(entry.originalExperience, size: 16, lineHeight: 32))
            case 2: content.append(Theme.body(entry.explanation, size: 14, lineHeight: 28))
            default: content.append(Theme.body(entry.prompt, size: 16, lineHeight: 32))
            }
        }
        document.set(content, width: max(100, scroll.contentSize.width))
    }
    override func layout() {
        super.layout(); let listWidth: CGFloat = bounds.width >= 1100 ? 352 : 280
        grid.frame = bounds; grid.isHidden = presentation != .grid
        listPanel.isHidden = presentation == .grid; preview.isHidden = presentation == .grid
        [categoryLabel, heading, summary, rule, scroll, segments, copyButton, editButton, moreButton, sourceButton].forEach { $0.isHidden = isEditing }
        if !isEditing { sourceButton.isHidden = entry?.source.isEmpty != false }
        listPanel.frame = NSRect(x: 0, y: 0, width: listWidth, height: bounds.height)
        preview.frame = NSRect(x: listWidth + 20, y: 0, width: bounds.width - listWidth - 20, height: bounds.height)
        for editor in preview.subviews.compactMap({ $0 as? PromptEditorView }) { editor.frame = preview.bounds }
        listScroll.frame = NSRect(x: 12, y: 12, width: listWidth - 24, height: bounds.height - 24)
        table.tableColumns.first?.width = listScroll.contentSize.width
        let w = preview.bounds.width, h = preview.bounds.height, pad: CGFloat = bounds.width >= 1100 ? 32 : 24
        let width = w - 2 * pad
        categoryLabel.frame = NSRect(x: pad, y: 24, width: width, height: 20)
        func place(_ field: NSTextField, y: CGFloat, lineHeight: CGFloat) {
            let natural = field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)).height ?? lineHeight
            field.frame = NSRect(x: pad, y: y, width: width, height: min(lineHeight * 2, max(lineHeight, ceil(natural))))
        }
        place(heading, y: 56, lineHeight: 32); place(summary, y: heading.frame.maxY + 12, lineHeight: 22)
        sourceButton.frame = NSRect(x: pad - 8, y: summary.frame.maxY + 16, width: min(260, width), height: 28)
        sourceButton.alignment = .left; sourceButton.font = .systemFont(ofSize: 13)
        segments.frame = NSRect(x: pad, y: sourceButton.isHidden ? summary.frame.maxY + 24 : sourceButton.frame.maxY + 24, width: min(336, width), height: 44)
        rule.frame = NSRect(x: pad, y: segments.frame.maxY + 24, width: width, height: 1)
        scroll.frame = NSRect(x: pad, y: rule.frame.maxY + 24, width: min(640, width), height: max(40, h - 112 - rule.frame.maxY))
        copyButton.frame = NSRect(x: w - pad - 216, y: h - 64, width: 116, height: 40); editButton.frame = NSRect(x: w - pad - 90, y: h - 64, width: 40, height: 40)
        moreButton.frame = NSRect(x: w - pad - 40, y: h - 64, width: 40, height: 40)
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
    private let generator: PromptGenerating
    private let experienceService: ExperienceServing
    private(set) var experience: ExperienceController?
    private var reviewID: String?
    private var generationTask: Task<Void, Never>?
    private var generationID: UUID?
    var isGenerating: Bool { generationID != nil }
    var confirmCandidateReplacement: () -> Bool = {
        let alert = NSAlert(); alert.messageText = "重新整理当前经验？"
        alert.informativeText = "成功后会替换当前候选及其修改。左侧和 Prompt 页的编辑稿保留。"
        alert.addButton(withTitle: "重新整理"); alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }
    var confirmDeletion: (PromptEntry) -> Bool = { entry in
        ManagementWindowController.deletionAlert(entry).runModal() == .alertSecondButtonReturn
    }
    static func deletionAlert(_ entry: PromptEntry) -> NSAlert {
        let alert = NSAlert(); alert.messageText = "删除这条经验？"; alert.informativeText = "「\(entry.title)」将被删除，无法恢复。"
        alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "删除")
        styleConfirmation(alert)
        alert.buttons[0].keyEquivalent = "\r"; alert.buttons[1].keyEquivalent = ""
        alert.window.initialFirstResponder = alert.buttons[0]
        return alert
    }
    static func comparisonAlert(current: String, proposed: String) -> NSAlert {
        let alert = NSAlert(); alert.messageText = "比较新建议"
        alert.accessoryView = PromptComparisonView(current: current, proposed: proposed)
        alert.addButton(withTitle: "保留当前版本"); alert.addButton(withTitle: "采用新版本")
        styleConfirmation(alert)
        return alert
    }
    private static func styleConfirmation(_ alert: NSAlert) {
        alert.window.appearance = NSAppearance(named: .darkAqua)
        for (index, button) in alert.buttons.enumerated() {
            button.isBordered = false; button.wantsLayer = true; button.layer?.cornerRadius = 8
            button.layer?.backgroundColor = (index == 0 ? NSColor.clear : Theme.selection).cgColor
            button.layer?.borderWidth = index == 0 ? 1 : 0; button.layer?.borderColor = Theme.border.cgColor
            button.attributedTitle = NSAttributedString(string: button.title, attributes: [.foregroundColor: Theme.text, .font: NSFont.systemFont(ofSize: 13, weight: .medium)])
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        }
    }
    var needsTerminationSave: Bool { isSaving || root.editor?.hasChanges == true || experience != nil }
    init(library: PromptLibrary, generator: PromptGenerating = DeepSeekClient(), experienceService: ExperienceServing = DeepSeekClient()) {
        self.library = library; self.generator = generator; self.experienceService = experienceService
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
        root.newButton.onPress = { [weak self] in self?.newExperience() }
        root.gridButton.onPress = { [weak self] in self?.root.libraryView.presentation = .grid }
        root.listButton.onPress = { [weak self] in
            guard let self, let id = self.selectedEntry?.id ?? self.root.libraryView.items.first?.summary.id else { return }
            self.root.libraryView.openItem(id: id)
        }
        root.backButton.onPress = { [weak self] in self?.backToGrid() }
        root.libraryView.onPresentationChange = { [weak self] in
            guard let self else { return }; self.root.needsLayout = true
            if self.root.libraryView.presentation == .grid { self.root.libraryView.grid.focus() }
        }
        root.cancelButton.onPress = { [weak self] in
            guard let self else { return }
            if self.root.editor?.inlineMode == true { self.leaveInlineEditor() }
            else if self.reviewID != nil { self.backToExperience() }
            else { self.leaveEditor() }
        }
        root.saveButton.onPress = { [weak self] in self?.saveEditor() }
        root.search.field.delegate = self
        root.libraryView.onSelect = { [weak self] in self?.select($0) }
        root.libraryView.copyButton.onPress = { [weak self] in self?.copyEntry() }
        root.libraryView.editButton.onPress = { [weak self] in self?.editEntry() }
        root.libraryView.onDelete = { [weak self] in self?.deleteSelected() }
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: .promptLibraryChanged, object: library)
        reloadCounts(); showLibrary(category: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self); draftWork?.cancel() }
    func show() {
        NSApp.setActivationPolicy(.regular)
        if let icon = DesignAssets.image("AppIcon", template: false) { NSApp.applicationIconImage = icon }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if root.page == .library, root.libraryView.presentation == .grid { root.libraryView.grid.focus() }
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
        if experience != nil { finishExperience { [weak self] in self?.showLibrary(category: category) }; return }
        cancelGeneration()
        if root.page == .editor, root.editor?.hasChanges == true {
            persistDraft { [weak self] success in if success { self?.root.page = .library; self?.showLibrary(category: category) } }
            return
        }
        selectedCategory = category; root.page = .library; root.libraryView.presentation = .grid
        navigationGeneration += 1
        root.title.stringValue = "全部内容"
        root.footer.stringValue = ""
        updateSidebar(); refreshLibrary(preserveScroll: false)
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
                self.root.setCategories(categories)
                for item in self.root.categoryItems { item.onPress = { [weak self] in if let id = item.category { self?.chooseCategory(id) } } }
                self.root.libraryView.categories = categories; self.root.editor?.setCategories(categories)
                self.root.experienceView?.categories = categories
                self.updateSidebar()
                if self.root.page == .library { self.root.subtitle.stringValue = "\(self.root.libraryView.items.count) 条内容  ·  \(categories.count) 个分类" }
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) { refreshLibrary(preserveScroll: false) }
    private func refreshLibrary(preserveScroll: Bool = true) {
        queryGeneration += 1; let generation = queryGeneration
        detailGeneration += 1
        let preserve = selectedEntry?.id
        let scrollY = preserveScroll ? root.libraryView.grid.scroll.contentView.bounds.minY : 0
        selectedEntry = nil; root.libraryView.setEntry(nil); root.libraryView.setItems([], selecting: nil)
        root.title.stringValue = selectedCategory.flatMap { id in counts.first { $0.id == id }?.name } ?? "全部内容"
        root.subtitle.stringValue = "0 条内容  ·  \(counts.count) 个分类"
        library.manage(category: selectedCategory, query: root.search.field.stringValue) { [weak self] result in
            guard let self, self.queryGeneration == generation, self.root.page == .library else {
                DiagnosticLog.shared.write(.libraryLoadDiscarded, fields: .init(stage: "management-stale-query")); return
            }
            switch result {
            case .success(let values):
                self.root.libraryView.setItems(values, selecting: preserve)
                self.root.libraryView.grid.restoreScroll(scrollY)
                self.root.subtitle.stringValue = "\(values.count) 条内容  ·  \(self.counts.count) 个分类"
            case .failure(let error): self.root.libraryView.setItems([], selecting: nil); self.root.footer.stringValue = error.localizedDescription
            }
        }
    }
    private func select(_ value: ManagedSummary) {
        guard !isSaving else { return }
        if root.editor?.inlineMode == true {
            let navigation = navigationGeneration + 1; navigationGeneration = navigation
            persistDraft { [weak self] success in
                guard let self, success, self.navigationGeneration == navigation else { return }
                self.cancelGeneration(); self.root.editor = nil; self.root.page = .library; self.select(value)
            }
            return
        }
        detailGeneration += 1; let generation = detailGeneration
        selectedEntry = nil; root.libraryView.setEntry(nil)
        library.load(.detail(value.summary.categoryID, value.summary.id)) { [weak self] result in
            guard let self, self.detailGeneration == generation, self.root.page == .library, self.root.libraryView.presentation == .detail else { return }
            if case .success(.detail(let entry)) = result { self.selectedEntry = entry; self.root.libraryView.setEntry(entry) }
            else { self.root.libraryView.setEntry(nil) }
        }
    }
    private func leaveInlineEditor() {
        guard !isSaving else { return }
        cancelGeneration()
        persistDraft { [weak self] success in
            guard let self, success else { return }
            self.root.editor = nil; self.root.page = .library; self.root.needsLayout = true
        }
    }
    private func backToGrid() {
        guard !isSaving else { return }
        if root.editor?.inlineMode == true {
            cancelGeneration()
            persistDraft { [weak self] success in
                guard let self, success else { return }
                self.root.editor = nil; self.root.page = .library; self.root.libraryView.presentation = .grid
            }
        } else { root.libraryView.presentation = .grid }
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
    private func presentEditor(_ draft: EditorDraft, review: Bool = false) {
        cancelGeneration(); draftWork?.cancel()
        root.editor = PromptEditorView(draft: draft, categories: counts, reviewMode: review, inlineMode: !review && draft.original != nil)
        if root.editor?.inlineMode == true { root.libraryView.presentation = .detail }
        root.editor?.onChange = { [weak self] in
            guard let self else { return }; if self.reviewID != nil { self.stashReview() } else { self.cancelGeneration(); self.scheduleDraft() }
        }
        root.editor?.generateButton.onPress = { [weak self] in
            guard let self else { return }
            if self.isGenerating { self.cancelGeneration(); self.root.requiredLabel.stringValue = "整理已取消，输入已保留。" }
            else if let editor = self.root.editor, editor.inlineMode, editor.candidate != nil { self.compareInlineCandidate(editor) }
            else { self.generatePrompt() }
        }
        root.editor?.onFailure = { [weak self] error in
            self?.root.requiredLabel.stringValue = (error as? LibraryFailure)?.localizedDescription ?? "请补齐候选字段，并选择有效分类。"; self?.root.requiredLabel.textColor = Theme.error
            DiagnosticLog.shared.write(.generationFailed, level: .warning, fields: .init(stage: "candidate-validation"))
        }
        root.editor?.configureButton.onPress = { [weak self] in self?.configureAPIKey() }
        root.page = .editor; root.title.stringValue = draft.original == nil ? "新增经验" : "编辑条目"
        root.subtitle.stringValue = ""; root.statusLabel.stringValue = "尚未保存"
        root.requiredLabel.stringValue = ""; root.requiredLabel.textColor = Theme.secondary
        root.footer.stringValue = ""
        root.saveButton.isEnabled = true; updateSidebar(); root.needsLayout = true
        root.cancelButton.title = review ? "返回整理" : "取消"; root.saveButton.title = review ? "保存已确认 \(experience?.session.confirmed.count ?? 0) 条" : "保存条目"
    }
    private func compareInlineCandidate(_ editor: PromptEditorView) {
        guard let candidate = editor.candidate, let window else { return }
        let snapshot = editor.draft
        let alert = Self.comparisonAlert(current: editor.value.prompt, proposed: candidate.prompt)
        alert.beginSheetModal(for: window) { [weak self, weak editor] response in
            guard let self, let editor, self.root.editor === editor, editor.draft == snapshot else {
                DiagnosticLog.shared.write(.generationDiscarded, fields: .init(stage: "inline-comparison-changed")); return
            }
            if response == .alertSecondButtonReturn { editor.adoptCandidate() }
            else { editor.discardCandidate() }
        }
    }
    private func scheduleDraft() {
        draftWork?.cancel(); root.statusLabel.stringValue = "尚未保存"
        let work = DispatchWorkItem { [weak self] in self?.persistDraft() }; draftWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    private func persistDraft(updateStatus: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if let experience {
            stashReview()
            Task { do { try await experience.persist(); completion?(true) } catch { self.root.requiredLabel.stringValue = error.localizedDescription; completion?(false) } }
            return
        }
        draftWork?.cancel()
        guard let editor = root.editor, editor.hasChanges else { completion?(true); return }
        library.storeDraft(editor.draft) { [weak self] result in
            switch result {
            case .success: if updateStatus { self?.root.statusLabel.stringValue = "草稿已保存" }; completion?(true)
            case .failure(let error): self?.root.statusLabel.stringValue = "草稿保存失败"; self?.root.requiredLabel.stringValue = error.localizedDescription; completion?(false)
            }
        }
    }
    func cancelGeneration() {
        guard let id = generationID else { return }
        generationID = nil; generationTask?.cancel(); generationTask = nil
        root.editor?.generateButton.title = root.editor?.inlineMode == true ? "重新生成" : "整理"
        root.requiredLabel.stringValue = "整理已取消，输入已保留。"; root.requiredLabel.textColor = Theme.secondary
        DiagnosticLog.shared.write(.generationCancelled, operationID: id, fields: .init(stage: "invalidated"))
    }
    func generatePrompt() {
        guard !isSaving, !isGenerating, let editor = root.editor, root.page == .editor else {
            DiagnosticLog.shared.write(.generationDiscarded, fields: .init(stage: "busy-or-inactive")); return
        }
        let snapshot = editor.draft, operationID = UUID()
        guard !snapshot.entry.originalExperience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            root.requiredLabel.stringValue = GenerationFailure.emptyExperience.localizedDescription
            DiagnosticLog.shared.write(.generationFailed, operationID: operationID, fields: .init(stage: "validation", errorCode: "empty-experience")); return
        }
        if editor.candidate != nil, !confirmCandidateReplacement() {
            DiagnosticLog.shared.write(.generationCancelled, operationID: operationID, fields: .init(stage: "keep-candidate")); return
        }
        generationID = operationID; editor.generateButton.title = "取消整理"
        root.requiredLabel.stringValue = "正在整理…"; root.requiredLabel.textColor = Theme.secondary
        DiagnosticLog.shared.write(.generationStarted, operationID: operationID, fields: .init(stage: "saving-draft"))
        // The exact request input must be durable before a network request starts.
        draftWork?.cancel()
        library.storeDraft(snapshot) { [weak self, weak editor] result in
            guard let self, let editor, self.generationID == operationID, self.root.editor === editor else { return }
            switch result {
            case .failure(let error): self.finishGeneration(error: error, operationID: operationID, stage: "draft")
            case .success:
                self.root.statusLabel.stringValue = "草稿已保存"
                self.library.load(.categories) { [weak self, weak editor] result in
                    guard let self, let editor, self.generationID == operationID, self.root.editor === editor else { return }
                    guard case .success(.categories(let categories)) = result else {
                        self.finishGeneration(error: LibraryFailure.invalidCategory, operationID: operationID, stage: "categories"); return
                    }
                    let generator = self.generator
                    self.generationTask = Task { [weak self, weak editor] in
                        do {
                            let candidate = try await generator.generate(experience: snapshot.entry.originalExperience, source: snapshot.entry.source, categories: categories)
                            guard let self, let editor else { return }
                            guard self.generationID == operationID, self.root.editor === editor, editor.draft == snapshot, !Task.isCancelled else {
                                if self.generationID == operationID { self.cancelGeneration(); self.root.requiredLabel.stringValue = "输入已更改，请重新整理。" }
                                DiagnosticLog.shared.write(.generationDiscarded, operationID: operationID, fields: .init(stage: "stale-response")); return
                            }
                            self.generationID = nil; self.generationTask = nil; editor.generateButton.title = "整理"
                            editor.receiveCandidate(candidate)
                            self.root.requiredLabel.stringValue = "候选已就绪，请审核后采用。"
                            DiagnosticLog.shared.write(.generationFinished, operationID: operationID, fields: .init(stage: "candidate"))
                            self.persistDraft()
                            if editor.inlineMode { self.compareInlineCandidate(editor) }
                        } catch {
                            guard let self, self.generationID == operationID else {
                                DiagnosticLog.shared.write(.generationDiscarded, operationID: operationID, fields: .init(stage: "stale-failure")); return
                            }
                            self.finishGeneration(error: error, operationID: operationID, stage: "request")
                        }
                    }
                }
            }
        }
    }
    private func finishGeneration(error: Error, operationID: UUID, stage: String) {
        generationID = nil; generationTask = nil; root.editor?.generateButton.title = root.editor?.inlineMode == true ? "重新生成" : "整理"
        let urlError = error as? URLError
        let message: String
        switch urlError?.code {
        case .timedOut: message = "DeepSeek 请求超时，输入已保留，请重试。"
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost: message = "无法连接 DeepSeek，请检查网络后重试。"
        case .cancelled: message = "整理已取消，输入已保留。"
        default: message = (error as? GenerationFailure)?.localizedDescription ?? (error as? LibraryFailure)?.localizedDescription ?? "整理失败，输入已保留，请重试。"
        }
        root.requiredLabel.stringValue = message; root.requiredLabel.textColor = Theme.error
        root.requiredLabel.toolTip = message
        let code: Int
        switch error {
        case GenerationFailure.http(let status): code = status
        case GenerationFailure.keychain(let status): code = Int(status)
        default: code = (error as NSError).code
        }
        DiagnosticLog.shared.write(.generationFailed, level: .warning, operationID: operationID, fields: .init(stage: stage, systemCode: code))
    }
    private func configureAPIKey() {
        let alert = NSAlert(); alert.messageText = "DeepSeek API key"
        alert.informativeText = "保存到本机 Keychain。读取链接和整理时，对应内容会发送给 DeepSeek。"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 26))
        field.placeholderString = "API key"; field.setAccessibilityLabel("DeepSeek API key"); alert.accessoryView = field
        alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue; field.stringValue = ""
        root.editor?.configureButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try DeepSeekKeychain.save(key) }
            DispatchQueue.main.async {
                guard let self else { return }; self.root.editor?.configureButton.isEnabled = true
                switch result {
                case .success:
                    self.root.requiredLabel.stringValue = "API key 已保存到 Keychain。"
                    self.root.experienceView?.status.stringValue = "API key 已保存到 Keychain。"
                case .failure(let error):
                    self.root.requiredLabel.stringValue = error.localizedDescription
                    self.experience?.show(error)
                    let code: Int
                    if case GenerationFailure.keychain(let status) = error { code = Int(status) } else { code = (error as NSError).code }
                    DiagnosticLog.shared.write(.credentialFailed, level: .warning, fields: .init(stage: "keychain-save", systemCode: code))
                }
            }
        }
    }
    private func leaveEditor() { showLibrary(category: selectedCategory) }
    func saveEditor() {
        if let experience, root.page == .experience { root.experienceView?.stashEditor(); experience.save(); return }
        if let experience, reviewID != nil { stashReview(); experience.save(); return }
        guard !isSaving, let editor = root.editor else { return }
        cancelGeneration()
        guard editor.validateFields() else {
            DiagnosticLog.shared.write(.storageFailed, level: .warning, fields: .init(stage: "form-validation", errorCode: "required-fields")); return
        }
        draftWork?.cancel(); isSaving = true; setSaving(true); root.statusLabel.stringValue = "正在保存…"
        library.saveDraft(editor.draft) { [weak self] result in
            guard let self else { return }; self.isSaving = false; self.setSaving(false)
            switch result {
            case .success(let saved):
                editor.markSaved(saved); self.selectedEntry = saved; self.root.editor = nil; self.root.page = .library
                if !editor.inlineMode { self.selectedCategory = nil }
                self.root.libraryView.presentation = .detail; self.refreshLibrary(); self.updateSidebar()
                self.root.footer.stringValue = "已保存"
            case .failure(let error):
                self.root.statusLabel.stringValue = "保存失败"; self.root.requiredLabel.stringValue = error.localizedDescription
                self.root.requiredLabel.textColor = Theme.error; self.persistDraft(updateStatus: false)
            }
            let finish = self.afterSave; self.afterSave = nil; finish?()
        }
    }
    func showStatistics() {
        guard !isSaving else { return }
        if experience != nil { finishExperience { [weak self] in self?.showStatistics() }; return }
        cancelGeneration()
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
        if let experience {
            root.experienceView?.stashEditor(); stashReview()
            Task { do { try await experience.finish(); completion(true) } catch { self.root.footer.stringValue = "草稿保存失败，输入已保留。"; completion(false) } }
            return
        }
        cancelGeneration()
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
        root.libraryView.navigationEnabled = !saving; root.backButton.isEnabled = !saving
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        prepareForTermination { [weak self] success in if success { self?.window?.orderOut(nil) } }
        return false
    }
}

extension ManagementWindowController {
    func newExperience() {
        guard !isSaving, experience?.saving != true else { return }
        navigationGeneration += 1; let generation = navigationGeneration
        // Existing manually edited drafts retain their original editor and conflict protection.
        library.editorDraft { [weak self] result in
            guard let self, self.navigationGeneration == generation else { return }
            switch result {
            case .failure(let error): self.root.footer.stringValue = error.localizedDescription
            case .success(let draft):
                if let draft { self.presentEditor(draft); return }
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let session = try await self.library.experienceDraft() ?? ExperienceSession()
                        guard self.navigationGeneration == generation else { return }
                        self.presentExperience(session)
                    } catch { self.root.footer.stringValue = "无法恢复会话草稿，请重试。" }
                }
            }
        }
    }
    func presentExperience(_ session: ExperienceSession) {
        cancelGeneration(); draftWork?.cancel(); reviewID = nil; root.editor = nil
        let controller = ExperienceController(session: session, library: library, service: experienceService)
        experience = controller
        controller.onSuggestion = { [weak self, weak controller] id, suggestion in
            guard let self, let controller, controller.current?.id == id,
                  let original = controller.current?.candidate, let window = self.window else { return }
            let alert = Self.comparisonAlert(current: original.prompt, proposed: suggestion.prompt)
            alert.beginSheetModal(for: window) { [weak controller] response in
                if response == .alertSecondButtonReturn { controller?.adoptSuggestion(id, suggestion) }
                else { controller?.keepCurrent(id) }
            }
        }
        controller.onChange = { [weak self, weak controller] in
            guard let self, let controller, self.experience === controller else { return }
            self.root.experienceView?.update(); self.setSaving(controller.saving)
            if self.root.page == .experience {
                self.root.title.stringValue = controller.session.items.isEmpty && self.root.experienceView?.completedCount == 0 ? (controller.isManualEntry ? "手动填写" : "新增经验") : "整理经验"
                self.root.subtitle.stringValue = controller.session.items.isEmpty ? "草稿自动保存在本机" : "\(controller.session.items.count) 条经验 · 本地草稿"
                self.root.saveButton.title = "保存已确认 \(controller.session.confirmed.count) 条"
                self.root.saveButton.isEnabled = !controller.busy && !controller.saving && !controller.session.confirmed.isEmpty
                self.root.needsLayout = true
            }
            self.root.requiredLabel.stringValue = controller.status
            if self.reviewID != nil { self.root.saveButton.title = "保存已确认 \(controller.session.confirmed.count) 条" }
        }
        controller.onReview = { [weak self] in self?.root.experienceView?.update() }
        controller.onSaved = { [weak self, weak controller] saved in
            guard let self, let controller else { return }
            self.root.editor = nil; self.reviewID = nil
            self.selectedEntry = saved.first
            if controller.session.items.isEmpty {
                self.root.experienceView?.showCompletion(saved.count)
                self.root.title.stringValue = "整理经验"; self.root.subtitle.stringValue = "0 条待整理经验"
                self.root.saveButton.title = "已保存"; self.root.saveButton.isEnabled = false
            }
            self.root.needsLayout = true
        }
        root.experienceView = ExperienceView(controller: controller, categories: counts)
        root.experienceView?.onConfigure = { [weak self] in self?.configureAPIKey() }
        root.experienceView?.onBack = { [weak self] in self?.leaveEditor() }
        root.page = .experience; root.title.stringValue = "新增经验"; root.needsLayout = true
        controller.onChange?()
    }
    private func stashReview() {
        guard let experience, let id = reviewID, let editor = root.editor else { return }
        let d = editor.draft, e = d.entry
        let value = GeneratedPrompt(title: e.title, summary: e.summary, explanation: e.explanation, prompt: e.prompt,
                                    categoryID: d.newCategoryName == nil ? e.categoryID : nil, newCategoryName: d.newCategoryName)
        if experience.session.items.first(where: { $0.id == id })?.candidate != value { experience.updateCandidate(id, value) }
        root.saveButton.title = "保存已确认 \(experience.session.confirmed.count) 条"
        root.editor?.nextButton.title = experience.reviewItems.last?.id == id ? "确认此条" : "确认并下一条"
        if let index = experience.reviewItems.firstIndex(where: { $0.id == id }) { editor.setReviewItems(experience.reviewItems, selected: index) }
    }
    func presentExperienceReview(index: Int) {
        guard experience?.saving != true else { return }
        stashReview()
        guard let experience, experience.reviewItems.indices.contains(index) else { return }
        let items = experience.reviewItems, item = items[index]
        do {
            let draft = try item.entry(source: experience.session.source)
            reviewID = item.id; presentEditor(draft, review: true); root.title.stringValue = "审核条目"
            root.editor?.setReviewPosition(index: index, total: items.count, title: item.title)
            root.editor?.setReviewItems(items, selected: index)
            root.editor?.onReviewSelect = { [weak self] id in
                guard let self, let index = self.experience?.reviewItems.firstIndex(where: { $0.id == id }) else { return }
                self.presentExperienceReview(index: index)
            }
            root.editor?.previousButton.onPress = { [weak self] in self?.presentExperienceReview(index: index - 1) }
            root.editor?.nextButton.onPress = { [weak self] in self?.confirmExperienceReview() }
        } catch { experience.show(error) }
    }
    func confirmExperienceReview() {
        guard let model = experience, let id = reviewID, let editor = root.editor, editor.validateFields() else { return }
        stashReview(); model.confirm(id)
        guard model.session.items.first(where: { $0.id == id })?.confirmed == true else { return }
        if let index = model.reviewItems.firstIndex(where: { $0.id == id }), index + 1 < model.reviewItems.count {
            presentExperienceReview(index: index + 1)
        } else {
            root.editor?.nextButton.title = "已确认"
            root.editor?.setReviewItems(model.reviewItems, selected: model.reviewItems.count - 1)
        }
        root.saveButton.title = "保存已确认 \(model.session.confirmed.count) 条"
    }
    private func backToExperience() {
        stashReview(); reviewID = nil; root.editor = nil; root.page = .experience
        root.title.stringValue = "新增经验"; root.experienceView?.update(); root.needsLayout = true
    }
    private func finishExperience(_ completion: @escaping () -> Void) {
        guard let experience, !experience.saving else { return }
        root.experienceView?.stashEditor(); stashReview()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await experience.finish()
                self.experience = nil; self.root.experienceView = nil; self.root.editor = nil; self.reviewID = nil; self.root.page = .library
                completion()
            } catch { experience.show(error) }
        }
    }
    func deleteSelected() {
        guard !isSaving, let original = selectedEntry else { return }
        guard confirmDeletion(original) else { return }
        isSaving = true; setSaving(true); root.libraryView.moreButton.isEnabled = false
        detailGeneration += 1; root.libraryView.copyButton.isEnabled = false; root.libraryView.editButton.isEnabled = false
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.library.deleteEntry(original)
                self.selectedEntry = nil; self.root.libraryView.setEntry(nil); self.root.footer.stringValue = "已删除「\(original.title)」"
            } catch { self.root.footer.stringValue = error.localizedDescription }
            self.isSaving = false; self.setSaving(false); self.refreshLibrary()
        }
    }
}
