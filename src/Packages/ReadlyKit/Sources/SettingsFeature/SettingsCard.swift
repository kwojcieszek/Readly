import DesignSystem
import SwiftUI

/// A titled, rounded section of the settings screen.
struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline)
        }
    }
}

/// A label above a control.
struct SettingsField<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content
        }
    }
}

extension View {
    /// The soft, borderless input look used across settings.
    func settingsInput() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .settingsInputBackground()
    }

    /// A menu picker in the same soft box as `settingsInput()`.
    func settingsMenuPicker() -> some View {
        labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .settingsInputBackground()
    }

    private func settingsInputBackground() -> some View {
        frame(minHeight: 36)
            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
