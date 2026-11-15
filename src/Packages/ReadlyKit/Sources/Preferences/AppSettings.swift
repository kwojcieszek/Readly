import Foundation
import Observation
import Speech
import TranslationCore

/// User preferences, persisted in `UserDefaults`. API keys live in encrypted local settings.
@MainActor
@Observable
public final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    public var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Key.appLanguage) }
    }

    public var appTheme: AppTheme {
        didSet { defaults.set(appTheme.rawValue, forKey: Key.appTheme) }
    }

    public var provider: TranslationProviderKind {
        didSet { defaults.set(provider.rawValue, forKey: Key.provider) }
    }

    public var targetLanguageCode: String {
        didSet { defaults.set(targetLanguageCode, forKey: Key.targetLanguage) }
    }

    public var voiceQuality: VoiceQuality {
        didSet { defaults.set(voiceQuality.rawValue, forKey: Key.voiceQuality) }
    }

    public var font: ReaderFont {
        didSet { defaults.set(font.rawValue, forKey: Key.font) }
    }

    /// Text size in percent of the book's base size.
    public var fontSize: Int {
        didSet { defaults.set(fontSize, forKey: Key.fontSize) }
    }

    public var horizontalMargin: Int {
        didSet { defaults.set(horizontalMargin, forKey: Key.horizontalMargin) }
    }

    public var verticalMargin: Int {
        didSet { defaults.set(verticalMargin, forKey: Key.verticalMargin) }
    }

    public var theme: ReaderTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    private var models: [String: String] {
        didSet { defaults.set(models, forKey: Key.models) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appLanguage = defaults.string(forKey: Key.appLanguage).flatMap(AppLanguage.init) ?? .system
        appTheme = defaults.string(forKey: Key.appTheme).flatMap(AppTheme.init) ?? .automatic
        provider = defaults.string(forKey: Key.provider).flatMap(TranslationProviderKind.init) ?? .apple
        targetLanguageCode = defaults.string(forKey: Key.targetLanguage) ?? TargetLanguage.deviceDefault.code
        voiceQuality = defaults.string(forKey: Key.voiceQuality).flatMap(VoiceQuality.init) ?? .enhanced
        font = defaults.string(forKey: Key.font).flatMap(ReaderFont.init) ?? .serif
        let storedSize = defaults.integer(forKey: Key.fontSize)
        fontSize = ReaderFontSize.range.contains(storedSize) ? storedSize : ReaderFontSize.default
        horizontalMargin = Self.loadMargin(from: defaults, key: Key.horizontalMargin)
        verticalMargin = Self.loadMargin(from: defaults, key: Key.verticalMargin)
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

    private static func loadMargin(from defaults: UserDefaults, key: String) -> Int {
        guard let margin = defaults.object(forKey: key) as? Int,
              ReaderMargin.range.contains(margin) else { return ReaderMargin.default }
        return margin
    }

    private enum Key {
        static let appLanguage = "app.language"
        static let appTheme = "app.theme"
        static let provider = "translation.provider"
        static let models = "translation.models"
        static let targetLanguage = "translation.targetLanguage"
        static let voiceQuality = "speech.voiceQuality"
        static let font = "reader.font"
        static let fontSize = "reader.fontSize"
        static let horizontalMargin = "reader.horizontalMargin"
        static let verticalMargin = "reader.verticalMargin"
        static let theme = "reader.theme"
    }
}
