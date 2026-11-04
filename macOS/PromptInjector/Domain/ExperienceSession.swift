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

    var needsGeneration: Bool { candidate == nil || generatedMessageCount != messages.count }
    func entry(source: String) throws -> EditorDraft {
        guard let c = candidate else { throw GenerationFailure.invalidOutput }
        return EditorDraft(entry: .init(id: id, categoryID: c.categoryID ?? "", title: c.title, summary: c.summary,
                                       originalExperience: original, source: source, explanation: c.explanation, prompt: c.prompt),
                           original: nil, newCategoryName: c.newCategoryName)
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
    var current: ExperienceItem? { items.first { $0.id == currentID } }
    var selected: [ExperienceItem] { items.filter(\.selected) }
    var confirmed: [ExperienceItem] { items.filter { $0.confirmed == true } }
    var remaining: Self {
        var next = self
        next.items.removeAll { $0.confirmed == true }
        if !next.items.contains(where: { $0.id == next.currentID }) { next.currentID = next.items.first?.id }
        if next.items.isEmpty { next.input = ""; next.raw = ""; next.source = ""; next.manualPrompt = nil; next.manualEntry = nil }
        next.revision += 1
        return next
    }
    func validate() throws {
        guard UUID(uuidString: id) != nil, revision >= 0, input.count <= 60_000, source.count <= 10_000,
              raw.count <= 60_000, (manualPrompt?.count ?? 0) <= 32_000, items.count <= 100,
              Set(items.map(\.id)).count == items.count else { throw GenerationFailure.invalidOutput }
        for item in items {
            guard UUID(uuidString: item.id) != nil, !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.title.count <= 200, !item.original.isEmpty, raw.contains(item.original), item.input.count <= 60_000,
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
