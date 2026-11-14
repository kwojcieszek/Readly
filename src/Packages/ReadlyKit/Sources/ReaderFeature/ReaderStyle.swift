import DesignSystem
import Preferences
import SwiftUI

extension ThemeColor {
    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

/// The style payload handed to `reader.js`.
struct ReaderStyle: Codable, Equatable {
    var fontFamily: String?
    var fontSize: Int
    var text: String
    var background: String
    var link: String
    var highlight: String

    @MainActor
    init(settings: AppSettings, colorScheme: ColorScheme) {
        let palette = settings.theme.colors(isDark: colorScheme == .dark)
        fontFamily = settings.font.cssFamily
        fontSize = settings.fontSize
        text = palette.text.css
        background = palette.background.css
        link = "rgb(110, 79, 227)"
        highlight = "rgba(124, 92, 246, 0.30)"
    }
}
