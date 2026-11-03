import Foundation
import Security

enum DeepSeekKeychain {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.promptinjector.deepseek",
         kSecAttrAccount as String: "api-key"]
    }
    static func read() throws -> String {
        var query = query
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw GenerationFailure.missingKey }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else { throw GenerationFailure.keychain(status) }
        return key
    }
    static func importFile(_ url: URL) throws {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, let size = info.fileSize, size <= 1024,
              let value = String(data: try Data(contentsOf: url), encoding: .utf8) else { throw GenerationFailure.missingKey }
        try save(value)
        guard try read() == value.trimmingCharacters(in: .whitespacesAndNewlines) else { throw GenerationFailure.missingKey }
        try Data().write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.utf8.count <= 512, key.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }) else { throw GenerationFailure.missingKey }
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw GenerationFailure.keychain(added) }
        } else if status != errSecSuccess { throw GenerationFailure.keychain(status) }
        DiagnosticLog.shared.write(.credentialSaved, fields: .init(stage: "keychain"))
    }
}
