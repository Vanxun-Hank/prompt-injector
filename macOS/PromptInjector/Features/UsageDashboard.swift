import AppKit

struct UsageRank {
    let id: String, title: String
    let copies: Int, insertions: Int
    let last: Date
    var total: Int { copies + insertions }
}

struct UsageSummary {
    let records: [UsageRecord]
    var total: Int { records.count }
    var copies: Int { records.filter { $0.kind == .copy }.count }
    var insertions: Int { total - copies }
    var promptCount: Int { Set(records.map(\.promptID)).count }
    var categoryCounts: [String: Int] { Dictionary(grouping: records, by: \.categoryID).mapValues(\.count) }
    var ranks: [UsageRank] {
        Dictionary(grouping: records, by: \.promptID).compactMap { id, values in
            guard let last = values.max(by: { $0.date < $1.date }) else { return nil }
            return UsageRank(id: id, title: last.title, copies: values.filter { $0.kind == .copy }.count, insertions: values.filter { $0.kind == .insert }.count, last: last.date)
        }.sorted { $0.total == $1.total ? $0.id < $1.id : $0.total > $1.total }
    }
}

final class UsageChart: FlippedView {
    var records: [UsageRecord] = [] { didSet { needsDisplay = true } }
    var start = Calendar.current.startOfDay(for: Date()) { didSet { needsDisplay = true } }
    var end = Date() { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let left: CGFloat = 36, right = bounds.width - 6, top: CGFloat = 20, baseline: CGFloat = 148
        let span = max(1, end.timeIntervalSince(start))
        let days = max(1, Int(ceil(span / 86400))), buckets = max(2, min(30, days))
        var series = Array(repeating: Array(repeating: 0.0, count: buckets), count: 5)
        for record in records {
            guard let cat = PromptCategory.all.firstIndex(where: { $0.id == record.categoryID }) else { continue }
            let index = min(buckets - 1, max(0, Int(record.date.timeIntervalSince(start) / span * Double(buckets))))
            series[cat][index] += 1
        }
        let peak = max(4, (0..<buckets).map { i in series.reduce(0) { $0 + $1[i] } }.max() ?? 4)
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: Theme.tertiary]
        for i in 0...3 {
            let y = baseline - CGFloat(i) / 3 * (baseline - top)
            Theme.border.setStroke(); let line = NSBezierPath(); line.move(to: NSPoint(x: left, y: y)); line.line(to: NSPoint(x: right, y: y)); line.lineWidth = 1; line.stroke()
            (String(Int(peak * Double(i) / 3)) as NSString).draw(at: NSPoint(x: 0, y: y - 6), withAttributes: attrs)
        }
        func points(_ values: [Double]) -> [NSPoint] { values.enumerated().map { NSPoint(x: left + CGFloat($0.offset) / CGFloat(max(1, buckets - 1)) * (right - left), y: baseline - CGFloat($0.element / peak) * (baseline - top)) } }
        func append(_ values: [NSPoint], to path: NSBezierPath, move: Bool) {
            guard let first = values.first else { return }; if move { path.move(to: first) } else { path.line(to: first) }
            for i in 1..<values.count {
                let a = values[i-1], b = values[i], middle = (a.x + b.x) / 2
                path.curve(to: b, controlPoint1: NSPoint(x: middle, y: a.y), controlPoint2: NSPoint(x: middle, y: b.y))
            }
        }
        var accumulated = Array(repeating: 0.0, count: buckets)
        for (i, category) in PromptCategory.all.enumerated() {
            let lower = points(accumulated)
            for j in 0..<buckets { accumulated[j] += series[i][j] }
            let upper = points(accumulated), area = NSBezierPath()
            append(upper, to: area, move: true); append(Array(lower.reversed()), to: area, move: false); area.close()
            Theme.categoryColor(category.id).withAlphaComponent(0.58).setFill(); area.fill()
            let line = NSBezierPath(); append(upper, to: line, move: true)
            Theme.categoryColor(category.id).withAlphaComponent(0.85).setStroke(); line.lineWidth = 1.2; line.stroke()
        }
        let formatter = DateFormatter(); formatter.dateFormat = days == 1 ? "HH:mm" : "MM.dd"
        for i in 0...5 {
            let date = start.addingTimeInterval(span * Double(i) / 5)
            let value = formatter.string(from: date) as NSString
            let x = left + CGFloat(i) / 5 * (right - left)
            value.draw(at: NSPoint(x: min(right - 28, x), y: 160), withAttributes: attrs)
        }
        let counts = UsageSummary(records: records).categoryCounts
        for (i, category) in PromptCategory.all.enumerated() {
            let x = left + CGFloat(i) * (right - left) / 5
            DesignAssets.image("Dot-" + category.id, template: false)?.draw(in: NSRect(x: x - 10, y: 184, width: 27, height: 27), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            ("\(category.name) · \(counts[category.id] ?? 0)" as NSString).draw(at: NSPoint(x: x + 12, y: 191), withAttributes: attrs)
        }
        if records.isEmpty {
            let empty = "还没有使用记录，复制或插入 Prompt 后显示趋势。" as NSString
            empty.draw(at: NSPoint(x: max(left, (bounds.width - empty.size(withAttributes: attrs).width) / 2), y: 82), withAttributes: attrs)
        }
    }
}

