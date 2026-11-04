import AppKit

private final class LibraryCollection: NSCollectionView {
    var activate: ((IndexPath) -> Void)?
    override func mouseDown(with event: NSEvent) {
        let path = indexPathForItem(at: convert(event.locationInWindow, from: nil))
        super.mouseDown(with: event)
        if let path { activate?(path) }
    }
    override func keyDown(with event: NSEvent) {
        if [36, 76].contains(event.keyCode), let path = selectionIndexPaths.first { activate?(path) }
        else { super.keyDown(with: event) }
    }
}

private final class CardSurface: SurfaceView {
    var onOpen: (() -> Void)?
    override func accessibilityPerformPress() -> Bool { onOpen?(); return onOpen != nil }
}

@MainActor final class ManagementCard: NSCollectionViewItem {
    let category = Theme.label(size: 12), heading = Theme.label(size: 17, weight: .medium)
    let summary = Theme.label(size: 13, color: Theme.secondary)
    let source = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    private let external = NSImageView()
    private var dot: CategoryDot?
    override func loadView() {
        view = CardSurface(color: Theme.shell, radius: 14)
        [category, heading, summary, source, external].forEach(view.addSubview)
        external.image = DesignAssets.image("ExternalLink")
        source.alignment = .left; source.font = .systemFont(ofSize: 13)
        heading.maximumNumberOfLines = 2; heading.cell?.wraps = true
        view.setAccessibilityRole(.button)
    }
    override var isSelected: Bool { didSet { view.layer?.borderColor = (isSelected ? Theme.accent : Theme.border).cgColor } }
    func set(_ item: ManagedSummary, categories: [PromptCategory]) {
        loadViewIfNeeded()
        category.stringValue = Theme.categoryName(item.summary.categoryID, in: categories)
        category.textColor = Theme.categoryColor(item.summary.categoryID, in: categories)
        heading.stringValue = item.summary.title; summary.stringValue = item.summary.summary
        view.setAccessibilityLabel(item.summary.title + "，" + item.summary.summary)
        view.toolTip = item.summary.title + "\n" + item.summary.summary
        dot?.removeFromSuperview()
        let next = CategoryDot(category: item.summary.categoryID, categories: categories); view.addSubview(next); dot = next
        SourceBadge.set(source, source: item.source); source.isHidden = item.source.isEmpty
        source.isEnabled = SourceLink.inSource(item.source) != nil
        external.isHidden = !source.isEnabled
        source.onPress = { if let url = SourceLink.inSource(item.source) { NSWorkspace.shared.open(url) } }
    }
    override func viewDidLayout() {
        super.viewDidLayout(); let w = view.bounds.width
        guard w > 40 else { return }
        dot?.frame = NSRect(x: 22, y: 25, width: 6, height: 6)
        category.frame = NSRect(x: 34, y: 16, width: w - 54, height: 24)
        let natural = heading.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: w - 40, height: 48)).height ?? 28
        heading.frame = NSRect(x: 20, y: 48, width: w - 40, height: min(48, max(28, ceil(natural))))
        summary.frame = NSRect(x: 20, y: heading.frame.maxY + 8, width: w - 40, height: 22)
        let sourceWidth = min(w - 64, ceil((source.title as NSString).size(withAttributes: [.font: source.font!]).width) + 32)
        source.frame = NSRect(x: 12, y: summary.frame.maxY + 8, width: sourceWidth, height: 28)
        external.frame = NSRect(x: source.frame.maxX + 4, y: source.frame.minY + 7, width: 14, height: 14)
    }
}

@MainActor final class ManagementGrid: FlippedView, NSCollectionViewDataSource {
    private let collection = LibraryCollection(), flow = NSCollectionViewFlowLayout()
    let scroll = NSScrollView()
    private let empty = Theme.label("没有匹配内容", size: 16, color: Theme.secondary)
    private(set) var items: [ManagedSummary] = []
    var categories: [PromptCategory] = [] { didSet { collection.reloadData() } }
    var onOpen: ((ManagedSummary) -> Void)?
    private(set) var columnCount = 3
    private var pendingScroll: CGFloat?
    override init(frame: NSRect) {
        super.init(frame: frame)
        flow.minimumInteritemSpacing = 16; flow.minimumLineSpacing = 16
        collection.collectionViewLayout = flow; collection.backgroundColors = [.clear]
        collection.isSelectable = true; collection.allowsEmptySelection = true; collection.dataSource = self
        collection.register(ManagementCard.self, forItemWithIdentifier: .init("prompt"))
        collection.activate = { [weak self] path in
            guard let self, self.items.indices.contains(path.item) else { return }
            self.onOpen?(self.items[path.item])
        }
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        scroll.documentView = collection; addSubview(scroll); addSubview(empty)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setItems(_ values: [ManagedSummary], selected: String?) {
        items = values; collection.reloadData(); empty.isHidden = !values.isEmpty
        if let index = values.firstIndex(where: { $0.summary.id == selected }) { collection.selectionIndexPaths = [IndexPath(item: index, section: 0)] }
        needsLayout = true
    }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: .init("prompt"), for: indexPath) as! ManagementCard
        let value = items[indexPath.item]
        item.set(value, categories: categories)
        (item.view as? CardSurface)?.onOpen = { [weak self] in self?.onOpen?(value) }
        return item
    }
    func focus() { window?.makeFirstResponder(collection) }
    func restoreScroll(_ y: CGFloat) { pendingScroll = y; needsLayout = true }
    override func layout() {
        super.layout(); scroll.frame = bounds; empty.frame = NSRect(x: 0, y: 40, width: bounds.width, height: 32)
        let width = max(200, scroll.contentSize.width)
        columnCount = width >= 1000 ? 3 : 2
        let size = NSSize(width: floor((width - CGFloat(columnCount - 1) * 16) / CGFloat(columnCount)), height: 178)
        if flow.itemSize != size { flow.itemSize = size }
        collection.setFrameSize(NSSize(width: width, height: max(bounds.height, CGFloat((items.count + columnCount - 1) / columnCount) * 194)))
        if let y = pendingScroll {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: min(max(0, y), max(0, collection.frame.height - scroll.contentSize.height))))
            scroll.reflectScrolledClipView(scroll.contentView); pendingScroll = nil
        }
    }
}
