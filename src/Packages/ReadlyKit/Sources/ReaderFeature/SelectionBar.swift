import DesignSystem
import SwiftUI
import TranslationCore

/// The floating bar of actions under the highlighted text.
struct SelectionBar: View {
    let display: TranslationDisplay
    let isSaved: Bool
    let isSpeaking: Bool
    let actions: TranslationPanel.Actions

    var body: some View {
        HStack(spacing: 2) {
            IconButton("Copy", systemImage: "doc.on.doc") { Pasteboard.copy(display.source) }
            if display.kind == .word, display.context != nil {
                separator
                Button(action: actions.translateSentence) {
                    Label("Sentence", systemImage: "translate")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 8)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Translate the whole sentence")
            }
            separator
            IconButton(
                isSpeaking ? "Stop" : "Listen",
                systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2",
                isActive: isSpeaking
            ) { actions.speak(display.source) }
            IconButton(
                isSaved ? "Remove from Saved Phrases" : "Save Phrase",
                systemImage: isSaved ? "star.fill" : "star",
                isActive: isSaved,
                action: actions.toggleSaved
            )
            .disabled(display.translatedText == nil)
            Menu {
                ShareLink(item: display.source) { Label("Share…", systemImage: "square.and.arrow.up") }
                Button("Close", systemImage: "xmark", action: actions.close)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .card(radius: 12)
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
    }

    private var separator: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 20)
    }
}

/// Places the selection bar next to the highlighted text, inside the reader.
struct SelectionBarPlacement {
    var selection: CGRect
    var barSize: CGSize
    var container: CGSize

    /// Centre of the bar: under the text, or above it when the text is low on the page.
    var center: CGPoint {
        let margin: CGFloat = 8
        let halfWidth = barSize.width / 2
        let x = min(max(selection.midX, halfWidth + margin), max(halfWidth + margin, container.width - halfWidth - margin))
        let below = selection.maxY + margin + barSize.height / 2
        let above = selection.minY - margin - barSize.height / 2
        let fitsBelow = below + barSize.height / 2 <= container.height * 0.6
        let y = fitsBelow || above - barSize.height / 2 < margin ? below : above
        return CGPoint(x: x, y: y)
    }
}