final class CategoryDistribution: FlippedView {
    var summary = UsageSummary(records: []) { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        for (i, category) in PromptCategory.all.enumerated() {
            let y = CGFloat(i) * 48
            DesignAssets.image("Dot-" + category.id, template: false)?.draw(in: NSRect(x: -10, y: y - 3, width: 27, height: 27), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let count = summary.categoryCounts[category.id] ?? 0
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: Theme.text]
            (category.name as NSString).draw(at: NSPoint(x: 15, y: y + 4), withAttributes: attrs)
            let value = String(format: "%d 次 · %.1f%%", count, Double(count) / Double(max(1, summary.total)) * 100) as NSString
            let secondary: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Theme.secondary]
            value.draw(at: NSPoint(x: bounds.width - value.size(withAttributes: secondary).width, y: y + 4), withAttributes: secondary)
            Theme.border.setFill(); NSBezierPath(roundedRect: NSRect(x: 0, y: y + 29, width: bounds.width, height: 4), xRadius: 2, yRadius: 2).fill()
            Theme.categoryColor(category.id).setFill(); NSBezierPath(roundedRect: NSRect(x: 0, y: y + 29, width: bounds.width * CGFloat(count) / CGFloat(max(1, summary.total)), height: 4), xRadius: 2, yRadius: 2).fill()
        }
    }
}

