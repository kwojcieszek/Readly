import DesignSystem
import Preferences
import SwiftUI

/// Reading appearance controls shown from the reader toolbar.
struct AppearanceControls: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                sizeButton("Smaller Text", systemImage: "textformat.size.smaller", action: settings.decreaseFontSize)
                    .disabled(settings.fontSize <= ReaderFontSize.range.lowerBound)
                Text("\(settings.fontSize)%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52)
                sizeButton("Larger Text", systemImage: "textformat.size.larger", action: settings.increaseFontSize)
                    .disabled(settings.fontSize >= ReaderFontSize.range.upperBound)
            }

            Slider(value: $settings.fontSize.asDouble, in: ReaderFontSize.range.asDouble, step: Double(ReaderFontSize.step)) {
                Text("Text Size")
            }
            .labelsHidden()

            Picker("Font", selection: $settings.font) {
                ForEach(ReaderFont.allCases) { Text(LocalizedStringKey($0.displayName)).tag($0) }
            }

            Picker("Theme", selection: $settings.theme) {
                ForEach(ReaderTheme.allCases) { Text(LocalizedStringKey($0.displayName)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(18)
        .frame(width: 290)
        .tint(Theme.accent)
    }

    private func sizeButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
            .controlSize(.large)
    }
}
