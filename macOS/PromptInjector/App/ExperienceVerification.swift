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
        func capture(_ name: String) async {
            window.contentView?.layoutSubtreeIfNeeded(); window.makeKeyAndOrderFront(nil)
            try? await Task.sleep(nanoseconds: 180_000_000)
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(window.windowNumber), output + "/" + name + ".png"]
            do { try p.run(); p.waitUntilExit(); check("capture/" + name, p.terminationStatus == 0) }
            catch { check("capture/" + name, false) }
        }
        manager.root.newButton.performClick(nil)
        await until { manager.root.experienceView != nil }
        guard let model = manager.experience, let view = manager.root.experienceView else { return checks }
        view.input.text.string = ExperienceFixtureService.raw; view.textDidChange(Notification(name: NSText.didChangeNotification))
        view.sourceField.stringValue = "https://x.com/HiTw93/status/2115366100221501540"; view.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        view.send.performClick(nil); await until { !model.busy && model.session.items.count == 2 }
        check("experience/identified-exact-original", model.session.items.map(\.original).joined(separator: "\n") == ExperienceFixtureService.raw)
        let first = model.session.items[0].id, second = model.session.items[1].id
        (view.table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? ExperienceRowCell)?.discuss.performClick(nil); await until { !model.busy && model.current?.messages.count == 2 }
        model.changeInput("所有规则都要脚本化吗？"); model.send(); await until { !model.busy && model.current?.messages.count == 4 }
        (view.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? ExperienceRowCell)?.checkbox.performClick(nil)
        check("experience/checkbox-does-not-discuss", model.current?.id == first && model.session.items[1].selected && model.current?.messages.count == 4)
        check("experience/per-round-divider", view.bubbles.filter { !$0.divider.isHidden }.count == 2)
        await capture("experience-chat")
        window.setContentSize(NSSize(width: 1100, height: 720)); window.contentView?.layoutSubtreeIfNeeded()
        check("experience/equal-columns-minimum", abs(view.panel.frame.width - view.chatScroll.frame.width) < 1)
        check("experience/fixed-input-minimum", view.input.frame.maxY <= view.bounds.height && view.organize.frame.maxX <= view.panel.bounds.width)
        view.chatScroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, view.chatBody.frame.height - view.chatScroll.contentSize.height)))
        await capture("experience-minimum")
        model.changeInput("尚未发送的理解"); try? await model.finish()
        let resumed = (try? repository.experienceDraft())
        check("experience/reopen-discussion-and-input", resumed?.items[0].input == "尚未发送的理解" && resumed?.items[0].messages.count == 4)
        (view.table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? ExperienceRowCell)?.checkbox.performClick(nil); view.organize.performClick(nil); await until { !model.busy && manager.root.editor?.reviewMode == true }
        window.setContentSize(NSSize(width: 1440, height: 960)); window.contentView?.layoutSubtreeIfNeeded()
        guard let editor = manager.root.editor else { check("experience/review-open", false); window.orderOut(nil); return checks }
        check("experience/review-source-readonly", !editor.originalText.text.isEditable && !editor.sourceField.isEditable)
        editor.titleField.stringValue = "审核后的短标题"; editor.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        await capture("experience-review")
        editor.segments.selectedIndex = 1; editor.needsLayout = true; await capture("experience-original")
        check("experience/review-original-verbatim", editor.originalText.text.string == model.session.items[0].original)
        let original = editor.reviewOriginal
        let glyphs = original.text.layoutManager.flatMap { manager in original.text.textContainer.map { manager.usedRect(for: $0) } } ?? .zero
        checks.append(["name": "experience/original-visible", "passed": !editor.reviewOriginalScroll.isHidden && original.text.visibleRect.intersects(glyphs),
                       "textFrame": NSStringFromRect(original.text.frame), "visibleRect": NSStringFromRect(original.text.visibleRect),
                       "glyphRect": NSStringFromRect(glyphs), "clipBounds": NSStringFromRect(editor.reviewOriginalScroll.contentView.bounds)])
        manager.saveEditor(); await until { manager.experience == nil && manager.selectedEntry != nil }
        let saved = try? repository.managedSummaries(category: nil, query: "审核后的短标题")
        check("experience/batch-saved-with-sixth-category", saved?.count == 1 && (try? repository.categories().count) == 6)
        check("experience/draft-not-resurrected-after-save", (try? repository.experienceDraft()) == nil)
        if let row = saved?.first, let entry = try? repository.entry(id: row.summary.id, category: row.summary.categoryID) {
            let launcher = LauncherWindowController(library: library)
            launcher.launcher.navigate(to: .detail(entry.categoryID, entry.id), animate: false)
            await until { launcher.launcher.currentEntry?.id == entry.id }
            check("experience/saved-immediately-loads-in-launcher", launcher.launcher.currentEntry?.prompt == entry.prompt)
            launcher.window?.orderOut(nil)
            manager.confirmDeletion = { _ in false }; manager.root.libraryView.deleteButton.performClick(nil)
            check("experience/delete-cancel-keeps-entry", (try? repository.entry(id: entry.id, category: entry.categoryID)) != nil)
            manager.confirmDeletion = { _ in true }; manager.root.libraryView.deleteButton.performClick(nil); await until { !manager.isSaving }
            check("experience/deleted-entry-no-longer-loads", (try? repository.entry(id: entry.id, category: entry.categoryID)) == nil)
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
                    session.items[i].messages.append(.init(role: .user, content: "请用短句解释方法和适用条件。"))
                    session.revision += 1; try await library.storeExperienceDraft(session)
                    stage = "discuss"; let answer = try await service.discuss(session.items[i], source: session.source, context: session.raw)
                    session.items[i].messages.append(.init(role: .assistant, content: answer))
                    session.revision += 1; try await library.storeExperienceDraft(session)
                    if i == 0 {
                        session.items[i].messages.append(.init(role: .user, content: "请再说明哪些情况不适用；原文没写清的地方请明确说明。"))
                        session.revision += 1; try await library.storeExperienceDraft(session)
                        let followup = try await service.discuss(session.items[i], source: session.source, context: session.raw)
                        session.items[i].messages.append(.init(role: .assistant, content: followup)); session.revision += 1
                        try await library.storeExperienceDraft(session)
                    }
                    stage = "organize"; session.items[i].candidate = try await service.organize(session.items[i], source: session.source, context: session.raw, categories: repository.categories())
                    guard let candidate = session.items[i].candidate else { throw GenerationFailure.invalidOutput }
                    session.items[i].candidate = GeneratedPrompt(title: candidate.title + "（验证编辑）", summary: candidate.summary, explanation: candidate.explanation, prompt: candidate.prompt, categoryID: candidate.categoryID, newCategoryName: candidate.newCategoryName)
                    session.items[i].selected = true; session.revision += 1
                    try await library.storeExperienceDraft(session)
                }
                stage = "save"; let saved = try await library.saveExperiences(session)
                stage = "reopen"; let reopened = SQLitePromptRepository(url: directory.appendingPathComponent("library.sqlite3"))
                for (item, entry) in zip(session.selected, saved) {
                    guard try reopened.entry(id: entry.id, category: entry.categoryID) == entry, entry.originalExperience == item.original,
                          entry.source == session.source, entry.title.hasSuffix("（验证编辑）") else { throw LibraryFailure.conflict }
                }
                let report: [String: Any] = ["passed": true, "realAPI": true, "realMultiRound": true, "fetchVerified": fetchVerified, "itemCount": saved.count, "identifiedCount": session.items.count,
                    "buildID": BuildIdentity.current.buildID, "sourceFingerprint": BuildIdentity.current.sourceFingerprint,
                    "formalLibraryChanged": false, "realCodexInsertion": false]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
                print("Real experience identification, discussion, candidate edit, save and reopen passed.")
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
