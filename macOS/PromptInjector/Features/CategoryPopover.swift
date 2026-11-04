import AppKit

private final class CategoryMenuTable: NSTableView {
    var choose: (() -> Void)?
    var dismiss: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: choose?()
        case 53: dismiss?()
        default: super.keyDown(with: event)
        }
    }
}

@MainActor final class CategoryPopover: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSPopoverDelegate {
    private let categories: [PromptCategory]
    private let selected: String
    private let onSelect: (String?, String?) -> Void
    let popover = NSPopover()
    private let table = CategoryMenuTable(), scroll = NSScrollView()
    let newButton = ActionButton(title: "＋ 新建分类", symbol: nil, target: nil, action: nil)
    let nameField = NSTextField(), errorLabel = Theme.label(size: 12, color: Theme.error)
    let cancelButton = ActionButton(title: "取消", symbol: nil, target: nil, action: nil)
    let createButton = ActionButton(title: "创建并使用", primary: true, target: nil, action: nil)
    private let nameBox = SurfaceView(color: Theme.shell, radius: 9)
    private let heading = Theme.label("新建分类", size: 14, weight: .medium)
    private var creating = false
    init(categories: [PromptCategory], selected: String, onSelect: @escaping (String?, String?) -> Void) {
        self.categories = categories; self.selected = selected; self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        view = SurfaceView(color: Theme.panel, radius: 12, border: nil)
        [scroll, newButton, heading, nameBox, errorLabel, cancelButton, createButton].forEach(view.addSubview)
        nameBox.addSubview(nameField)
        table.addTableColumn(NSTableColumn(identifier: .init("category"))); table.headerView = nil
        table.style = .plain; table.backgroundColor = .clear; table.rowHeight = 34; table.intercellSpacing = NSSize(width: 0, height: 2)
        table.dataSource = self; table.delegate = self; table.focusRingType = .none
        table.target = self; table.action = #selector(chooseCurrent)
        table.choose = { [weak self] in self?.chooseCurrent() }; table.dismiss = { [weak self] in self?.popover.performClose(nil) }
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay; scroll.documentView = table
        nameField.font = .systemFont(ofSize: 14); nameField.textColor = Theme.text
        nameField.drawsBackground = false; nameField.isBordered = false; nameField.focusRingType = .none; nameField.delegate = self
        nameField.setAccessibilityLabel("新分类名称")
        nameField.placeholderAttributedString = NSAttributedString(string: "分类名称", attributes: [.foregroundColor: Theme.tertiary])
        cancelButton.outlined = true
        newButton.onPress = { [weak self] in self?.showCreate() }
        cancelButton.onPress = { [weak self] in self?.showList() }
        createButton.onPress = { [weak self] in self?.create() }
        popover.delegate = self; popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        showList()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func show(relativeTo control: NSView) {
        guard control.window != nil else {
            DiagnosticLog.shared.write(.generationDiscarded, fields: .init(stage: "category-unattached")); return
        }
        popover.contentViewController = self
        popover.show(relativeTo: control.bounds, of: control, preferredEdge: .maxY)
        view.window?.makeFirstResponder(creating ? nameField : table)
    }
    func popoverDidClose(_ notification: Notification) { popover.contentViewController = nil }
    private func showList() {
        creating = false; errorLabel.stringValue = ""
        let height = min(328, CGFloat(categories.count) * 36 + 64)
        popover.contentSize = NSSize(width: 304, height: height); view.setFrameSize(popover.contentSize)
        [heading, nameBox, errorLabel, cancelButton, createButton].forEach { $0.isHidden = true }
        scroll.isHidden = false; newButton.isHidden = false
        scroll.frame = NSRect(x: 8, y: 8, width: 288, height: height - 60)
        table.tableColumns.first?.width = 288
        newButton.frame = NSRect(x: 12, y: height - 48, width: 280, height: 36)
        table.reloadData()
        if let index = categories.firstIndex(where: { $0.id == selected }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false); table.scrollRowToVisible(index)
        }
        view.window?.makeFirstResponder(table)
    }
    func showCreate(name: String = "") {
        creating = true; nameField.stringValue = name; errorLabel.stringValue = ""
        scroll.isHidden = true; newButton.isHidden = true
        [heading, nameBox, errorLabel, cancelButton, createButton].forEach { $0.isHidden = false }
        popover.contentSize = NSSize(width: 304, height: 184); view.setFrameSize(popover.contentSize)
        heading.frame = NSRect(x: 16, y: 12, width: 272, height: 24)
        nameBox.frame = NSRect(x: 16, y: 46, width: 272, height: 40)
        Theme.placeLine(nameField, in: NSRect(x: 12, y: 0, width: 248, height: 40), stableBaseline: true)
        errorLabel.frame = NSRect(x: 16, y: 92, width: 272, height: 28)
        cancelButton.frame = NSRect(x: 16, y: 132, width: 96, height: 36)
        createButton.frame = NSRect(x: 124, y: 132, width: 164, height: 36)
        view.window?.makeFirstResponder(nameField)
    }
    func create() {
        do {
            let name = try PromptCategory.normalizedName(nameField.stringValue)
            if let existing = categories.first(where: { PromptCategory.nameKey($0.name) == PromptCategory.nameKey(name) }) {
                onSelect(existing.id, nil)
            } else { onSelect(nil, name) }
            popover.performClose(nil)
        } catch {
            errorLabel.stringValue = error.localizedDescription; nameBox.layer?.borderColor = Theme.error.cgColor
            view.window?.makeFirstResponder(nameField)
            DiagnosticLog.shared.write(.generationFailed, level: .warning, fields: .init(stage: "category-name-validation"))
        }
    }
    @objc private func chooseCurrent() {
        guard categories.indices.contains(table.selectedRow) else { return }
        onSelect(categories[table.selectedRow].id, nil); popover.performClose(nil)
    }
    func controlTextDidChange(_ obj: Notification) { errorLabel.stringValue = ""; nameBox.layer?.borderColor = Theme.border.cgColor }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { create(); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { popover.performClose(nil); return true }
        return false
    }
    func numberOfRows(in tableView: NSTableView) -> Int { categories.count }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let category = categories[row], cell = NSTableCellView()
        let image = NSImageView(frame: NSRect(x: 10, y: 3, width: 27, height: 27))
        image.image = DesignAssets.categoryDot(category.id, in: categories); cell.addSubview(image)
        let label = Theme.label(category.name, size: 13); label.frame = NSRect(x: 42, y: 5, width: 210, height: 24); cell.addSubview(label)
        if category.id == selected {
            let check = NSImageView(frame: NSRect(x: 260, y: 9, width: 16, height: 16)); check.image = DesignAssets.image("Check"); cell.addSubview(check)
        }
        return cell
    }
}
