import Foundation
import Translation
import TranslationCore

/// `Translating` backed by Apple's on-device translator.
public struct SystemTranslator: Translating {
    private let bridge: SystemTranslationBridge

    public init(bridge: SystemTranslationBridge) {
        self.bridge = bridge
    }

    public func translate(_ request: TranslationRequest) async throws -> String {
        let target = Locale.Language(identifier: request.targetLanguageCode ?? "en")
        let pair = SystemTranslationBridge.LanguagePair(
            source: Self.source(request.sourceLanguageCode, target: target),
            target: target
        )
        let result = try await bridge.translate(request.text, pair: pair)
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw TranslationError.emptyResponse }
        return cleaned
    }

    /// The book's language helps with single words; it is dropped when it equals the
    /// target, since a declared language can be wrong and the system then detects it.
    static func source(_ code: String?, target: Locale.Language) -> Locale.Language? {
        guard let code, !code.isEmpty else { return nil }
        let source = Locale.Language(identifier: code)
        return source.languageCode == target.languageCode ? nil : source
    }
}
