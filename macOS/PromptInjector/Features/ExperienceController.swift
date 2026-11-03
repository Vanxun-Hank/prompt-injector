import Foundation

@MainActor final class ExperienceController {
    private(set) var session: ExperienceSession
    private(set) var busy = false
    private(set) var saving = false
    private(set) var status = ""
    private(set) var failed = false
    var onChange: (() -> Void)?
    var onReview: (() -> Void)?
    var onSaved: (([PromptEntry]) -> Void)?
    var confirmReplacement: () -> Bool = { false }
    private let library: PromptLibrary
    private let service: ExperienceServing
    private var operationID: UUID?
    private var task: Task<Void, Never>?
    private var autosave: Task<Void, Never>?

    init(session: ExperienceSession, library: PromptLibrary, service: ExperienceServing) {
        var restored = session
        for i in restored.items.indices {
            for j in restored.items[i].messages.indices where restored.items[i].messages[j].delivery == .pending {
                restored.items[i].messages[j].delivery = .failed
            }
        }
        if restored != session { restored.revision += 1 }
        self.session = restored; self.library = library; self.service = service
    }
    deinit { task?.cancel(); autosave?.cancel() }
    var current: ExperienceItem? { session.current }
    var reviewItems: [ExperienceItem] { session.selected }
    func changeInput(_ value: String) {
        guard !saving else { return }
        if let i = session.items.firstIndex(where: { $0.id == session.currentID }) { session.items[i].input = value }
        else {
            if session.input != value {
                if session.source == SourceLink.url(session.input)?.absoluteString { session.source = "" }
                session.raw = ""
            }
            session.input = value
        }
        changed(notify: false)
    }
    func changeSource(_ value: String) { guard !saving, session.items.isEmpty else { return }; session.source = value; changed(notify: false) }
    func toggle(_ id: String) {
        guard !saving, let i = session.items.firstIndex(where: { $0.id == id }) else { return }
        session.items[i].selected.toggle(); changed()
    }
    func choose(_ id: String) {
        guard !saving, session.items.contains(where: { $0.id == id }) else { return }
        if session.currentID != id { cancel() }
        session.currentID = id; changed()
    }
    func send() { guard !busy, !saving, session.items.isEmpty else { return }; identify() }
    func beginManual() {
        guard !busy, !saving, session.items.isEmpty else { return }
        session.manualPrompt = session.manualPrompt ?? ""; changed()
    }
    func changePrompt(_ text: String) {
        guard !saving else { return }
        let wasBusy = busy; cancel()
        if let i = session.items.firstIndex(where: { $0.id == session.currentID }) {
            let c = session.items[i].candidate
            session.items[i].candidate = GeneratedPrompt(title: c?.title ?? session.items[i].title, summary: c?.summary ?? "",
                explanation: c?.explanation ?? "", prompt: text, categoryID: c?.categoryID, newCategoryName: c?.newCategoryName)
        } else { session.manualPrompt = text }
        status = ""; failed = false; changed(notify: wasBusy)
    }
    func continueManual() {
        guard !busy, !saving, session.items.isEmpty else { return }
        guard !session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.emptyExperience); return }
        guard session.input.count <= 60_000, (session.manualPrompt?.count ?? 0) <= 32_000 else { show(GenerationFailure.tooLong); return }
        guard let prompt = session.manualPrompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.emptyPrompt); return }
        session.raw = session.input
        let item = ExperienceItem(title: "新条目", original: session.input, selected: true,
            candidate: GeneratedPrompt(title: "", summary: "", explanation: "", prompt: prompt, categoryID: nil, newCategoryName: nil))
        session.items = [item]; session.currentID = item.id; changed(); onReview?()
    }
    private func identify() {
        let input = session.input
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.emptyExperience); return }
        guard input.count <= 60_000 else { show(GenerationFailure.tooLong); return }
        run(stage: "experience-identify") { [weak self] token in
            guard let self else { return }
            guard self.session.input == input else { self.discard(token); return }
            let raw: String
            if let url = SourceLink.url(input) {
                if self.session.source.isEmpty { self.session.source = input.trimmingCharacters(in: .whitespacesAndNewlines); self.changed() }
                raw = self.session.raw.isEmpty ? try await self.service.fetch(url) : self.session.raw
            } else { raw = input }
            guard self.valid(token), self.session.input == input else { self.discard(token); return }
            self.session.raw = raw; self.changed(); try await self.persist()
            let items = try await self.service.identify(raw)
            guard self.valid(token), self.session.input == input, self.session.raw == raw else { self.discard(token); return }
            self.session.items = items; self.session.currentID = items.first?.id
            self.status = ""; self.changed()
            if items.count == 1 {
                self.session.items[0].selected = true; self.changed()
                try await self.generate(items[0], token: token)
                if self.valid(token) { self.onReview?() }
            }
        }
    }
    func organize() {
        guard !busy, !saving else { return }
        guard !session.selected.isEmpty else { show(GenerationFailure.nothingSelected); return }
        guard session.selected.allSatisfy({ !($0.candidate?.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }) else {
            show(GenerationFailure.emptyPrompt); return
        }
        status = ""; failed = false; onReview?()
    }
    func generateCurrent() {
        guard !busy, !saving, let item = current else { return }
        if let prompt = item.candidate?.prompt, !prompt.isEmpty, !confirmReplacement() { return }
        run(stage: "experience-organize") { [weak self] token in
            guard let self else { return }
            try await self.generate(item, token: token)
        }
    }
    private func generate(_ item: ExperienceItem, token: UUID) async throws {
        let categories: [PromptCategory] = try await withCheckedThrowingContinuation { continuation in
            library.load(.categories) { result in
                if case .success(.categories(let values)) = result { continuation.resume(returning: values) }
                else if case .failure(let error) = result { continuation.resume(throwing: error) }
                else { continuation.resume(throwing: LibraryFailure.invalidCategory) }
            }
        }
        guard valid(token) else { return }
        let value = try await service.organize(item, source: session.source, context: session.raw, categories: categories)
        try value.validate(categories: categories)
        guard valid(token), let index = session.items.firstIndex(where: { $0.id == item.id }),
              session.items[index].candidate == item.candidate else { discard(token); return }
        session.items[index].candidate = value; session.items[index].generatedMessageCount = item.messages.count
        changed(); try await persist()
    }
    func updateCandidate(_ id: String, _ value: GeneratedPrompt) {
        guard !saving, let i = session.items.firstIndex(where: { $0.id == id }) else { return }
        cancel(); session.items[i].candidate = value; changed(notify: false)
    }
    private func run(stage: String, work: @escaping (UUID) async throws -> Void) {
        let token = UUID(); operationID = token; busy = true; failed = false; status = stage == "experience-organize" ? "正在整理…" : "正在处理…"; onChange?()
        DiagnosticLog.shared.write(.generationStarted, operationID: token, fields: .init(stage: stage))
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.persist()
                guard self.valid(token) else { return }
                try await work(token)
                guard self.valid(token) else { return }
                self.busy = false; self.operationID = nil; self.task = nil; self.status = ""; self.onChange?()
                DiagnosticLog.shared.write(.generationFinished, operationID: token, fields: .init(stage: stage))
            } catch {
                guard self.valid(token) else { self.discard(token); return }
                self.busy = false; self.operationID = nil; self.task = nil; self.failPending(); self.show(error)
                DiagnosticLog.shared.write(.generationFailed, level: .warning, operationID: token, fields: .init(stage: stage, systemCode: (error as NSError).code))
                try? await self.persist()
            }
        }
    }
    private func valid(_ token: UUID) -> Bool { operationID == token && !Task.isCancelled }
    private func discard(_ token: UUID) {
        DiagnosticLog.shared.write(.generationDiscarded, operationID: token, fields: .init(stage: "experience-stale-response"))
        if operationID == token { cancel() }
    }
    private func failPending() {
        for i in session.items.indices {
            for j in session.items[i].messages.indices where session.items[i].messages[j].delivery == .pending { session.items[i].messages[j].delivery = .failed }
        }
        changed(notify: false)
    }
    func cancel() {
        guard let token = operationID else { return }
        operationID = nil; task?.cancel(); task = nil; busy = false; status = "已取消，输入已保留。"; failed = false
        failPending(); onChange?()
        DiagnosticLog.shared.write(.generationCancelled, operationID: token, fields: .init(stage: "experience-cancelled"))
    }
    private func changed(notify: Bool = true) {
        session.revision += 1
        autosave?.cancel()
        autosave = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000); try Task.checkCancellation(); try await self?.persist() }
            catch is CancellationError { }
            catch { self?.show(error) }
        }
        if notify { onChange?() }
    }
    func persist() async throws {
        autosave?.cancel(); autosave = nil
        let snapshot = session
        try await library.storeExperienceDraft(snapshot)
    }
    func save() {
        guard !busy, !saving else { return }
        saving = true; failed = false; status = "正在保存…"; onChange?()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.persist()
                let snapshot = self.session
                let saved = try await self.library.saveExperiences(snapshot)
                self.session = snapshot.remaining; self.saving = false; self.task = nil; self.status = "已保存"; self.onChange?(); self.onSaved?(saved)
            } catch { self.saving = false; self.task = nil; self.show(error) }
        }
    }
    func finish() async throws {
        cancel()
        // Wait for the repository transaction before allowing window/app termination.
        if saving { await task?.value }
        saving = true; onChange?()
        defer { saving = false; onChange?() }
        if !session.items.isEmpty || !session.input.isEmpty || !session.source.isEmpty || session.manualPrompt != nil { try await persist() }
    }
    func show(_ error: Error) {
        DiagnosticLog.shared.write(.generationFailed, level: .warning, fields: .init(stage: "experience-feedback", systemCode: (error as NSError).code))
        failed = true
        if let error = error as? URLError {
            status = error.code == .timedOut ? "请求超时，输入已保留，请重试。" : "网络连接失败，输入已保留，请重试。"
        } else if let error = error as? GenerationFailure { status = error.localizedDescription }
        else if let error = error as? LibraryFailure { status = error.localizedDescription }
        else { status = "处理失败，输入已保留，请重试。" }
        onChange?()
    }
}
