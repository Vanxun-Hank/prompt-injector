import Foundation

struct DiscussionMessage: Codable, Equatable {
    enum Role: String, Codable { case user, assistant }
    enum Delivery: String, Codable { case pending, complete, failed }
    var id = UUID().uuidString
    let role: Role
    let content: String
    var delivery: Delivery = .complete
}

struct ExperienceItem: Codable, Equatable {
    var id = UUID().uuidString
    var title: String
    let original: String
    var messages: [DiscussionMessage] = []
    var input = ""
    var selected = false
    var candidate: GeneratedPrompt?
    var suggestion: GeneratedPrompt?
    var confirmed: Bool?
    var generatedMessageCount: Int?
    var originID: String?
    var edited: Bool?

    var needsGeneration: Bool { candidate == nil || generatedMessageCount != messages.count }
    var needsRemovalConfirmation: Bool { edited ?? (candidate != nil) }
    func entry(source: String) throws -> EditorDraft {
        guard let c = candidate else { throw GenerationFailure.invalidOutput }
        return EditorDraft(entry: .init(id: id, categoryID: c.categoryID ?? "", title: c.title, summary: c.summary,
                                       originalExperience: original, source: source, explanation: c.explanation, prompt: c.prompt),
                           original: nil, newCategoryName: c.newCategoryName)
    }
}

struct ExperienceOrigin: Codable, Equatable {
    var raw: String
    var source: String
}

struct ExperienceIntake: Codable, Equatable {
    var input = ""
    var origin = ExperienceOrigin(raw: "", source: "")
    var manualPrompt: String?
    var manualEntry: Bool?
}

extension GeneratedPrompt {
    init(draft: EditorDraft) {
        let entry = draft.entry
        self.init(title: entry.title, summary: entry.summary, explanation: entry.explanation, prompt: entry.prompt,
                  categoryID: draft.newCategoryName == nil && !entry.categoryID.isEmpty ? entry.categoryID : nil,
                  newCategoryName: draft.newCategoryName)
    }
}

struct ExperienceSession: Codable, Equatable {
    var id = UUID().uuidString
    var revision = 0
    var input = ""
    var source = ""
    var raw = ""
    var items: [ExperienceItem] = []
    var manualPrompt: String?
    var manualEntry: Bool?
    var currentID: String?
    var origins: [String: ExperienceOrigin]?
    var addition: ExperienceIntake?
    var intake: ExperienceIntake {
        get { addition ?? .init(input: input, origin: .init(raw: raw, source: source), manualPrompt: manualPrompt, manualEntry: manualEntry) }
        set {
            if addition != nil { addition = newValue }
            else { input = newValue.input; raw = newValue.origin.raw; source = newValue.origin.source; manualPrompt = newValue.manualPrompt; manualEntry = newValue.manualEntry }
        }
    }
    var hasDraft: Bool { !items.isEmpty || addition != nil || !input.isEmpty || !source.isEmpty || manualPrompt != nil }
    func origin(for item: ExperienceItem) -> ExperienceOrigin {
        item.originID.flatMap { origins?[$0] } ?? .init(raw: raw, source: source)
    }
    var current: ExperienceItem? { items.first { $0.id == currentID } }
    var selected: [ExperienceItem] { items.filter(\.selected) }
    var confirmed: [ExperienceItem] { items.filter { $0.confirmed == true } }
    var remaining: Self {
        var next = self
        next.items.removeAll { $0.confirmed == true }
        if !next.items.contains(where: { $0.id == next.currentID }) { next.currentID = next.items.first?.id }
        next.pruneOrigins()
        next.revision += 1
        return next
    }
    mutating func pruneOrigins() {
        let referenced = Set(items.compactMap(\.originID))
        origins = referenced.isEmpty ? nil : origins?.filter { referenced.contains($0.key) }
        if !items.contains(where: { $0.originID == nil }) {
            input = ""; raw = ""; source = ""; manualPrompt = nil; manualEntry = nil
        }
    }
    func validate() throws {
        guard UUID(uuidString: id) != nil, revision >= 0, input.count <= 60_000, source.count <= 10_000,
              raw.count <= 60_000, (manualPrompt?.count ?? 0) <= 32_000, items.count <= 100,
              Set(items.map(\.id)).count == items.count,
              (origins?.count ?? 0) <= items.count,
              origins?.values.allSatisfy({ $0.raw.count <= 60_000 && $0.source.count <= 10_000 }) != false,
              (addition?.input.count ?? 0) <= 60_000, (addition?.origin.raw.count ?? 0) <= 60_000,
              (addition?.origin.source.count ?? 0) <= 10_000, (addition?.manualPrompt?.count ?? 0) <= 32_000 else { throw GenerationFailure.invalidOutput }
        for item in items {
            guard UUID(uuidString: item.id) != nil, !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.originID == nil || item.originID.flatMap({ origins?[$0] }) != nil,
                  item.title.count <= 200, !item.original.isEmpty, origin(for: item).raw.contains(item.original), item.input.count <= 60_000,
                  item.messages.count <= 500, item.messages.allSatisfy({ !$0.content.isEmpty && $0.content.count <= 60_000 }) else { throw GenerationFailure.invalidOutput }
        }
        guard currentID == nil || items.contains(where: { $0.id == currentID }) else { throw GenerationFailure.invalidOutput }
    }
}

