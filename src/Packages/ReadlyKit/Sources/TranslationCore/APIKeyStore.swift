import CryptoKit
import Foundation

public protocol APIKeyStoring: Sendable {
    func apiKey(for provider: TranslationProviderKind) -> String?
    /// Stores the key; an empty key removes it.
    func setAPIKey(_ key: String, for provider: TranslationProviderKind) throws
}

/// Keeps encrypted API keys in the app's local settings directory.
public final class EncryptedAPIKeyStore: APIKeyStoring {
    private static let lock = NSLock()
    private let directory: URL

    public init(directory: URL = URL.applicationSupportDirectory.appending(path: "Readly/APIKeys")) {
        self.directory = directory
    }

    public func apiKey(for provider: TranslationProviderKind) -> String? {
        Self.lock.withLock {
            guard let key = try? readKey(for: provider), !key.isEmpty else { return nil }
            return key
        }
    }

    public func setAPIKey(_ key: String, for provider: TranslationProviderKind) throws {
        try Self.lock.withLock {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                do {
                    try FileManager.default.removeItem(at: keyURL(for: provider))
                } catch let error as CocoaError where error.code == .fileNoSuchFile {
                    return
                }
            } else {
                try writeKey(trimmed, for: provider)
            }
        }
    }

    private func readKey(for provider: TranslationProviderKind) throws -> String? {
        let data: Data
        do {
            data = try Data(contentsOf: keyURL(for: provider))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        let sealed = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealed, using: encryptionKey(), authenticating: Data(provider.rawValue.utf8))
        guard let key = String(data: decrypted, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return key
    }

    private func writeKey(_ key: String, for provider: TranslationProviderKind) throws {
        let sealed = try AES.GCM.seal(Data(key.utf8), using: encryptionKey(create: true),
                                     authenticating: Data(provider.rawValue.utf8))
        guard let data = sealed.combined else { throw CocoaError(.fileWriteUnknown) }
        try write(data, to: keyURL(for: provider))
    }

    private func encryptionKey(create: Bool = false) throws -> SymmetricKey {
        let url = directory.appending(path: "encryption-key")
        do {
            let data = try Data(contentsOf: url)
            guard data.count == 32 else { throw CocoaError(.fileReadCorruptFile) }
            return SymmetricKey(data: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile && create {
            // Keep the randomly generated encryption key local to this installation.
            let key = SymmetricKey(size: .bits256)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            var settingsDirectory = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try settingsDirectory.setResourceValues(values)
            try write(key.withUnsafeBytes { Data($0) }, to: url)
            return key
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }

    private func keyURL(for provider: TranslationProviderKind) -> URL {
        directory.appending(path: provider.rawValue + ".sealed")
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
