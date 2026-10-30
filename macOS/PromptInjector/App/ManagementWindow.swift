import AppKit

private final class FormDocument: NSView {
    override var isFlipped: Bool { true }
}

@MainActor final class ManagementWindowController: NSWindowController {
    let library: PromptLibrary
    let category = NSPopUpButton()
    let titleField = NSTextField()
    let summaryField = NSTextField()
    let originalExperience = NSTextView()
    let source = NSTextView()
    let explanation = NSTextView()
    let prompt = NSTextView()
    let titleError = Theme.label(size: 12, color: Theme.error)
    let promptError = Theme.label(size: 12, color: Theme.error)
    let feedback = Theme.label(size: 12, color: Theme.secondary)
    lazy var saveButton = NSButton(title: "保存", target: self, action: #selector(save))
    lazy var newButton = NSButton(title: "继续新增", target: self, action: #selector(newEntry))
    private(set) var entryID = UUID().uuidString
    private(set) var isSaving = false
    private(set) var isSaved = false

    init(library: PromptLibrary) {
        self.library = library
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "管理内容 · Prompt Injector"
        window.identifier = .init("PromptInjector.Management")
        window.minSize = NSSize(width: 480, height: 400)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
        buildForm()
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        DiagnosticLog.shared.write(.managementOpened)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    var entry: PromptEntry {
        let index = category.indexOfSelectedItem
        return .init(id: entryID, categoryID: PromptCategory.all.indices.contains(index) ? PromptCategory.all[index].id : "",
              title: titleField.stringValue, summary: summaryField.stringValue,
              originalExperience: originalExperience.string, source: source.string,
              explanation: explanation.string, prompt: prompt.string)
    }

    @objc func save() {
        guard !isSaving, !isSaved else {
            DiagnosticLog.shared.write(.managementSave, fields: .init(stage: "ignored", result: isSaving ? "saving" : "saved"))
            return
        }
        let operationID = UUID()
        titleError.isHidden = !titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        promptError.isHidden = !prompt.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard titleError.isHidden && promptError.isHidden else {
            DiagnosticLog.shared.write(.managementSave, level: .warning, operationID: operationID, fields: .init(stage: "validation", result: "requiredField"))
            let field: NSView = titleError.isHidden ? prompt : titleField
            field.scrollToVisible(field.bounds)
            window?.makeFirstResponder(field)
            announce("请填写标题和 Prompt。", error: true)
            return
        }
        let value = entry
        isSaving = true
        updateControls()
        announce("正在保存…", error: false)
        DiagnosticLog.shared.write(.managementSave, operationID: operationID, fields: .init(stage: "started"))
        library.create(value, operationID: operationID) { [self] result in
            isSaving = false
            switch result {
            case .success:
                isSaved = true
                announce("已保存，可在浮窗中使用。", error: false)
                DiagnosticLog.shared.write(.managementSave, operationID: operationID, fields: .init(stage: "completed"))
            case .failure(let error):
                announce((error as? LibraryFailure)?.errorDescription ?? "保存失败，内容已保留，请重试。", error: true)
                DiagnosticLog.shared.write(.managementSave, level: .error, operationID: operationID, fields: .init(stage: "failed"))
            }
            updateControls()
        }
    }

    @objc func newEntry() {
        guard isSaved, !isSaving else {
            DiagnosticLog.shared.write(.managementSave, fields: .init(stage: "newIgnored"))
            return
        }
        entryID = UUID().uuidString
        isSaved = false
        titleField.stringValue = ""; summaryField.stringValue = ""
        [originalExperience, source, explanation, prompt].forEach { $0.string = ""; $0.undoManager?.removeAllActions() }
        titleError.isHidden = true; promptError.isHidden = true
        feedback.stringValue = ""
        updateControls()
        titleField.scrollToVisible(titleField.bounds)
        window?.makeFirstResponder(titleField)
    }

    private func updateControls() {
        let editable = !isSaving && !isSaved
        category.isEnabled = editable
        [titleField, summaryField].forEach { $0.isEditable = editable }
        [originalExperience, source, explanation, prompt].forEach { $0.isEditable = editable }
        saveButton.isEnabled = editable
        saveButton.title = isSaving ? "保存中…" : isSaved ? "已保存" : "保存"
        newButton.isEnabled = isSaved
    }

    private func announce(_ message: String, error: Bool) {
        feedback.stringValue = message
        feedback.textColor = error ? Theme.error : Theme.secondary
        NSAccessibility.post(element: feedback, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    private func buildForm() {
        guard let root = window?.contentView else { return }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let document = FormDocument()
        scroll.documentView = document
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        document.addSubview(stack)
        let heading = Theme.label("新增内容", size: 20, weight: .semibold)
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(Theme.label("标题与 Prompt 为必填", size: 12, color: Theme.secondary))
        category.addItems(withTitles: PromptCategory.all.map(\.name))
        category.setAccessibilityLabel("分类")
        addField("分类", control: category, to: stack)
        for (name, field) in [("标题", titleField), ("简述", summaryField)] {
            field.font = .systemFont(ofSize: 14)
            field.setAccessibilityLabel(name)
            addField(name, control: field, error: name == "标题" ? titleError : nil, to: stack)
        }
        titleError.stringValue = "请填写标题。"; promptError.stringValue = "请填写 Prompt。"
        titleError.isHidden = true; promptError.isHidden = true
        for (name, editor, height) in [("原始经验", originalExperience, 110.0), ("来源", source, 54.0), ("解释", explanation, 90.0), ("Prompt", prompt, 180.0)] {
            let editorScroll = NSScrollView()
            editorScroll.hasVerticalScroller = true; editorScroll.borderType = .bezelBorder
            editor.font = .systemFont(ofSize: 14)
            editor.isRichText = false; editor.allowsUndo = true
            editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false; editor.isAutomaticSpellingCorrectionEnabled = false
            editor.isHorizontallyResizable = false; editor.isVerticallyResizable = true
            editor.autoresizingMask = [.width]
            editor.textContainer?.widthTracksTextView = true
            editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            editor.textContainerInset = NSSize(width: 8, height: 8)
            editor.setAccessibilityLabel(name)
            editorScroll.documentView = editor
            editorScroll.heightAnchor.constraint(equalToConstant: height).isActive = true
            addField(name, control: editorScroll, error: name == "Prompt" ? promptError : nil, to: stack)
        }
        feedback.maximumNumberOfLines = 2; feedback.lineBreakMode = .byWordWrapping
        [saveButton, newButton].forEach { $0.bezelStyle = .rounded }
        saveButton.keyEquivalent = "s"; saveButton.keyEquivalentModifierMask = [.command]
        [scroll, feedback, saveButton, newButton].forEach { root.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        [document, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor), scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24), stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24), stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
            saveButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24), saveButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20), saveButton.widthAnchor.constraint(equalToConstant: 84),
            newButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12), newButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            newButton.widthAnchor.constraint(equalToConstant: 96),
            feedback.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24), feedback.trailingAnchor.constraint(equalTo: newButton.leadingAnchor, constant: -16), feedback.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])
        updateControls()
    }

    private func addField(_ title: String, control: NSView, error: NSTextField? = nil, to stack: NSStackView) {
        let group = NSStackView()
        group.orientation = .vertical; group.alignment = .leading; group.spacing = 6
        group.addArrangedSubview(Theme.label(title, size: 12, weight: .medium, color: Theme.secondary))
        group.addArrangedSubview(control)
        if let error { group.addArrangedSubview(error) }
        stack.addArrangedSubview(group)
        [group, control].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        group.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        control.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
    }
}
