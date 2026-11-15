import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case polish = "pl"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"

    public var id: Self { self }
    public var localeOverride: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .polish: "Polski"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .italian: "Italiano"
        }
    }
}
