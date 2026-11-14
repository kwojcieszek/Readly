import Foundation
import Security

public protocol APIKeyStoring: Sendable {
    func apiKey(for provider: TranslationProviderKind) -> String?
    /// Stores the key; an empty key removes it.
    func setAPIKey(_ key: String, for provider: TranslationProviderKind) throws
}

public struct KeychainError: LocalizedError {
    let status: OSStatus

    public var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "code \(status)"
        return "The API key could not be saved to the keychain (\(detail))."
    }
}

/// Keeps API keys in the system keychain, one entry per provider.
public struct KeychainAPIKeyStore: APIKeyStoring {
    private let service: String

    public init(service: String = "Readly.APIKeys") {
        self.service = service
    }

    public func apiKey(for provider: TranslationProviderKind) -> String? {
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setAPIKey(_ key: String, for provider: TranslationProviderKind) throws {
        let query = baseQuery(for: provider)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(status: status)
            }
            return
        }

        let data = Data(trimmed.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private func baseQuery(for provider: TranslationProviderKind) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }
}

/// Volatile store for tests and previews.
public final class InMemoryAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [TranslationProviderKind: String]

    public init(keys: [TranslationProviderKind: String] = [:]) {
        self.keys = keys
    }

    public func apiKey(for provider: TranslationProviderKind) -> String? {
        lock.withLock { keys[provider] }
    }

    public func setAPIKey(_ key: String, for provider: TranslationProviderKind) throws {
        lock.withLock { keys[provider] = key.isEmpty ? nil : key }
    }
}
