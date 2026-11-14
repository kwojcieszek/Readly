import Foundation
import Translation

/// Whether the system translator can translate into a language.
public enum SystemLanguageSupport {
    public static func supports(targetCode: String) async -> Bool {
        let languages = await LanguageAvailability().supportedLanguages
        let target = Locale.Language(identifier: targetCode).languageCode
        return languages.contains { $0.languageCode == target }
    }
}
