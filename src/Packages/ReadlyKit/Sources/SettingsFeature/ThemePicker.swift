import DesignSystem
import Preferences
import SwiftUI

/// Theme choice as color swatches.
struct ThemePicker: View {
    @Binding var selection: ReaderTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ReaderTheme.allCases) { theme in
                swatch(for: theme)
            }
        }
    }

    private func swatch(for theme: ReaderTheme) -> some View {
        let colors = theme.colors(isDark: colorScheme == .dark)
        let isSelected = theme == selection
        return Button {
            withAnimation(.snappy(duration: 0.18)) { selection = theme }
        } label: {
            VStack(spacing: 6) {
                Text("Aa")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(colors.text.swiftUIColor)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(colors.background.swiftUIColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Theme.accent : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    }
                Text(theme.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
