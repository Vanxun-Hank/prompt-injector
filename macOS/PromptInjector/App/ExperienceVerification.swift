import AppKit

// Explicit verification modes use fixtures and temporary repositories, never the user's library.
struct ExperienceFixtureService: ExperienceServing {
    static let raw = "对于 Agent 必须遵守的规则，用脚本检查并真实运行。\n开始写代码前，先说明改动位置、影响范围和预期结果。"
    func fetch(_ url: URL) async throws -> String { Self.raw }
    func identify(_ text: String) async throws -> [ExperienceItem] {
        [.init(title: "用脚本验证规则", original: "对于 Agent 必须遵守的规则，用脚本检查并真实运行。"),
         .init(title: "动手前说明改动", original: "开始写代码前，先说明改动位置、影响范围和预期结果。")]
    }
    func discuss(_ item: ExperienceItem, source: String, context: String) async throws -> String {
        if item.messages.count > 1 { return "只有能明确判定通过或失败的规则，才适合脚本检查。\n\n开放的产品判断，仍然需要人来判断。" }
        return "Prompt 负责提醒，脚本负责检查。\n\nAgent 可能忽略文字规则。脚本能用实际运行结果判断是否达标。"
    }
    func organize(_ item: ExperienceItem, source: String, context: String, categories: [PromptCategory]) async throws -> GeneratedPrompt {
        .init(title: item.title, summary: "有可校验的硬性规则时使用", explanation: "原文方法\n保留方法和条件。\n\n讨论补充\n可明确校验的要求适合脚本检查。", prompt: item.original, categoryID: nil, newCategoryName: "学习与整理")
    }
}

