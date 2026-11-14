import Foundation

public struct TargetLanguage: Sendable, Identifiable, Hashable {
    public let code: String

    public var id: String { code }

    /// Name shown in the UI, in the user's language.
    public var displayName: String {
        let name = Locale.current.localizedString(forLanguageCode: code) ?? englishName
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Name used in prompts.
    public var englishName: String {
        Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? code
    }

    public init(code: String) {
        self.code = code
    }

    public static let all: [TargetLanguage] = [
        "ar", "bg", "cs", "da", "de", "el", "en", "es", "fi", "fr", "he", "hi", "hr", "hu", "id",
        "it", "ja", "ko", "lt", "nl", "nb", "pl", "pt", "ro", "ru", "sk", "sv", "tr", "uk", "vi", "zh",
    ].map(TargetLanguage.init)

    /// The device language when supported, English otherwise.
    public static var deviceDefault: TargetLanguage {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return all.first { $0.code == code } ?? TargetLanguage(code: "en")
    }
}
