import Foundation

struct PromptCategory: Equatable {
    let id: String
    let name: String
    let symbol: String
    static let all: [Self] = [
        .init(id: "requirements", name: "需求对接", symbol: "text.bubble"),
        .init(id: "coding", name: "编码", symbol: "chevron.left.forwardslash.chevron.right"),
        .init(id: "debugging", name: "排查", symbol: "ladybug"),
        .init(id: "review", name: "审查", symbol: "checkmark.shield"),
        .init(id: "release", name: "发布", symbol: "arrow.up.right.square")
    ]
}

struct PromptEntry: Codable, Equatable {
    let id: String
    let categoryID: String
    let title: String
    let summary: String
    let originalExperience: String
    let source: String
    let explanation: String
    let prompt: String
}

struct PromptSummary: Equatable {
    let id: String
    let categoryID: String
    let title: String
    let summary: String
}

enum LibraryPageContent {
    case categories([PromptCategory])
    case entries([PromptSummary])
    case detail(PromptEntry)
}

protocol PromptRepository: AnyObject {
    func categories() throws -> [PromptCategory]
    func summaries(in category: String) throws -> [PromptSummary]
    func entry(id: String, category: String) throws -> PromptEntry?
}

enum PromptSeed {
    static func entries() throws -> [PromptEntry] {
        guard let url = Bundle.main.url(forResource: "prompts", withExtension: "json") ?? Bundle.module.url(forResource: "prompts", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([PromptEntry].self, from: Data(contentsOf: url))
    }
}

/// All repository access, including opening/migration, runs on this serial background queue.
final class PromptLibrary {
    private let repository: PromptRepository
    private let queue = DispatchQueue(label: "com.promptinjector.library", qos: .userInitiated)
    init(repository: PromptRepository) { self.repository = repository }
    convenience init() { self.init(repository: SQLitePromptRepository(url: SQLitePromptRepository.defaultURL)) }
    convenience init(entries: [PromptEntry]) { self.init(repository: MemoryPromptRepository(entries: entries)) }
    func load(_ page: LauncherPage, completion: @escaping (Result<LibraryPageContent, Error>) -> Void) {
        queue.async { [repository] in
            let result = Result<LibraryPageContent, Error> {
                switch page {
                case .categories: return .categories(try repository.categories())
                case .entries(let id): return .entries(try repository.summaries(in: id))
                case .detail(let category, let id):
                    guard let entry = try repository.entry(id: id, category: category) else { throw LibraryFailure.missingEntry }
                    return .detail(entry)
                }
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}

enum LibraryFailure: Error, LocalizedError {
    case missingEntry, incompatibleVersion, invalidSeed
    var errorDescription: String? {
        switch self {
        case .missingEntry: return "条目不存在，请返回列表。"
        case .incompatibleVersion: return "资料库版本较新，请更新应用。"
        case .invalidSeed: return "无法初始化资料库，请检查安装文件。"
        }
    }
}

/// Only used for isolated fixtures; the running app always uses SQLite.
final class MemoryPromptRepository: PromptRepository {
    let entries: [PromptEntry]
    init(entries: [PromptEntry]) { self.entries = entries }
    func categories() throws -> [PromptCategory] { PromptCategory.all }
    func summaries(in category: String) throws -> [PromptSummary] {
        entries.filter { $0.categoryID == category }.map { .init(id: $0.id, categoryID: $0.categoryID, title: $0.title, summary: $0.summary) }
    }
    func entry(id: String, category: String) throws -> PromptEntry? { entries.first { $0.id == id && $0.categoryID == category } }
}

enum LauncherPage: Equatable {
    case categories
    case entries(String)
    case detail(String, String)
    var level: Int {
        switch self {
        case .categories: return 0
        case .entries: return 1
        case .detail: return 2
        }
    }
    var key: String {
        switch self {
        case .categories: return "categories"
        case .entries(let id): return "entries/\(id)"
        case .detail(_, let id): return "detail/\(id)"
        }
    }
}

struct PageMemory {
    var selection = 0
    var scrollY: CGFloat = 0
}

struct NavigationState {
    private(set) var page: LauncherPage = .categories
    private(set) var memory: [String: PageMemory] = [:]
    mutating func remember(selection: Int, scrollY: CGFloat) {
        memory[page.key] = .init(selection: selection, scrollY: scrollY)
    }
    mutating func open(_ page: LauncherPage) { self.page = page }
    @discardableResult mutating func back() -> Bool {
        switch page {
        case .categories: return false
        case .entries: page = .categories
        case .detail(let category, _): page = .entries(category)
        }
        return true
    }
    var restored: PageMemory { memory[page.key] ?? .init() }
}
