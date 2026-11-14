import Foundation

/// An sRGB color with 0...255 components, usable from both CSS and SwiftUI.
public struct ThemeColor: Sendable, Equatable {
    public let red: Int
    public let green: Int
    public let blue: Int

    public init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var css: String { "rgb(\(red), \(green), \(blue))" }
}

public struct ReaderThemeColors: Sendable, Equatable {
    public let background: ThemeColor
    public let text: ThemeColor

    public static let light = ReaderThemeColors(
        background: ThemeColor(red: 247, green: 247, blue: 245), text: ThemeColor(red: 34, green: 34, blue: 36)
    )
    public static let sepia = ReaderThemeColors(
        background: ThemeColor(red: 244, green: 236, blue: 216), text: ThemeColor(red: 62, green: 48, blue: 32)
    )
    public static let dark = ReaderThemeColors(
        background: ThemeColor(red: 29, green: 29, blue: 31), text: ThemeColor(red: 214, green: 214, blue: 216)
    )
}

extension ReaderTheme {
    /// The theme's page colors; `automatic` follows the system appearance.
    public func colors(isDark: Bool) -> ReaderThemeColors {
        switch self {
        case .automatic: isDark ? .dark : .light
        case .light: .light
        case .sepia: .sepia
        case .dark: .dark
        }
    }
}
