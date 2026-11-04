import AppKit

final class EditorText: SurfaceView {
    let scroll = NSScrollView(), text = NSTextView()
    var reservedBottom: CGFloat = 0
    init(_ value: String, label: String, size: CGFloat = 14) {
        super.init(color: Theme.shell, radius: 9)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        text.isRichText = false; text.drawsBackground = false; text.textColor = Theme.text
        text.allowsUndo = true
        text.insertionPointColor = Theme.text; text.font = .systemFont(ofSize: size)
        text.textContainerInset = NSSize(width: 12, height: 10); text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.widthTracksTextView = true; text.isHorizontallyResizable = false
        text.isVerticallyResizable = true; text.autoresizingMask = [.width]
        text.string = value; text.setAccessibilityLabel(label); text.focusRingType = .none
        text.minSize = .zero; text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let p = NSMutableParagraphStyle(); p.minimumLineHeight = size >= 15 ? 28 : 24; p.maximumLineHeight = p.minimumLineHeight
        text.defaultParagraphStyle = p
        text.typingAttributes = [.font: NSFont.systemFont(ofSize: size), .foregroundColor: Theme.text, .paragraphStyle: p]
        text.textStorage?.setAttributedString(NSAttributedString(string: value, attributes: text.typingAttributes))
        scroll.documentView = text; addSubview(scroll)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout(); scroll.frame = NSRect(x: 1, y: 1, width: max(1, bounds.width - 2), height: max(1, bounds.height - reservedBottom - 2))
        text.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(scroll.contentSize.height, text.frame.height)))
    }
}