@MainActor final class UsageDashboard: FlippedView, NSTableViewDataSource, NSTableViewDelegate {
    private let library: PromptLibrary
    private let scroll = NSScrollView(), doc = FlippedView()
    private let heading = Theme.label("使用统计", size: 26, weight: .medium), dateLabel = Theme.label(size: 12, color: Theme.secondary)
    private let band = SurfaceView(color: Theme.band, radius: 16, border: nil)
    private let scope = Theme.label("本地记录", size: 12, color: Theme.hex(0xF5D975)), definition = Theme.label("成功复制或成功插入，各计一次", size: 12, color: Theme.secondary)
    let range = ChoiceSegments(["7 天", "30 天", "90 天", "全部"])
    private var cards: [(SurfaceView, NSTextField, NSTextField, NSTextField)] = []
    private let trend = SurfaceView(), ranksPanel = SurfaceView(), distributionPanel = SurfaceView()
    private let trendLabel = Theme.label("使用趋势", size: 16, weight: .medium), chart = UsageChart()
    private let trendUnit = Theme.label("按分类 · 次", size: 11, color: Theme.secondary)
    private let ranksLabel = Theme.label("Prompt 使用排行", size: 16, weight: .medium)
    private let rankCount = Theme.label(size: 11, color: Theme.tertiary)
    private let distributionLabel = Theme.label("分类分布", size: 16, weight: .medium), distributionHint = Theme.label("所选时段的使用次数占比", size: 11, color: Theme.tertiary)
    private let distribution = CategoryDistribution()
    let table = NSTableView(), tableScroll = NSScrollView()
    private let footer = Theme.label("使用次数 = 成功复制次数 + 成功插入次数", size: 11, color: Theme.tertiary)
    private var ranks: [UsageRank] = [], generation = 0
    private(set) var currentSummary = UsageSummary(records: [])
    var category: String? { didSet { reload() } }
    init(library: PromptLibrary) {
        self.library = library; super.init(frame: .zero)
        addSubview(scroll); scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay; scroll.documentView = doc
        scroll.automaticallyAdjustsContentInsets = false
        [heading, dateLabel, band, trend, ranksPanel, distributionPanel, footer].forEach(doc.addSubview)
        [scope, definition, range].forEach(band.addSubview)
        range.selectedIndex = 1; range.onSelect = { [weak self] _ in self?.reload() }
        for label in ["使用次数", "成功插入", "成功复制", "已使用 Prompt"] {
            let card = SurfaceView(), name = Theme.label(label, size: 12, color: Theme.secondary), value = Theme.label("0", size: 34, weight: .semibold), hint = Theme.label(size: 11, color: Theme.tertiary)
            doc.addSubview(card); [name, value, hint].forEach(card.addSubview); cards.append((card, name, value, hint))
        }
        [trendLabel, trendUnit, chart].forEach(trend.addSubview)
        [ranksLabel, rankCount, tableScroll].forEach(ranksPanel.addSubview)
        [distributionLabel, distributionHint, distribution].forEach(distributionPanel.addSubview)
        for (id, label, width) in [("title", "Prompt", CGFloat(390)), ("total", "使用", 65), ("insert", "插入", 65), ("copy", "复制", 65), ("last", "最近使用", 100)] {
            let col = NSTableColumn(identifier: .init(id)); col.title = label; col.width = width; table.addTableColumn(col)
        }
        table.rowHeight = 38; table.backgroundColor = .clear; table.style = .plain; table.dataSource = self; table.delegate = self; table.focusRingType = .none
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.intercellSpacing = .zero
        tableScroll.drawsBackground = false; tableScroll.hasVerticalScroller = true; tableScroll.scrollerStyle = .overlay; tableScroll.documentView = table
        NotificationCenter.default.addObserver(self, selector: #selector(usageChanged), name: .promptUsageChanged, object: library)
        reload()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func usageChanged() { reload() }
    func reload() {
        generation += 1; let token = generation, now = Date(), selectedCategory = category
        let days = [7, 30, 90, 0][range.selectedIndex]
        let start = days == 0 ? nil : Calendar.current.date(byAdding: .day, value: 1 - days, to: Calendar.current.startOfDay(for: now))
        library.usage(since: start) { [weak self] result in
            guard let self, self.generation == token else { return }
            switch result {
            case .failure(let error): self.footer.stringValue = error.localizedDescription
            case .success(let records):
                let filtered = records.filter { selectedCategory == nil || $0.categoryID == selectedCategory }
                let summary = UsageSummary(records: filtered)
                self.currentSummary = summary
                self.ranks = summary.ranks; self.table.reloadData(); self.distribution.summary = summary
                let from = start ?? filtered.first.map { Calendar.current.startOfDay(for: $0.date) } ?? Calendar.current.date(byAdding: .day, value: -29, to: now)!
                self.chart.start = from; self.chart.end = now; self.chart.records = filtered
                let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"
                self.dateLabel.stringValue = f.string(from: from) + " — " + f.string(from: now)
                self.heading.stringValue = selectedCategory.map { "使用统计 · " + Theme.categoryName($0) } ?? "使用统计"
                for (i, count) in [summary.total, summary.insertions, summary.copies, summary.promptCount].enumerated() { self.cards[i].2.stringValue = String(count) }
                let dayCount = max(1, Calendar.current.dateComponents([.day], from: from, to: now).day! + 1)
                self.cards[0].3.stringValue = String(format: "日均 %.1f 次", Double(summary.total) / Double(dayCount))
                self.cards[1].3.stringValue = String(format: "占全部使用的 %.1f%%", Double(summary.insertions) / Double(max(1, summary.total)) * 100)
                self.cards[2].3.stringValue = String(format: "占全部使用的 %.1f%%", Double(summary.copies) / Double(max(1, summary.total)) * 100)
                self.cards[3].3.stringValue = "共 \(summary.promptCount) 条 Prompt 有使用记录"
                self.rankCount.stringValue = "共 \(self.ranks.count) 条"
                self.footer.stringValue = self.library.lastUsageRecordingFailed
                    ? "复制／插入已完成，但最近一次使用记录未保存，请检查本地资料库。"
                    : "本地记录 · 使用次数 = 成功复制次数 + 成功插入次数"
            }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { ranks.count }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard ranks.indices.contains(row) else { return nil }; let rank = ranks[row], field = Theme.label(size: 12)
        switch tableColumn?.identifier.rawValue {
        case "total": field.stringValue = String(rank.total)
        case "insert": field.stringValue = String(rank.insertions)
        case "copy": field.stringValue = String(rank.copies)
        case "last": let f = DateFormatter(); f.dateFormat = "M月d日"; field.stringValue = f.string(from: rank.last)
        default: field.stringValue = "\(row + 1)  " + rank.title
        }
        field.toolTip = rank.title; return field
    }
    override func layout() {
        super.layout(); scroll.frame = bounds; let width = scroll.contentSize.width, main = width - 64
        doc.frame = NSRect(x: 0, y: 0, width: width, height: max(1100, bounds.height))
        heading.frame = NSRect(x: 32, y: 32, width: main, height: 36); dateLabel.frame = NSRect(x: 32, y: 70, width: main, height: 18)
        band.frame = NSRect(x: 32, y: 108, width: main, height: 64)
        scope.frame = NSRect(x: 28, y: 22, width: 80, height: 20); definition.frame = NSRect(x: 114, y: 22, width: max(200, main - 460), height: 20)
        range.frame = NSRect(x: main - 312, y: 12, width: 296, height: 40)
        let cardWidth = (main - 48) / 4
        for (i, card) in cards.enumerated() {
            card.0.frame = NSRect(x: 32 + CGFloat(i) * (cardWidth + 16), y: 192, width: cardWidth, height: 128)
            card.1.frame = NSRect(x: 20, y: 20, width: cardWidth - 40, height: 20)
            card.2.frame = NSRect(x: 20, y: 48, width: cardWidth - 40, height: 42); card.3.frame = NSRect(x: 20, y: 94, width: cardWidth - 40, height: 18)
        }
        trend.frame = NSRect(x: 32, y: 340, width: main, height: 300)
        trendLabel.frame = NSRect(x: 24, y: 24, width: 250, height: 24); trendUnit.frame = NSRect(x: main - 124, y: 28, width: 100, height: 18)
        chart.frame = NSRect(x: 24, y: 64, width: main - 48, height: 216)
        let dw = min(360, max(260, main * 0.31)), rw = main - dw - 20
        ranksPanel.frame = NSRect(x: 32, y: 660, width: rw, height: 368); distributionPanel.frame = NSRect(x: 52 + rw, y: 660, width: dw, height: 368)
        ranksLabel.frame = NSRect(x: 16, y: 20, width: rw - 90, height: 24); rankCount.frame = NSRect(x: rw - 70, y: 24, width: 54, height: 18)
        tableScroll.frame = NSRect(x: 16, y: 60, width: rw - 32, height: 292)
        for (column, columnWidth) in zip(table.tableColumns, [max(120, rw - 328), 65, 65, 65, 100]) { column.width = columnWidth }
        distributionLabel.frame = NSRect(x: 24, y: 24, width: dw - 48, height: 24); distributionHint.frame = NSRect(x: 24, y: 68, width: dw - 48, height: 18)
        distribution.frame = NSRect(x: 24, y: 100, width: dw - 48, height: 240); footer.frame = NSRect(x: 32, y: 1048, width: main, height: 20)
    }
}
