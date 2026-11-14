import Preferences
import SwiftUI

/// A live sample of the reader's font, size and theme.
struct ReadingPreview: View {
    let settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = settings.theme.colors(isDark: colorScheme == .dark)
        Text("The gate was open, and beyond it the garden lay quiet in the morning light.")
            .font(settings.font.previewFont(size: 16 * min(2.2, Double(settings.fontSize) / 100)))
            .lineSpacing(5)
            .foregroundStyle(colors.text.swiftUIColor)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 150, alignment: .leading)
            .padding(16)
            .background(colors.background.swiftUIColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.gray.opacity(0.25))
            }
            .clipped()
            .animation(.snappy(duration: 0.2), value: settings.fontSize)
            .accessibilityLabel("Reading preview")
    }
}

extension ThemeColor {
    var swiftUIColor: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

extension ReaderFont {
    func previewFont(size: Double) -> Font {
        switch self {
        case .original, .serif: .system(size: size, design: .serif)
        case .system: .system(size: size)
        case .georgia: .custom("Georgia", size: size)
        case .palatino: .custom("Palatino", size: size)
        case .rounded: .system(size: size, design: .rounded)
        case .monospaced: .system(size: size, design: .monospaced)
        }
    }
}
