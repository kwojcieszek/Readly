import SwiftUI

/// A borderless, icon-only button with a comfortable hit area.
public struct IconButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let isActive: Bool
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, systemImage: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(isActive ? Theme.accent : Color.primary.opacity(0.8))
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

extension IconButton {
    /// Reads a text aloud; turns into a stop button while it is being read.
    public static func speak(
        _ title: LocalizedStringKey = "Listen",
        isSpeaking: Bool,
        action: @escaping () -> Void
    ) -> IconButton {
        IconButton(
            isSpeaking ? "Stop" : title,
            systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2",
            isActive: isSpeaking,
            action: action
        )
    }

    /// Stars a translation, or removes its star.
    public static func savePhrase(isSaved: Bool, action: @escaping () -> Void) -> IconButton {
        IconButton(
            isSaved ? "Remove from Saved Phrases" : "Save Phrase",
            systemImage: isSaved ? "star.fill" : "star",
            isActive: isSaved,
            action: action
        )
    }
}

/// A small spinner with a caption, e.g. "Translating…".
public struct LoadingLabel: View {
    private let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(title).foregroundStyle(.secondary)
        }
    }
}

/// The rounded, bordered container used for panels and floating bars.
public struct CardBackground: ViewModifier {
    private let radius: CGFloat

    public init(radius: CGFloat = Theme.cardRadius) {
        self.radius = radius
    }

    public func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.hairline)
            }
    }
}

extension View {
    public func card(radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(CardBackground(radius: radius))
    }
}
