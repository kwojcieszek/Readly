import DesignSystem
import SwiftUI
import TranslationCore

/// Chooses the translation provider from a row of tiles.
struct ProviderPicker: View {
    @Binding var selection: TranslationProviderKind

    var body: some View {
        HStack(spacing: 10) {
            ForEach(TranslationProviderKind.allCases) { provider in
                tile(for: provider)
            }
        }
    }

    private func tile(for provider: TranslationProviderKind) -> some View {
        let isSelected = provider == selection
        return Button {
            withAnimation(.snappy(duration: 0.18)) { selection = provider }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: provider.symbolName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                Text(provider.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Theme.accent.opacity(0.12) : Color.gray.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(provider.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension TranslationProviderKind {
    var shortName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Claude"
        case .gemini: "Gemini"
        case .apple: "Apple"
        }
    }

    var symbolName: String {
        switch self {
        case .openAI: "circle.hexagongrid"
        case .anthropic: "sun.max"
        case .gemini: "sparkles"
        case .apple: "apple.logo"
        }
    }
}