extension AppDelegate {
    @MainActor func verifyExperiences(output: String) async -> [[String: Any]] {
        var checks: [[String: Any]] = []
        func check(_ name: String, _ pass: Bool) { checks.append(["name": name, "passed": pass]) }
        func until(_ condition: () -> Bool) async {
            for _ in 0..<300 { if condition() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
            check("experience/async-timeout", false)
        }
        guard CommandLine.arguments.contains("--verify-ui"), let parent = verificationDatabaseDirectory else { return [] }
        let url = parent.appendingPathComponent("experience/library.sqlite3"), repository = SQLitePromptRepository(url: url)
        let library = PromptLibrary(repository: repository)
        let manager = ManagementWindowController(library: library, experienceService: ExperienceFixtureService())
        guard let window = manager.window else { return [["name": "experience/window", "passed": false]] }
        manager.show(); window.setContentSize(NSSize(width: 1440, height: 960))
        func capture(_ name: String, target: NSWindow? = nil) async {
            let window = target ?? window
            if let screen = NSScreen.screens.first(where: { $0.visibleFrame.width >= window.frame.width && $0.visibleFrame.height >= window.frame.height }) {
                let area = screen.visibleFrame
                window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
                check("capture-placement/" + name, area.contains(window.frame))
            }
            window.contentView?.layoutSubtreeIfNeeded(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            window.displayIfNeeded()
            var captured = false, attempts = 0
            // Newly created WindowServer surfaces can reject the first capture; retry only the image, never the checks.
            for attempt in 1...3 {
                attempts = attempt
                try? await Task.sleep(nanoseconds: 180_000_000)
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                p.arguments = ["-x", "-o", "-l", String(window.windowNumber), output + "/" + name + ".png"]
                do { try p.run(); p.waitUntilExit(); captured = p.terminationStatus == 0 } catch { captured = false }
                if captured { break }
            }
            checks.append(["name": "capture/" + name, "passed": captured, "attempts": attempts,
                           "frame": NSStringFromRect(window.frame), "visible": window.isVisible,
                           "activeSpace": window.isOnActiveSpace, "windowNumber": window.windowNumber])
        }
        manager.root.newButton.performClick(nil)
        await until { manager.root.experienceView != nil }
        guard let model = manager.experience, let view = manager.root.experienceView else { return checks }
        await capture("experience-new")
        view.send.performClick(nil)
        check("v7/input-validation-near-field", !view.inputError.isHidden && window.firstResponder === view.input.text && !model.busy)
        await capture("experience-input-error")
        view.input.text.string = ExperienceFixtureService.raw; view.textDidChange(Notification(name: NSText.didChangeNotification, object: view.input.text))
        view.sourceField.stringValue = "https://x.com/HiTw93/status/2115366100221501540"; view.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        view.send.performClick(nil); await until { !model.busy && model.session.items.count == 2 }
        check("experience/identified-exact-original", model.session.items.map(\.original).joined(separator: "\n") == ExperienceFixtureService.raw)
        let first = model.session.items[0].id
        (view.table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? ExperienceRowCell)?.discuss.performClick(nil)
        model.changePrompt("用户粘贴的 Prompt"); model.choose(model.session.items[1].id)
        model.generateCurrent(); await until { !model.busy && model.current?.candidate != nil }
        model.choose(first)
        check("experience/selection-preserves-prompt-without-chat", model.current?.candidate?.prompt == "用户粘贴的 Prompt" && model.session.items.allSatisfy { $0.messages.isEmpty })
        (view.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? ExperienceRowCell)?.checkbox.performClick(nil)
        check("experience/checkbox-does-not-discuss", model.current?.id == first && model.session.items[1].selected && model.current?.messages.isEmpty == true)
        await capture("experience-organize")
        window.setContentSize(NSSize(width: 1100, height: 720)); window.contentView?.layoutSubtreeIfNeeded()
        check("experience/prompt-and-original-fit-minimum", (view.editor?.promptText.frame.height ?? 0) >= 150 && (view.editor?.frame.maxX ?? 0) <= view.bounds.width)
        check("experience/fixed-input-minimum", view.bounds.contains(view.organize.frame) && view.bounds.contains(view.generate.frame))
        await capture("experience-minimum")
        try? await model.finish()
        let resumed = try? repository.experienceDraft()
        check("experience/reopen-independent-prompts", resumed?.items[0].candidate?.prompt == "用户粘贴的 Prompt" && resumed?.items[1].candidate != nil)
        model.changePrompt(""); model.toggle(first)
        model.confirm(first)
        check("experience/empty-prompt-blocks-review", model.failed && model.session.confirmed.isEmpty && model.reviewItems.contains { $0.id == first })
        model.changePrompt("用户粘贴的 Prompt"); view.update()
        window.setContentSize(NSSize(width: 1440, height: 960)); window.contentView?.layoutSubtreeIfNeeded()
        guard let editor = view.editor else { check("experience/review-open", false); window.orderOut(nil); return checks }
        check("experience/review-source-readonly", !editor.originalText.text.isEditable && !editor.sourceField.isEditable)
        check("experience/confirm-action-visible", !view.organize.isHidden && view.bounds.contains(view.organize.frame))
        check("v7/unified-workbench", manager.root.page == .experience && manager.root.editor == nil && editor.workbenchMode)
        editor.titleField.stringValue = "审核后的短标题"; editor.summaryText.text.string = "有硬性规则时使用"; editor.explanationText.text.string = "保留方法与条件"
        editor.addCategory(); editor.categoryChooser?.nameField.stringValue = "学习与整理"; editor.categoryChooser?.createButton.performClick(nil)
        editor.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        await capture("experience-review")
        view.choose(model.session.items[1].id)
        check("experience/audit-list-stashes-edits", view.editor !== editor)
        view.choose(first)
        guard let editor = view.editor else { check("experience/audit-list-return", false); return checks }
        check("experience/audit-list-restores-edits", editor.titleField.stringValue == "审核后的短标题")
        window.setContentSize(NSSize(width: 1100, height: 720)); window.contentView?.layoutSubtreeIfNeeded()
        check("experience/audit-fields-fit-minimum", editor.workbenchMode && editor.promptText.frame.height >= 150 && view.bounds.contains(view.listScroll.convert(view.listScroll.bounds, to: view)))
        await capture("experience-review-minimum")
        window.setContentSize(NSSize(width: 1440, height: 960)); window.contentView?.layoutSubtreeIfNeeded()
        editor.originalToggle.performClick(nil); await capture("experience-original")
        check("experience/review-original-verbatim", editor.originalText.text.string == model.session.items[0].original)
        let original = editor.reviewOriginal
        let glyphs = original.text.layoutManager.flatMap { manager in original.text.textContainer.map { manager.usedRect(for: $0) } } ?? .zero
        check("experience/original-visible", !editor.reviewOriginalScroll.isHidden && original.text.visibleRect.intersects(glyphs))
        view.confirmCurrent(); view.confirmCurrent(); manager.saveEditor()
        await until { !model.saving && view.completedCount == 2 }
        check("v7/all-saved-without-resurrected-input", model.session.items.isEmpty && view.editor == nil && !manager.root.saveButton.isEnabled)
        check("workbench/compact-completion", view.panel.isHidden && view.content.isHidden && !view.add.isHidden && view.backButton.title == "查看内容库")
        await capture("workbench-complete")
        let saved = try? repository.managedSummaries(category: nil, query: "审核后的短标题")
        check("experience/batch-saved-with-sixth-category", saved?.count == 1 && (try? repository.categories().count) == 6)
        check("experience/draft-not-resurrected-after-save", (try? repository.experienceDraft()) == nil)
        if let row = saved?.first, let entry = try? repository.entry(id: row.summary.id, category: row.summary.categoryID) {
            let launcher = LauncherWindowController(library: library)
            launcher.launcher.navigate(to: .detail(entry.categoryID, entry.id), animate: false)
            await until { launcher.launcher.currentEntry?.id == entry.id }
            check("experience/saved-immediately-loads-in-launcher", launcher.launcher.currentEntry?.prompt == entry.prompt)
            launcher.window?.orderOut(nil)
            view.backButton.performClick(nil); await until { manager.root.page == .library && manager.root.libraryView.items.contains { $0.summary.id == entry.id } }
            manager.root.libraryView.openItem(id: entry.id); await until { manager.selectedEntry?.id == entry.id }
            check("v7/saved-card-immediately-available", manager.selectedEntry == entry)
            manager.confirmDeletion = { _ in false }; manager.root.libraryView.deleteButton.performClick(nil)
            check("experience/delete-cancel-keeps-entry", (try? repository.entry(id: entry.id, category: entry.categoryID)) != nil)
            manager.confirmDeletion = { _ in true }; manager.root.libraryView.deleteButton.performClick(nil); await until { !manager.isSaving }
            check("experience/deleted-entry-no-longer-loads", (try? repository.entry(id: entry.id, category: entry.categoryID)) == nil)
        }
        manager.presentExperience(ExperienceSession())
        if let manualView = manager.root.experienceView, let manualModel = manager.experience {
            manualView.manual.performClick(nil)
            manualView.input.text.string = "手动录入的作者原文"; manualView.textDidChange(Notification(name: NSText.didChangeNotification, object: manualView.input.text))
            manualView.prompt.text.string = "自己粘贴的明确指令"; manualView.textDidChange(Notification(name: NSText.didChangeNotification, object: manualView.prompt.text))
            window.setContentSize(NSSize(width: 1440, height: 960)); await capture("experience-manual")
            window.setContentSize(NSSize(width: 1100, height: 720)); await capture("experience-manual-minimum")
            check("experience/manual-pair-fit", manualView.input.frame.maxX < manualView.prompt.frame.minX && manualView.prompt.frame.maxX <= manualView.content.bounds.width && manualView.prompt.frame.height >= 200)
            manualView.automatic.performClick(nil)
            check("v7/input-mode-retains-prompt", !manualModel.isManualEntry && manualModel.session.manualPrompt == "自己粘贴的明确指令")
            manualView.manual.performClick(nil)
            manualView.send.performClick(nil)
            check("experience/manual-paste-skips-generation", manager.root.experienceView?.editor?.promptText.text.string == "自己粘贴的明确指令" && manualModel.current?.original == "手动录入的作者原文" && !manualModel.busy)
            let old = manualModel.current
            manualView.add.performClick(nil)
            manualView.input.text.string = ExperienceFixtureService.raw
            manualView.textDidChange(Notification(name: NSText.didChangeNotification, object: manualView.input.text))
            manualView.sourceField.stringValue = "https://github.com/example/second"; manualView.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
            await capture("workbench-addition-minimum")
            check("workbench/add-keeps-list-and-focus", manualView.showingInput && !manualView.panel.isHidden && manualView.editor?.isHidden == true && window.firstResponder === manualView.input.text)
            if let old { manualView.choose(old.id) }
            check("workbench/view-existing-while-adding", !manualView.showingInput && manualView.editor?.promptText.text.string == "自己粘贴的明确指令")
            manualView.add.performClick(nil); manualView.send.performClick(nil)
            await until { !manualModel.busy && manualModel.session.items.count == 3 }
            check("workbench/append-source-visible", manualModel.session.items.first == old && manualView.editor?.sourceField.stringValue == "https://github.com/example/second")
            let currentID = manualModel.current?.id
            if let action = manualView.removalMenu(row: 2)?.items.first, let selector = action.action { NSApp.sendAction(selector, to: action.target, from: action) }
            check("workbench/context-remove-keeps-current", manualModel.current?.id == currentID && manualView.selectedCount.stringValue == "已勾选 1 / 2")
            if let old { manualView.choose(old.id) }
            manualView.editor?.removeExperience.performClick(nil)
            await until { window.attachedSheet != nil }
            if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .alertFirstButtonReturn) }
            await until { window.attachedSheet == nil }
            check("workbench/edited-removal-cancel-keeps-draft", manualModel.current?.id == old?.id && manualModel.session.items.count == 2)
            manualView.editor?.removeExperience.performClick(nil)
            await until { window.attachedSheet != nil }
            if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .alertSecondButtonReturn) }
            await until { manualModel.session.items.count == 1 }
            check("workbench/removal-selects-adjacent", manualModel.current?.id == currentID && manualView.editor?.id == currentID)
            manualView.editor?.removeExperience.performClick(nil)
            check("workbench/remove-last-empties-detail", manualModel.current == nil && manualView.editor == nil && manualView.panel.isHidden && !manualView.add.isHidden)
            manualView.add.performClick(nil)
            check("workbench/continue-from-empty", manualView.showingInput && manager.root.page == .experience && manualView.input.text.string.isEmpty)
            try? await manualModel.finish()
        }
        for count in [1, 5, 20] {
            let dir = parent.appendingPathComponent("v7-\(count)/library.sqlite3")
            let repo = SQLitePromptRepository(url: dir), local = PromptLibrary(repository: repo)
            let form = ManagementWindowController(library: local, experienceService: ExperienceFixtureService())
            form.show(); form.window?.setContentSize(NSSize(width: 1440, height: 960))
            await until { form.root.categoryItems.count == 5 }
            var session = ExperienceSession(); session.raw = (0..<count).map { "作者原文\($0)。" }.joined(separator: "\n")
            session.input = session.raw; session.source = "https://x.com/author/status/1"
            session.items = (0..<count).map { i in .init(title: "经验\(i)", original: "作者原文\(i)。", candidate: .init(title: "验证经验\(i)", summary: "符合原文条件时", explanation: "保留方法与适用条件。", prompt: "执行第\(i)条明确指令。", categoryID: "coding", newCategoryName: nil)) }
            session.currentID = session.items[0].id; form.presentExperience(session)
            guard let workspace = form.root.experienceView, let model = form.experience else { check("v7/workspace-\(count)", false); continue }
            workspace.confirmCurrent(); form.root.saveButton.performClick(nil)
            await until { !model.saving }
            check("v7/partial-save-\(count)", model.session.items.count == count - 1 && workspace.selectedCount.stringValue == "已勾选 0 / \(count - 1)")
            if count > 1 {
                check("v7/remaining-draft-\(count)", (try? repo.experienceDraft()?.items.count) == count - 1 && workspace.editor?.id == session.items[1].id)
            } else { check("v7/completed-one", workspace.completedCount == 1 && (try? repo.experienceDraft()) == nil) }
            await capture("v7-partial-\(count)", target: form.window)
            if count == 1 {
                workspace.add.performClick(nil)
                check("workbench/continue-after-save", workspace.showingInput && form.root.page == .experience && workspace.input.text.string.isEmpty && workspace.status.stringValue.isEmpty)
            } else if count == 5 {
                model.remove(session.items[1].id)
                check("workbench/removed-clears-old-save-count", workspace.status.stringValue.isEmpty && workspace.selectedCount.stringValue == "已勾选 0 / 3")
            }
            try? await model.finish(); form.window?.orderOut(nil)
        }
        await withCheckedContinuation { continuation in library.flush { continuation.resume() } }
        window.orderOut(nil)
        return checks
    }

    @MainActor func runExperienceVerification() {
        Task {
            let args = CommandLine.arguments
            guard let index = args.firstIndex(of: "--verify-experience"), args.count > index + 1 else { exit(1) }
            let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            var stage = "prepare", fetchVerified = false
            var sample = ExperienceFixtureService.raw, source = "本项目公开验证样本（两条），不写正式库"
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let repository = SQLitePromptRepository(url: directory.appendingPathComponent("library.sqlite3")), library = PromptLibrary(repository: repository)
                let service = DeepSeekClient()
                if let i = args.firstIndex(of: "--source-url"), args.count > i + 1 {
                    guard let url = SourceLink.url(args[i + 1]) else { throw GenerationFailure.fetchUnavailable }
                    stage = "fetch"; sample = try await service.fetch(url); source = url.absoluteString; fetchVerified = true
                }
                var session = ExperienceSession(); session.raw = sample; session.input = session.raw; session.source = source
                stage = "draft"; try await library.storeExperienceDraft(session)
                stage = "identify"; session.items = try await service.identify(session.raw); session.currentID = session.items.first?.id; session.revision += 1
                guard !session.items.isEmpty else { throw GenerationFailure.invalidOutput }
                for i in session.items.indices.prefix(2) {
                    stage = "organize"; session.items[i].candidate = try await service.organize(session.items[i], source: session.source, context: session.raw, categories: repository.categories())
                    guard let candidate = session.items[i].candidate else { throw GenerationFailure.invalidOutput }
                    session.items[i].candidate = GeneratedPrompt(title: candidate.title + "（验证编辑）", summary: candidate.summary, explanation: candidate.explanation, prompt: candidate.prompt, categoryID: candidate.categoryID, newCategoryName: candidate.newCategoryName)
                    session.items[i].selected = true; session.items[i].confirmed = true; session.revision += 1
                    try await library.storeExperienceDraft(session)
                }
                stage = "save"; let saved = try await library.saveExperiences(session)
                stage = "reopen"; let reopened = SQLitePromptRepository(url: directory.appendingPathComponent("library.sqlite3"))
                for (item, entry) in zip(session.selected, saved) {
                    guard try reopened.entry(id: entry.id, category: entry.categoryID) == entry, entry.originalExperience == item.original,
                          entry.source == session.source, entry.title.hasSuffix("（验证编辑）") else { throw LibraryFailure.conflict }
                }
                let report: [String: Any] = ["passed": true, "realAPI": true, "realMultiRound": false, "fetchVerified": fetchVerified, "itemCount": saved.count, "identifiedCount": session.items.count,
                    "buildID": BuildIdentity.current.buildID, "sourceFingerprint": BuildIdentity.current.sourceFingerprint,
                    "formalLibraryChanged": false, "realCodexInsertion": false]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
                print("Real experience identification, organization, candidate edit, save and reopen passed.")
                DiagnosticLog.shared.flush(); NSApp.terminate(nil)
            } catch {
                let report: [String: Any] = ["passed": false, "stage": stage, "systemCode": (error as NSError).code, "realAPI": true, "fetchVerified": fetchVerified, "formalLibraryChanged": false]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) { try? data.write(to: directory.appendingPathComponent("report.json"), options: .atomic) }
                print("Experience verification failed at \(stage), code \((error as NSError).code).")
                DiagnosticLog.shared.flush(); exit(1)
            }
        }
    }
}
