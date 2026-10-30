import Foundation

struct PromptCategory: Equatable {
    let id: String
    let name: String
    let symbol: String
    var entryCount: Int = 0
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

struct ManagedSummary: Equatable {
    let summary: PromptSummary
    let source: String
}

enum UsageKind: String, Codable { case copy, insert }
struct UsageRecord: Equatable {
    let promptID: String
    let categoryID: String
    let title: String
    let kind: UsageKind
    let date: Date
}

protocol ManagedPromptRepository: PromptRepository {
    func managedSummaries(category: String?, query: String) throws -> [ManagedSummary]
    func save(_ entry: PromptEntry, replacing original: PromptEntry?) throws
    func storeDraft(_ entry: PromptEntry, original: PromptEntry?) throws
    func editorDraft() throws -> EditorDraft?
    func discardDraft() throws
    func recordUsage(_ entry: PromptEntry, kind: UsageKind, date: Date) throws
    func usage(since: Date?) throws -> [UsageRecord]
}

struct EditorDraft: Codable, Equatable {
    let entry: PromptEntry
    let original: PromptEntry?
}

extension Notification.Name {
    static let promptLibraryChanged = Notification.Name("PromptInjector.library.changed")
    static let promptUsageChanged = Notification.Name("PromptInjector.usage.changed")
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
    private(set) var lastUsageRecordingFailed = false
    init(repository: PromptRepository) { self.repository = repository }
    convenience init() { self.init(repository: SQLitePromptRepository(url: SQLitePromptRepository.defaultURL)) }
    convenience init(entries: [PromptEntry]) { self.init(repository: MemoryPromptRepository(entries: entries)) }
    private func managed<T>(_ operation: @escaping (ManagedPromptRepository) throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        queue.async { [repository] in
            let result = Result<T, Error> {
                guard let repository = repository as? ManagedPromptRepository else { throw LibraryFailure.readOnly }
                return try operation(repository)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
    func manage(category: String?, query: String, completion: @escaping (Result<[ManagedSummary], Error>) -> Void) {
        managed({ try $0.managedSummaries(category: category, query: query) }, completion: completion)
    }
    func save(_ entry: PromptEntry, replacing original: PromptEntry?, completion: @escaping (Result<Void, Error>) -> Void) {
        managed({ try $0.save(entry, replacing: original) }) { [weak self] result in
            if case .success = result {
                NotificationCenter.default.post(name: .promptLibraryChanged, object: self, userInfo: ["id": entry.id, "category": entry.categoryID])
            }
            completion(result)
        }
    }
    func storeDraft(_ entry: PromptEntry, original: PromptEntry?, completion: @escaping (Result<Void, Error>) -> Void) {
        managed({ try $0.storeDraft(entry, original: original) }, completion: completion)
    }
    func editorDraft(completion: @escaping (Result<EditorDraft?, Error>) -> Void) { managed({ try $0.editorDraft() }, completion: completion) }
    func discardDraft(completion: @escaping (Result<Void, Error>) -> Void) { managed({ try $0.discardDraft() }, completion: completion) }
    func recordUsage(_ entry: PromptEntry, kind: UsageKind, completion: ((Result<Void, Error>) -> Void)? = nil) {
        managed({ try $0.recordUsage(entry, kind: kind, date: Date()) }) { [weak self] (result: Result<Void, Error>) in
            if case .failure = result { self?.lastUsageRecordingFailed = true } else { self?.lastUsageRecordingFailed = false }
            NotificationCenter.default.post(name: .promptUsageChanged, object: self)
            completion?(result)
        }
    }
    func flush(completion: @escaping () -> Void) { queue.async { DispatchQueue.main.async(execute: completion) } }
    func usage(since: Date?, completion: @escaping (Result<[UsageRecord], Error>) -> Void) { managed({ try $0.usage(since: since) }, completion: completion) }
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
    case missingEntry, incompatibleVersion, invalidSeed, invalidFields, conflict, readOnly
    var errorDescription: String? {
        switch self {
        case .missingEntry: return "条目不存在，请返回列表。"
        case .incompatibleVersion: return "资料库版本较新，请更新应用。"
        case .invalidSeed: return "无法初始化资料库，请检查安装文件。"
        case .invalidFields: return "请填写标题和 Prompt，并选择有效分类。"
        case .conflict: return "条目已被其他窗口修改。输入已保留，请返回列表核对后再保存。"
        case .readOnly: return "此资料库不支持编辑。"
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
