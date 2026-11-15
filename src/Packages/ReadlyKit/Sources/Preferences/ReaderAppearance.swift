import Foundation

public enum ReaderFont: String, CaseIterable, Codable, Sendable, Identifiable {
    case original
    case system
    case serif
    case georgia
    case palatino
    case rounded
    case monospaced

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: "Book Default"
        case .system: "San Francisco"
        case .serif: "New York"
        case .georgia: "Georgia"
        case .palatino: "Palatino"
        case .rounded: "Rounded"
        case .monospaced: "Monospaced"
        }
    }

    /// CSS `font-family` value; `nil` keeps the publisher's fonts.
    public var cssFamily: String? {
        switch self {
        case .original: nil
        case .system: "-apple-system, system-ui, sans-serif"
        case .serif: "ui-serif, 'New York', Georgia, serif"
        case .georgia: "Georgia, serif"
        case .palatino: "Palatino, 'Palatino Linotype', serif"
        case .rounded: "ui-rounded, -apple-system, sans-serif"
        case .monospaced: "ui-monospace, Menlo, monospace"
        }
    }
}

public enum ReaderTheme: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic
    case light
    case sepia
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: "Auto"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }
}

public enum ReaderFontSize {
    public static let range = 50...400
    public static let step = 10
    public static let `default` = 110
}

public enum ReaderMargin {
    public static let range = 0...64
    public static let step = 2
    public static let `default` = 12
}
