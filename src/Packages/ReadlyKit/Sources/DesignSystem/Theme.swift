import SwiftUI

/// Readly's look: quiet grays with one soft violet accent.
public enum Theme {
    public static let accent = Color(red: 0.43, green: 0.31, blue: 0.89)
    /// A faint wash of the accent, for selected chips and highlights.
    public static let accentSoft = accent.opacity(0.14)
    public static let cornerRadius: CGFloat = 10
    public static let cardRadius: CGFloat = 14

    public static var background: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    public static var surface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// A subtle fill for search fields, chips and inputs.
    public static let fill = Color.gray.opacity(0.13)
    public static let hairline = Color.gray.opacity(0.25)
}
