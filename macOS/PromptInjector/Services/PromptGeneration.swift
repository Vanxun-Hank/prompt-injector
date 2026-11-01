import Foundation

struct GeneratedPrompt: Codable, Equatable {
    let title: String
    let summary: String
    let explanation: String
    let prompt: String
    let categoryID: String?
    let newCategoryName: String?

    static func decode(_ data: Data, categories: [PromptCategory]) throws -> Self {
        guard data.count <= 256_000,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["title", "summary", "explanation", "prompt", "categoryID", "newCategoryName"]) else { throw GenerationFailure.invalidOutput }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate(categories: categories)
        if let name = value.newCategoryName,
           let existing = categories.first(where: { PromptCategory.nameKey($0.name) == PromptCategory.nameKey((try? PromptCategory.normalizedName(name)) ?? name) }) {
            return Self(title: value.title, summary: value.summary, explanation: value.explanation, prompt: value.prompt, categoryID: existing.id, newCategoryName: nil)
        }
        return value
    }
    func validate(categories: [PromptCategory]) throws {
        for (text, limit) in [(title, 200), (summary, 1000), (explanation, 16000), (prompt, 32000)] {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= limit,
                  !text.contains("\0") else { throw GenerationFailure.invalidOutput }
        }
        switch (categoryID, newCategoryName) {
        case (.some(let id), .none): guard categories.contains(where: { $0.id == id }) else { throw GenerationFailure.invalidOutput }
        case (.none, .some(let name)): _ = try PromptCategory.normalizedName(name)
        default: throw GenerationFailure.invalidOutput
        }
    }
}

enum GenerationFailure: Error, LocalizedError {
    case missingKey, emptyExperience, tooLong, invalidOutput, http(Int), keychain(Int32)
    var errorDescription: String? {
        switch self {
        case .missingKey: return "请先配置 DeepSeek API key。"
        case .emptyExperience: return "请先粘贴原始经验。"
        case .tooLong: return "原始经验过长，请缩短后重试（最多 60,000 字）。"
        case .invalidOutput: return "整理结果不完整或格式无效，请重试。"
        case .http(401): return "DeepSeek API key 无效，请重新配置。"
        case .http(402): return "DeepSeek 余额不足，请检查账户。"
        case .http(429): return "DeepSeek 请求过多，请稍后重试。"
        case .http(let code): return "DeepSeek 请求失败（HTTP \(code)），请重试。"
        case .keychain: return "无法访问 Keychain，请解锁钥匙串后重试。"
        }
    }
}

protocol PromptGenerating {
    func generate(experience: String, source: String, categories: [PromptCategory]) async throws -> GeneratedPrompt
}