protocol ExperienceRepository: AnyObject {
    func experienceDraft() throws -> ExperienceSession?
    func storeExperienceDraft(_ session: ExperienceSession) throws
    func saveExperiences(_ session: ExperienceSession) throws -> [PromptEntry]
    func deleteEntry(_ original: PromptEntry) throws
}

protocol ExperienceServing {
    func fetch(_ url: URL) async throws -> String
    func identify(_ text: String) async throws -> [ExperienceItem]
    func discuss(_ item: ExperienceItem, source: String, context: String) async throws -> String
    func organize(_ item: ExperienceItem, source: String, context: String, categories: [PromptCategory]) async throws -> GeneratedPrompt
}

enum SourceLink {
    static func articleText(_ markdown: String, url: URL) -> String {
        guard platform(url.absoluteString).name == "X" else { return markdown }
        let lines = markdown.components(separatedBy: .newlines)
        let bodyLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let heading = lines.first, heading.hasPrefix("# "), let body = bodyLines.first,
              bodyLines.allSatisfy({ $0.hasPrefix("- ") }) else { return markdown }
        let post = String(body.dropFirst(2))
        // Fetch's X output repeats the linked post in the heading, then appends replies.
        // Use that exact duplicated body only; unfamiliar formats stay intact for review.
        guard !post.isEmpty, let range = heading.range(of: post) else { return markdown }
        let before = String(heading[..<range.lowerBound]), after = String(heading[range.upperBound...])
        for (open, close) in [("“", "”"), ("\"", "\""), ("「", "」")] where before.hasSuffix(open) && after.hasPrefix(close) {
            let suffix = after.dropFirst(close.count).trimmingCharacters(in: .whitespaces)
            if suffix.isEmpty || suffix == "/ X" { return post }
        }
        return markdown
    }
    static func url(_ text: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased(), !host.isEmpty, url.user == nil, url.password == nil,
              !value.contains(where: \.isWhitespace), host != "localhost", !host.hasSuffix(".local"),
              host != "[::1]", host != "::1", !host.hasPrefix("127."), !host.hasPrefix("10."),
              !host.hasPrefix("192.168."), !host.hasPrefix("169.254.") else { return nil }
        if host.hasPrefix("172."), let second = host.split(separator: ".").dropFirst().first.flatMap({ Int($0) }), (16...31).contains(second) { return nil }
        return url
    }
    static func inSource(_ source: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { $0.url }.first.flatMap { url($0.absoluteString) }
    }
    static func platform(_ source: String) -> (name: String, asset: String?) {
        let host = inSource(source)?.host?.lowercased() ?? ""
        if ["x.com", "twitter.com"].contains(host) || host.hasSuffix(".x.com") || host.hasSuffix(".twitter.com") { return ("X", "SourceX") }
        if host == "github.com" || host.hasSuffix(".github.com") { return ("GitHub", "SourceGitHub") }
        if host == "reddit.com" || host.hasSuffix(".reddit.com") { return ("Reddit", "SourceReddit") }
        return (host.isEmpty ? "来源" : host, nil)
    }
}
