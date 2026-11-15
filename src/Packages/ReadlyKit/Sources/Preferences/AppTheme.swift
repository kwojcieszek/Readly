import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    public var id: Self { self }

    public var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    public var title: LocalizedStringKey {
        switch self {
        case .automatic: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
