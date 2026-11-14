import Foundation
import Observation
import TranslationCore

/// User preferences, persisted in `UserDefaults`. API keys live in the keychain instead.
@MainActor
@Observable
public final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    public var provider: TranslationProviderKind {
        didSet { defaults.set(provider.rawValue, forKey: Key.provider) }
    }

    public var targetLanguageCode: String {
        didSet { defaults.set(targetLanguageCode, forKey: Key.targetLanguage) }
    }

    public var font: ReaderFont {
        didSet { defaults.set(font.rawValue, forKey: Key.font) }
    }

    /// Text size in percent of the book's base size.
    public var fontSize: Int {
        didSet { defaults.set(fontSize, forKey: Key.fontSize) }
    }

    public var theme: ReaderTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    private var models: [String: String] {
        didSet { defaults.set(models, forKey: Key.models) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        provider = defaults.string(forKey: Key.provider).flatMap(TranslationProviderKind.init) ?? .openAI
        targetLanguageCode = defaults.string(forKey: Key.targetLanguage) ?? TargetLanguage.deviceDefault.code
        font = defaults.string(forKey: Key.font).flatMap(ReaderFont.init) ?? .serif
        let storedSize = defaults.integer(forKey: Key.fontSize)
        fontSize = ReaderFontSize.range.contains(storedSize) ? storedSize : ReaderFontSize.default
        theme = defaults.string(forKey: Key.theme).flatMap(ReaderTheme.init) ?? .automatic
        models = defaults.dictionary(forKey: Key.models) as? [String: String] ?? [:]
    }

    public var targetLanguage: TargetLanguage {
        TargetLanguage(code: targetLanguageCode)
    }

    public func model(for provider: TranslationProviderKind) -> String {
        models[provider.rawValue] ?? provider.defaultModel
    }

    public func setModel(_ model: String, for provider: TranslationProviderKind) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        models[provider.rawValue] = trimmed.isEmpty || trimmed == provider.defaultModel ? nil : trimmed
    }

    public func increaseFontSize() {
        fontSize = min(ReaderFontSize.range.upperBound, fontSize + ReaderFontSize.step)
    }

    public func decreaseFontSize() {
        fontSize = max(ReaderFontSize.range.lowerBound, fontSize - ReaderFontSize.step)
    }

    private enum Key {
        static let provider = "translation.provider"
        static let models = "translation.models"
        static let targetLanguage = "translation.targetLanguage"
        static let font = "reader.font"
        static let fontSize = "reader.fontSize"
        static let theme = "reader.theme"
    }
}