@MainActor final class PromptEditorView: FlippedView, NSTextFieldDelegate, NSTextViewDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let reviewList = NSTableView(), reviewListScroll = NSScrollView()
    private var reviewItems: [ExperienceItem] = []
    var onReviewSelect: ((String) -> Void)?
    private var settingReviewSelection = false
    private var editingEnabled = true
    let reviewMode: Bool
    let previousButton = ActionButton(title: "上一条", symbol: nil, target: nil, action: nil)
    let nextButton = ActionButton(title: "下一条", symbol: nil, target: nil, action: nil)
    var onChange: (() -> Void)?
    private(set) var original: PromptEntry?
    let id: String
    private var category: String
    private var categories: [PromptCategory]
    var candidate: GeneratedPrompt? { candidateEditor.value }
    var onFailure: ((Error) -> Void)?
    let newCategoryField = NSTextField()
    private let newCategoryBox = SurfaceView(color: Theme.shell, radius: 9)
    private let newCategoryLabel = Theme.label("新分类名称", size: 12, color: Theme.secondary)
    let generateButton = ActionButton(title: "整理", symbol: "sparkles", primary: true, target: nil, action: nil)
    let configureButton = ActionButton(title: "", symbol: "key", target: nil, action: nil)
    let adoptButton = ActionButton(title: "采用候选", symbol: "checkmark", target: nil, action: nil)
    let candidateEditor = GeneratedPromptEditor()
    private var creatingCategory = false
    private(set) var categoryChooser: CategoryPopover?
    let info = SurfaceView(color: Theme.shell), content = SurfaceView(color: Theme.shell, border: Theme.hex(0x626262))
    private let infoScroll = NSScrollView(), infoBody = FlippedView()
    private let infoHeading = Theme.label("条目信息", size: 16, weight: .medium)
    let titleError = Theme.label(size: 11, color: Theme.error), categoryError = Theme.label(size: 11, color: Theme.error), promptError = Theme.label(size: 12, color: Theme.error)
    private let labels = ["标题 *", "分类", "简述", "来源"].map { Theme.label($0, size: 12, color: Theme.secondary) }
    let titleField = NSTextField(), sourceField = NSTextField()
    private let titleBox = SurfaceView(color: Theme.shell, radius: 9), sourceBox = SurfaceView(color: Theme.shell, radius: 9)
    let categoryButton = ActionButton(title: "", symbol: nil, target: nil, action: nil)
    private let categoryBox = SurfaceView(color: Theme.shell, radius: 9)
    private var dot: CategoryDot?
    private let categoryArrow = NSImageView()
    let summaryText: EditorText, promptText: EditorText, originalText: EditorText, explanationText: EditorText
    let segments: ChoiceSegments
    private let sourceIcon = NSImageView()
    let reviewOriginal = TextDocument(), reviewOriginalScroll = NSScrollView()
    private let contentRule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    private let promptLabel = Theme.label("Prompt *", size: 14, weight: .medium)
    private let originalLabel = Theme.label("原始经验", size: 14, weight: .medium)
    private let explanationLabel = Theme.label("解释", size: 14, weight: .medium)
    private let explanationRule = SurfaceView(color: Theme.border, radius: 0, border: nil)
    init(draft: EditorDraft, categories: [PromptCategory] = [], reviewMode: Bool = false) {
        self.reviewMode = reviewMode
        segments = ChoiceSegments(reviewMode ? ["Prompt", "作者原文", "整理说明"] : ["Prompt", "原始经验与解释", "整理候选"])
        self.categories = categories; creatingCategory = draft.newCategoryName != nil
        id = draft.entry.id; category = draft.entry.categoryID; original = draft.original
        summaryText = EditorText(draft.entry.summary, label: "简述", size: 13)
        promptText = EditorText(draft.entry.prompt, label: "完整 Prompt", size: 15)
        originalText = EditorText(draft.entry.originalExperience, label: "原始经验", size: 15)
        explanationText = EditorText(draft.entry.explanation, label: "解释", size: 15)
        super.init(frame: .zero)
        addSubview(info); addSubview(content); info.addSubview(infoScroll)
        infoScroll.drawsBackground = false; infoScroll.hasVerticalScroller = true; infoScroll.scrollerStyle = .overlay; infoScroll.documentView = infoBody
        [infoHeading, titleBox, categoryBox, summaryText, sourceBox, newCategoryLabel, newCategoryBox].forEach(infoBody.addSubview)
        labels.forEach(infoBody.addSubview)
        [titleError, categoryError].forEach(infoBody.addSubview); content.addSubview(promptError)
        [generateButton, configureButton].forEach(info.addSubview)
        [previousButton, nextButton].forEach(info.addSubview); sourceBox.addSubview(sourceIcon)
        for (field, box, label, value) in [(titleField, titleBox, "标题", draft.entry.title), (sourceField, sourceBox, "来源", draft.entry.source), (newCategoryField, newCategoryBox, "新分类名称", draft.newCategoryName ?? "")] {
            field.font = .systemFont(ofSize: 14); field.textColor = Theme.text; field.drawsBackground = false
            field.isBordered = false; field.focusRingType = .none; field.delegate = self
            field.stringValue = value; field.setAccessibilityLabel(label); box.addSubview(field)
        }
        categoryBox.addSubview(categoryButton); categoryButton.alignment = .left
        categoryArrow.image = DesignAssets.image("Down"); categoryBox.addSubview(categoryArrow)
        categoryButton.font = .systemFont(ofSize: 14); categoryButton.onPress = { [weak self] in self?.chooseCategory() }
        [candidateEditor, adoptButton, segments, contentRule, promptLabel, promptText, originalLabel, originalText, explanationLabel, explanationText, explanationRule].forEach(content.addSubview)
        content.addSubview(reviewOriginalScroll); reviewOriginalScroll.drawsBackground = false; reviewOriginalScroll.hasVerticalScroller = true
        reviewOriginalScroll.scrollerStyle = .overlay; reviewOriginalScroll.documentView = reviewOriginal
        reviewOriginal.set(Theme.body(draft.entry.originalExperience, size: 16, lineHeight: 32), width: 640)
        reviewOriginalScroll.isHidden = true
        for edit in [summaryText, promptText, originalText, explanationText] { edit.text.delegate = self }
        // The long content editors use the surrounding panel as their surface.
        for edit in [promptText, originalText, explanationText] { edit.layer?.borderWidth = 0; edit.layer?.backgroundColor = NSColor.clear.cgColor }
        segments.onSelect = { [weak self] _ in
            guard let self else { return }; PageTransition.fade(self.content, duration: 0.12); self.needsLayout = true
        }
        candidateEditor.setCategories(categories); candidateEditor.set(draft.candidate)
        candidateEditor.onChange = { [weak self] in self?.onChange?() }
        configureButton.toolTip = "配置 DeepSeek API key"; configureButton.setAccessibilityLabel("配置 DeepSeek API key")
        adoptButton.toolTip = "将候选填入标题、简述、解释、Prompt 和分类；保留原文与来源"
        adoptButton.onPress = { [weak self] in self?.adoptCandidate() }
        updateCategory(); showCandidate()
        if reviewMode {
            originalText.text.isEditable = false; sourceField.isEditable = false
            content.addSubview(nextButton)
            [labels[0], labels[1], labels[2], titleBox, categoryBox, summaryText, sourceBox, newCategoryLabel, newCategoryBox, titleError, categoryError].forEach(content.addSubview)
            info.addSubview(infoHeading); infoHeading.stringValue = "待保存条目"
            info.addSubview(reviewListScroll)
            reviewList.addTableColumn(NSTableColumn(identifier: .init("review"))); reviewList.headerView = nil
            reviewList.style = .plain; reviewList.backgroundColor = .clear; reviewList.rowHeight = 80
            reviewList.intercellSpacing = NSSize(width: 0, height: 4); reviewList.selectionHighlightStyle = .regular
            reviewList.dataSource = self; reviewList.delegate = self; reviewList.focusRingType = .none
            reviewListScroll.documentView = reviewList; reviewListScroll.drawsBackground = false
            reviewListScroll.hasVerticalScroller = true; reviewListScroll.scrollerStyle = .overlay
        }
        sourceField.maximumNumberOfLines = 1; sourceField.lineBreakMode = .byTruncatingTail; sourceField.cell?.wraps = false
        sourceField.toolTip = draft.entry.source; clearValidation()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var value: PromptEntry { .init(id: id, categoryID: category, title: titleField.stringValue, summary: summaryText.text.string, originalExperience: originalText.text.string, source: sourceField.stringValue, explanation: explanationText.text.string, prompt: promptText.text.string) }
    var draft: EditorDraft { EditorDraft(entry: value, original: original, newCategoryName: creatingCategory ? newCategoryField.stringValue : nil, candidate: candidate) }
    var hasChanges: Bool {
        if creatingCategory || candidate != nil { return true }
        if let original { return value != original }
        let value = value
        return [value.title, value.summary, value.originalExperience, value.source, value.explanation, value.prompt].contains { !$0.isEmpty }
    }
    func markSaved(_ entry: PromptEntry) { original = entry }
    func setEditingEnabled(_ enabled: Bool) {
        editingEnabled = enabled
        titleField.isEditable = enabled; sourceField.isEditable = enabled && !reviewMode; categoryButton.isEnabled = enabled; newCategoryField.isEditable = enabled
        generateButton.isEnabled = enabled; configureButton.isEnabled = enabled; adoptButton.isEnabled = enabled && candidate != nil; candidateEditor.setEditingEnabled(enabled)
        [summaryText, promptText, originalText, explanationText].forEach { $0.text.isEditable = enabled }
        if reviewMode { originalText.text.isEditable = false }
        previousButton.isEnabled = enabled && reviewIndex > 0; nextButton.isEnabled = enabled
    }
    func clearValidation() {
        [titleError, categoryError, promptError].forEach { $0.stringValue = ""; $0.isHidden = true }
        titleBox.layer?.borderColor = Theme.border.cgColor; categoryBox.layer?.borderColor = Theme.border.cgColor
        promptText.layer?.borderWidth = 0; needsLayout = true
    }
    @discardableResult func validateFields() -> Bool {
        clearValidation()
        if value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleError.stringValue = "请输入标题。"; titleError.isHidden = false; titleBox.layer?.borderColor = Theme.error.cgColor
            window?.makeFirstResponder(titleField); needsLayout = true; return false
        }
        if value.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.selectedIndex = 0; promptError.stringValue = "请填写 Prompt。"; promptError.isHidden = false
            promptText.layer?.borderColor = Theme.error.cgColor; promptText.layer?.borderWidth = 1
            window?.makeFirstResponder(promptText.text); needsLayout = true; return false
        }
        do {
            if creatingCategory { _ = try PromptCategory.normalizedName(newCategoryField.stringValue) }
            else if !categories.contains(where: { $0.id == category }) { throw LibraryFailure.invalidCategory }
        } catch {
            categoryError.stringValue = error.localizedDescription; categoryError.isHidden = false
            categoryBox.layer?.borderColor = Theme.error.cgColor; window?.makeFirstResponder(categoryButton); needsLayout = true; return false
        }
        return true
    }
    func controlTextDidChange(_ obj: Notification) { clearValidation(); needsLayout = true; onChange?() }
    func textDidChange(_ notification: Notification) { clearValidation(); onChange?() }
    private var reviewIndex = 0, reviewTotal = 0
    func setReviewPosition(index: Int, total: Int, title: String) {
        reviewIndex = index; reviewTotal = total; infoHeading.stringValue = reviewMode ? "待保存条目" : "\(index + 1) / \(total) · \(title)"
        previousButton.isEnabled = index > 0; nextButton.isEnabled = true
        nextButton.title = index + 1 < total ? "确认并下一条" : "确认此条"
    }
    func setReviewItems(_ items: [ExperienceItem], selected: Int) {
        reviewItems = items; settingReviewSelection = true; reviewList.reloadData()
        reviewList.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        reviewList.scrollRowToVisible(selected); settingReviewSelection = false
    }
    func numberOfRows(in tableView: NSTableView) -> Int { reviewItems.count }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PromptRow() }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { editingEnabled }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = reviewItems[row], cell = ManagementSummaryCell()
        cell.heading.stringValue = item.candidate?.title.isEmpty == false ? item.candidate!.title : item.title
        cell.summary.stringValue = (item.confirmed == true ? "已确认 · " : "待确认 · ") + (item.candidate?.summary ?? "")
        return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard editingEnabled, !settingReviewSelection, reviewItems.indices.contains(reviewList.selectedRow) else { return }
        onReviewSelect?(reviewItems[reviewList.selectedRow].id)
    }
    private func updateCategory() {
        categoryButton.title = creatingCategory ? (newCategoryField.stringValue + "（新）") : Theme.categoryName(category, in: categories)
        dot?.removeFromSuperview(); let next = CategoryDot(category: category, categories: categories); categoryBox.addSubview(next); dot = next
        needsLayout = true
    }
    private func chooseCategory() {
        let chooser = CategoryPopover(categories: categories, selected: creatingCategory ? "" : category) { [weak self] id, name in
            guard let self else { return }
            self.creatingCategory = name != nil
            if let id { self.category = id }
            self.newCategoryField.stringValue = name ?? ""
            self.clearValidation(); self.updateCategory(); self.onChange?()
        }
        categoryChooser = chooser; chooser.show(relativeTo: categoryBox)
        if creatingCategory { chooser.showCreate(name: newCategoryField.stringValue) }
    }
    @objc func addCategory() {
        chooseCategory(); categoryChooser?.showCreate(name: creatingCategory ? newCategoryField.stringValue : "")
    }
    func setCategories(_ values: [PromptCategory]) { categories = values; candidateEditor.setCategories(values); updateCategory(); showCandidate() }
    func receiveCandidate(_ value: GeneratedPrompt) {
        candidateEditor.set(value); segments.selectedIndex = 2; showCandidate(); onChange?()
    }
    private func showCandidate() {
        adoptButton.isEnabled = candidate != nil; needsLayout = true
    }
    func adoptCandidate() {
        guard let candidate, candidateEditor.validateFields() else { return }
        do { try candidate.validate(categories: categories) }
        catch { onFailure?(error); return }
        titleField.stringValue = candidate.title; summaryText.text.string = candidate.summary
        explanationText.text.string = candidate.explanation; promptText.text.string = candidate.prompt
        if let id = candidate.categoryID { category = id; creatingCategory = false }
        else { creatingCategory = true; newCategoryField.stringValue = candidate.newCategoryName ?? "" }
        // Undo stacks refer to the previous document; never replay them into an adopted candidate.
        [titleField, summaryText.text, explanationText.text, promptText.text, newCategoryField].forEach { $0.undoManager?.removeAllActions() }
        candidateEditor.set(nil); segments.selectedIndex = 0; updateCategory(); showCandidate()
        if creatingCategory { layoutSubtreeIfNeeded(); newCategoryBox.scrollToVisible(newCategoryBox.bounds) }
        DiagnosticLog.shared.write(.candidateAdopted, fields: .init(stage: "explicit-adoption")); onChange?()
    }
    override func layout() {
        super.layout(); let iw: CGFloat = bounds.width >= 1100 ? (reviewMode ? 352 : 380) : 320, cw = bounds.width - iw - 20, h = bounds.height
        info.frame = NSRect(x: 0, y: 0, width: iw, height: h); content.frame = NSRect(x: iw + 20, y: 0, width: cw, height: h)
        infoScroll.frame = NSRect(x: 1, y: 1, width: iw - 2, height: max(0, h - 80)); infoBody.frame = NSRect(x: 0, y: 0, width: iw - 2, height: max(h - 80, creatingCategory ? 566 : 478))
        infoHeading.frame = NSRect(x: 24, y: 24, width: iw - 48, height: 24)
        for (label, y) in zip(labels, [CGFloat(74), 162, 250, 386]) { label.frame = NSRect(x: 24, y: y, width: iw - 48, height: 18) }
        titleBox.frame = NSRect(x: 24, y: 98, width: iw - 48, height: 44)
        Theme.placeLine(titleField, in: NSRect(x: 12, y: 0, width: iw - 72, height: 44), stableBaseline: true)
        categoryBox.frame = NSRect(x: 24, y: 186, width: iw - 48, height: 44)
        dot?.frame = NSRect(x: 12, y: 18.5, width: 7, height: 7); categoryButton.frame = NSRect(x: 27, y: 5, width: iw - 88, height: 34)
        categoryArrow.frame = NSRect(x: iw - 76, y: 14, width: 16, height: 16)
        summaryText.frame = NSRect(x: 24, y: 274, width: iw - 48, height: 84)
        sourceBox.frame = NSRect(x: 24, y: 410, width: iw - 48, height: 44)
        let platform = SourceLink.platform(sourceField.stringValue)
        sourceIcon.image = platform.asset.flatMap { DesignAssets.image($0) } ?? NSImage(systemSymbolName: "link", accessibilityDescription: "来源")
        sourceIcon.frame = NSRect(x: 12, y: 14, width: 16, height: 16)
        Theme.placeLine(sourceField, in: NSRect(x: 40, y: 0, width: iw - 100, height: 44), stableBaseline: true)
        newCategoryLabel.isHidden = true; newCategoryBox.isHidden = true
        newCategoryLabel.frame = NSRect(x: 24, y: 474, width: iw - 48, height: 18)
        newCategoryBox.frame = NSRect(x: 24, y: 498, width: iw - 48, height: 44)
        Theme.placeLine(newCategoryField, in: NSRect(x: 12, y: 0, width: iw - 72, height: 44), stableBaseline: true)
        titleError.frame = NSRect(x: 24, y: 144, width: iw - 48, height: 16)
        categoryError.frame = NSRect(x: 24, y: 232, width: iw - 48, height: 16)
        let actionsY = h - 60
        generateButton.frame = NSRect(x: 24, y: actionsY, width: iw - 104, height: 40)
        configureButton.frame = NSRect(x: iw - 64, y: actionsY, width: 40, height: 40)
        generateButton.isHidden = reviewMode; configureButton.isHidden = reviewMode
        previousButton.isHidden = !reviewMode; nextButton.isHidden = !reviewMode
        previousButton.frame = NSRect(x: 24, y: actionsY, width: 96, height: 40)
        nextButton.frame = NSRect(x: iw - 120, y: actionsY, width: 96, height: 40)
        segments.frame = NSRect(x: 24, y: 24, width: min(400, cw - 48), height: 44); contentRule.frame = NSRect(x: 24, y: 84, width: cw - 48, height: 1)
        promptLabel.frame = NSRect(x: 24, y: 104, width: cw - 48, height: 24)
        promptText.frame = NSRect(x: 12, y: 136, width: cw - 24, height: max(120, h - 160))
        originalLabel.frame = promptLabel.frame
        let oh = max(120, min(180, (h - 228) * 0.4))
        originalText.frame = NSRect(x: 12, y: 136, width: cw - 24, height: oh)
        explanationRule.frame = NSRect(x: 24, y: originalText.frame.maxY + 12, width: cw - 48, height: 1)
        explanationLabel.frame = NSRect(x: 24, y: explanationRule.frame.maxY + 16, width: cw - 48, height: 24)
        explanationText.frame = NSRect(x: 12, y: explanationLabel.frame.maxY + 8, width: cw - 24, height: max(80, h - explanationLabel.frame.maxY - 32))
        adoptButton.frame = NSRect(x: cw - 148, y: 96, width: 124, height: 36)
        candidateEditor.frame = NSRect(x: 12, y: 144, width: cw - 24, height: max(120, h - 164))
        let reviewing = segments.selectedIndex == 2
        candidateEditor.isHidden = !reviewing; adoptButton.isHidden = !reviewing
        let prompt = segments.selectedIndex == 0
        [promptLabel, promptText].forEach { $0.isHidden = !prompt }
        [originalLabel, originalText, explanationRule, explanationLabel, explanationText].forEach { $0.isHidden = prompt || reviewing }
        if reviewMode {
            infoScroll.isHidden = true; previousButton.isHidden = true; nextButton.isHidden = false
            nextButton.frame = NSRect(x: cw - 184, y: h - 60, width: 160, height: 36)
            infoHeading.frame = NSRect(x: 24, y: 24, width: iw - 48, height: 24)
            reviewListScroll.frame = NSRect(x: 12, y: 64, width: iw - 24, height: h - 88)
            reviewList.tableColumns.first?.width = reviewListScroll.contentSize.width
            let categoryWidth: CGFloat = min(200, cw * 0.32), titleWidth = cw - categoryWidth - 64
            labels[0].frame = NSRect(x: 24, y: 24, width: titleWidth, height: 18)
            titleBox.frame = NSRect(x: 24, y: 48, width: titleWidth, height: 44)
            Theme.placeLine(titleField, in: NSRect(x: 12, y: 0, width: titleWidth - 24, height: 44), stableBaseline: true)
            labels[1].frame = NSRect(x: cw - categoryWidth - 24, y: 24, width: categoryWidth, height: 18)
            categoryBox.frame = NSRect(x: cw - categoryWidth - 24, y: 48, width: categoryWidth, height: 44)
            categoryButton.frame = NSRect(x: 27, y: 5, width: categoryWidth - 60, height: 34)
            categoryArrow.frame = NSRect(x: categoryWidth - 28, y: 14, width: 16, height: 16)
            titleError.frame = NSRect(x: 24, y: 94, width: titleWidth, height: 18)
            categoryError.frame = NSRect(x: cw - categoryWidth - 24, y: 94, width: categoryWidth, height: 18)
            labels[2].frame = NSRect(x: 24, y: 108, width: cw - 48, height: 18)
            summaryText.frame = NSRect(x: 24, y: 132, width: cw - 48, height: 44)
            newCategoryLabel.frame = NSRect(x: 24, y: 192, width: cw - 48, height: 18)
            newCategoryBox.frame = NSRect(x: 24, y: 216, width: cw - 48, height: 44)
            Theme.placeLine(newCategoryField, in: NSRect(x: 12, y: 0, width: cw - 72, height: 44), stableBaseline: true)
            let errorGap: CGFloat = titleError.isHidden && categoryError.isHidden ? 0 : 22
            labels[2].frame.origin.y += errorGap; summaryText.frame.origin.y += errorGap
            let tabY: CGFloat = 196 + errorGap
            segments.frame = NSRect(x: 24, y: tabY, width: min(400, cw - 48), height: 40)
            contentRule.frame = NSRect(x: 24, y: tabY + 56, width: cw - 48, height: 1)
            let textY = tabY + 76
            candidateEditor.isHidden = true; adoptButton.isHidden = true
            promptLabel.isHidden = true; originalLabel.isHidden = true; explanationLabel.isHidden = true; explanationRule.isHidden = true
            promptText.isHidden = segments.selectedIndex != 0; originalText.isHidden = true
            explanationText.isHidden = segments.selectedIndex != 2
            sourceBox.isHidden = segments.selectedIndex != 1 || sourceField.stringValue.isEmpty
            sourceBox.frame = NSRect(x: 24, y: textY, width: cw - 48, height: 36)
            sourceIcon.frame = NSRect(x: 12, y: 10, width: 16, height: 16)
            Theme.placeLine(sourceField, in: NSRect(x: 40, y: 0, width: cw - 100, height: 36), stableBaseline: true)
            reviewOriginalScroll.isHidden = segments.selectedIndex != 1
            let originalY = textY + (sourceBox.isHidden ? 0 : 52)
            reviewOriginalScroll.frame = NSRect(x: 32, y: originalY, width: min(640, cw - 64), height: max(80, h - originalY - 80))
            reviewOriginal.arrange(width: reviewOriginalScroll.contentSize.width)
            for field in [promptText, explanationText] { field.frame = NSRect(x: 20, y: textY, width: cw - 40, height: max(80, h - textY - 80)) }

        }
        if !promptError.isHidden {
            promptError.frame = NSRect(x: promptText.frame.minX + 12, y: promptText.frame.maxY - 18, width: promptText.frame.width - 24, height: 18)
            promptText.frame.size.height -= 24
        }
    }
}
