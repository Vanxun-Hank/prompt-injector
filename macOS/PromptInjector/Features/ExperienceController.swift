import Foundation

@MainActor final class ExperienceController {
    private(set) var session: ExperienceSession
    private(set) var busy = false
    private(set) var identifying = false
    private(set) var showingInput: Bool
    private(set) var saving = false
    private(set) var status = ""
    private(set) var failed = false
    var onChange: (() -> Void)?
    var onReview: (() -> Void)?
    var onSaved: (([PromptEntry]) -> Void)?
    var onSuggestion: ((String, GeneratedPrompt) -> Void)?
    private(set) var activeItemID: String?
    private(set) var failedItemID: String?
    private let library: PromptLibrary
    private let service: ExperienceServing
    private var operationID: UUID?
    private var task: Task<Void, Never>?
    private var autosave: Task<Void, Never>?
    private var queuedIDs: [String] = []
    private var dirty = false

    init(session: ExperienceSession, library: PromptLibrary, service: ExperienceServing) {
        var restored = session
        for i in restored.items.indices {
            for j in restored.items[i].messages.indices where restored.items[i].messages[j].delivery == .pending {
                restored.items[i].messages[j].delivery = .failed
            }
        }
        if restored.currentID == nil { restored.currentID = restored.items.first?.id }
        if restored != session { restored.revision += 1 }
        self.session = restored; self.library = library; self.service = service
        showingInput = restored.items.isEmpty || restored.addition != nil
    }
    deinit { task?.cancel(); autosave?.cancel() }
    var current: ExperienceItem? { session.current }
    var isManualEntry: Bool { session.intake.manualEntry ?? (session.intake.manualPrompt != nil) }
    var reviewItems: [ExperienceItem] { session.items.filter { $0.candidate != nil } }
    func changeInput(_ value: String) {
        guard !saving else { return }
        guard showingInput else { return }
        var intake = session.intake
        if intake.input != value {
            if intake.origin.source == SourceLink.url(intake.input)?.absoluteString { intake.origin.source = "" }
            intake.origin.raw = ""
        }
        intake.input = value; session.intake = intake
        changed(notify: false)
    }
    func changeSource(_ value: String) { guard !saving, showingInput else { return }; session.intake.origin.source = value; changed(notify: false) }
    func beginAddition() {
        guard !saving else { return }
        if !showingInput { session.addition = session.addition ?? ExperienceIntake() }
        if !busy && !failed { status = "" }
        showingInput = true; changed()
    }
    func cancelAddition() {
        guard !saving, session.addition != nil else { return }
        if identifying { cancel() }
        session.addition = nil; showingInput = false
        if !busy { status = ""; failed = false }
        changed()
        DiagnosticLog.shared.write(.experienceChanged, fields: .init(stage: "addition-discarded"))
    }
    func toggle(_ id: String) {
        guard !saving, let i = session.items.firstIndex(where: { $0.id == id }) else { return }
        session.items[i].selected.toggle(); changed()
    }
    func choose(_ id: String) {
        guard !saving, session.items.contains(where: { $0.id == id }) else { return }
        session.currentID = id; showingInput = false; changed()
        if !identifying, let suggestion = current?.suggestion { onSuggestion?(id, suggestion) }
    }
    func send() {
        guard !busy, !saving, showingInput else { return }
        guard session.items.count < 100 else { show(GenerationFailure.workbenchFull); return }
        identify()
    }
    func beginManual() {
        guard !busy, !saving, showingInput else { return }
        session.intake.manualPrompt = session.intake.manualPrompt ?? ""; session.intake.manualEntry = true; changed()
    }
    func beginAutomatic() {
        guard !busy, !saving, showingInput else { return }
        session.intake.manualEntry = false; changed()
    }
    func changePrompt(_ text: String) {
        guard !saving else { return }
        if showingInput { session.intake.manualPrompt = text; changed(notify: false) }
        else if let item = current {
            let c = item.candidate
            updateCandidate(item.id, GeneratedPrompt(title: c?.title ?? item.title, summary: c?.summary ?? "",
                explanation: c?.explanation ?? "", prompt: text, categoryID: c?.categoryID, newCategoryName: c?.newCategoryName))
            onChange?()
        }
    }
    func continueManual() {
        guard !busy, !saving, showingInput else { return }
        let intake = session.intake
        guard !intake.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.emptyExperience); return }
        guard intake.input.count <= 60_000, (intake.manualPrompt?.count ?? 0) <= 32_000 else { show(GenerationFailure.tooLong); return }
        guard let prompt = intake.manualPrompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.emptyPrompt); return }
        let item = ExperienceItem(title: "新条目", original: intake.input, selected: true,
            candidate: GeneratedPrompt(title: "", summary: "", explanation: "", prompt: prompt, categoryID: nil, newCategoryName: nil), edited: true)
        do { try append([item], raw: intake.input); onReview?() } catch { show(error) }
    }
    private func append(_ items: [ExperienceItem], raw: String) throws {
        guard !items.isEmpty else { throw GenerationFailure.invalidOutput }
        guard session.items.count + items.count <= 100 else { throw GenerationFailure.workbenchFull }
        var next = session
        let origin = ExperienceOrigin(raw: raw, source: session.intake.origin.source)
        if next.addition != nil {
            let id = UUID().uuidString
            var origins = next.origins ?? [:]; origins[id] = origin; next.origins = origins
            next.items += items.map { item in var item = item; item.originID = id; return item }
            next.addition = nil
        } else { next.raw = raw; next.items += items }
        if showingInput || next.currentID == nil { next.currentID = items.first?.id }
        try next.validate()
        session = next; showingInput = false; status = ""; failed = false; changed()
        DiagnosticLog.shared.write(.experienceChanged, fields: .init(stage: "items-appended", rowCount: items.count))
    }
    private func identify() {
        let input = session.intake.input
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.emptyExperience); return }
        guard input.count <= 60_000 else { show(GenerationFailure.tooLong); return }
        run(stage: "experience-identify") { [weak self] token in
            guard let self else { return }
            guard self.session.intake.input == input else { self.discard(token); return }
            let raw: String
            if let url = SourceLink.url(input) {
                if self.session.intake.origin.source.isEmpty { self.session.intake.origin.source = url.absoluteString; self.changed() }
                raw = self.session.intake.origin.raw.isEmpty ? try await self.service.fetch(url) : self.session.intake.origin.raw
            } else { raw = input }
            guard self.valid(token), self.session.intake.input == input else { self.discard(token); return }
            self.session.intake.origin.raw = raw; self.changed(); try await self.persist()
            let items = try await self.service.identify(raw)
            guard self.valid(token), self.session.intake.input == input, self.session.intake.origin.raw == raw else { self.discard(token); return }
            try self.append(items, raw: raw); try await self.persist()
        }
    }
    func organize() {
        guard !busy, !saving else { return }
        guard reviewItems.contains(where: { $0.candidate?.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }) else { show(GenerationFailure.emptyPrompt); return }
        status = ""; failed = false; onReview?()
    }
    func generateSelected() {
        guard !busy, !saving else { return }
        let selected = session.selected.map(\.id)
        guard !selected.isEmpty else { show(GenerationFailure.nothingSelected); return }
        runGeneration(selected)
    }
    private func runGeneration(_ ids: [String]) {
        queuedIDs = ids
        run(stage: "experience-organize") { [weak self] token in
            guard let self else { return }
            while self.valid(token), !self.queuedIDs.isEmpty {
                let id = self.queuedIDs.removeFirst()
                guard let item = self.session.items.first(where: { $0.id == id }) else { continue }
                try await self.generate(item, token: token)
            }
        }
    }
    func generateCurrent() {
        guard !busy, !saving, let item = current else { return }
        if let suggestion = item.suggestion { onSuggestion?(item.id, suggestion); return }
        runGeneration([item.id])
    }
    func remove(_ id: String) {
        guard !saving, let index = session.items.firstIndex(where: { $0.id == id }) else {
            DiagnosticLog.shared.write(.experienceChanged, fields: .init(stage: "remove-unavailable")); return
        }
        session.items.remove(at: index); queuedIDs.removeAll { $0 == id }
        if session.currentID == id { session.currentID = session.items.isEmpty ? nil : session.items[min(index, session.items.count - 1)].id }
        session.pruneOrigins()
        let remaining = queuedIDs
        if activeItemID == id { cancel(); if !remaining.isEmpty { runGeneration(remaining) } }
        if failedItemID == id { failedItemID = nil; failed = false; status = "" }
        if !busy && !failed { status = "" }
        changed()
        DiagnosticLog.shared.write(.experienceChanged, fields: .init(stage: "item-removed", rowCount: session.items.count))
    }
    func confirm(_ id: String) {
        guard !busy, !saving, let i = session.items.firstIndex(where: { $0.id == id }), let c = session.items[i].candidate else { return }
        guard !c.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !c.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { show(GenerationFailure.invalidOutput); return }
        session.items[i].confirmed = true; changed()
    }
    func adoptSuggestion(_ id: String, _ expected: GeneratedPrompt) {
        guard !saving, let i = session.items.firstIndex(where: { $0.id == id }), session.items[i].suggestion == expected else { return }
        session.items[i].candidate = expected; session.items[i].suggestion = nil; session.items[i].confirmed = false; session.items[i].edited = false
        DiagnosticLog.shared.write(.candidateAdopted, fields: .init(stage: "experience-explicit-adoption")); changed()
    }
    func keepCurrent(_ id: String) {
        guard !saving, let i = session.items.firstIndex(where: { $0.id == id }) else { return }
        session.items[i].suggestion = nil; changed()
    }
    private func generate(_ item: ExperienceItem, token: UUID) async throws {
        activeItemID = item.id; failedItemID = nil; onChange?()
        let categories: [PromptCategory] = try await withCheckedThrowingContinuation { continuation in
            library.load(.categories) { result in
                if case .success(.categories(let values)) = result { continuation.resume(returning: values) }
                else if case .failure(let error) = result { continuation.resume(throwing: error) }
                else { continuation.resume(throwing: LibraryFailure.invalidCategory) }
            }
        }
        guard valid(token) else { return }
        let origin = session.origin(for: item)
        let value = try await service.organize(item, source: origin.source, context: origin.raw, categories: categories)
        guard valid(token) else { discard(token); return }
        try value.validate(categories: categories)
        guard valid(token), let index = session.items.firstIndex(where: { $0.id == item.id }),
              session.items[index].candidate == item.candidate else { discard(token); return }
        if let old = item.candidate, !old.prompt.isEmpty || item.edited == true {
            session.items[index].suggestion = value
        } else { session.items[index].candidate = value; session.items[index].confirmed = false; session.items[index].edited = false }
        session.items[index].generatedMessageCount = item.messages.count
        changed(); try await persist()
        if valid(token), !showingInput, session.items.first(where: { $0.id == item.id })?.suggestion == value { onSuggestion?(item.id, value) }
    }
    func updateCandidate(_ id: String, _ value: GeneratedPrompt) {
        guard !saving, let i = session.items.firstIndex(where: { $0.id == id }) else { return }
        session.items[i].candidate = value; session.items[i].confirmed = false; session.items[i].suggestion = nil; session.items[i].edited = true
        if failed, failedItemID == id || (failedItemID == nil && session.addition == nil) {
            failed = false; failedItemID = nil; status = ""
        }
        if activeItemID == id {
            let remaining = queuedIDs; cancel(); if !remaining.isEmpty { runGeneration(remaining) }
        }
        changed(notify: false)
    }
    private func run(stage: String, work: @escaping (UUID) async throws -> Void) {
        let token = UUID(); operationID = token; busy = true; identifying = stage == "experience-identify"; failed = false; status = identifying ? "正在识别…" : "正在整理…"; onChange?()
        DiagnosticLog.shared.write(.generationStarted, operationID: token, fields: .init(stage: stage))
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.persist()
                guard self.valid(token) else { return }
                try await work(token)
                guard self.valid(token) else { return }
                self.busy = false; self.identifying = false; self.activeItemID = nil; self.operationID = nil; self.task = nil; self.status = ""; self.onChange?()
                DiagnosticLog.shared.write(.generationFinished, operationID: token, fields: .init(stage: stage))
            } catch {
                guard self.valid(token) else { self.discard(token); return }
                self.failedItemID = self.activeItemID; self.activeItemID = nil; self.busy = false; self.identifying = false; self.queuedIDs = []; self.operationID = nil; self.task = nil; self.failPending(); self.show(error)
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
        operationID = nil; task?.cancel(); task = nil; busy = false; identifying = false; activeItemID = nil; queuedIDs = []; status = "已取消，输入已保留。"; failed = false
        failPending(); onChange?()
        DiagnosticLog.shared.write(.generationCancelled, operationID: token, fields: .init(stage: "experience-cancelled"))
    }
    private func changed(notify: Bool = true) {
        session.revision += 1; dirty = true
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
        if session.revision == snapshot.revision { dirty = false }
    }
    func save() {
        guard !busy, !saving else { return }
        guard !session.confirmed.isEmpty else { show(GenerationFailure.nothingConfirmed); return }
        saving = true; failed = false; status = "正在保存…"; onChange?()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.persist()
                let snapshot = self.session
                let saved = try await self.library.saveExperiences(snapshot)
                self.session = snapshot.remaining; self.dirty = false; self.saving = false; self.task = nil
                self.status = self.session.items.isEmpty ? "已保存 \(saved.count) 条经验" : "已保存 \(saved.count) 条，其余 \(self.session.items.count) 条保留为草稿"
                self.onChange?(); self.onSaved?(saved)
            } catch { self.saving = false; self.task = nil; self.show(error) }
        }
    }
    func finish() async throws {
        cancel()
        // Wait for the repository transaction before allowing window/app termination.
        if saving { await task?.value }
        saving = true; onChange?()
        defer { saving = false; onChange?() }
        if session.hasDraft || dirty { try await persist() }
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
