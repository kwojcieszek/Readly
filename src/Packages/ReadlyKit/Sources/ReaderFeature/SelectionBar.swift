import DesignSystem
import SwiftUI
import TranslationCore

/// The actions shown below the translation.
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
            IconButton.speak(isSpeaking: isSpeaking) { actions.speak(display.source) }
            IconButton.savePhrase(isSaved: isSaved, action: actions.toggleSaved)
                .disabled(display.translatedText == nil)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var separator: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 20)
    }
}

/// Places the tooltip next to the highlighted text, inside the reader.
struct SelectionBarPlacement {
    var selection: CGRect
    var barSize: CGSize
    var container: CGSize

    /// Centre of the bar: under the text, or above it when the text is low on the page.
    var center: CGPoint {
        let margin: CGFloat = 8
        let halfWidth = barSize.width / 2
        let x = min(max(selection.midX, halfWidth + margin), max(halfWidth + margin, container.width - halfWidth - margin))
        let halfHeight = barSize.height / 2
        let below = selection.maxY + margin + halfHeight
        let above = selection.minY - margin - halfHeight
        let minY = halfHeight + margin
        let maxY = max(minY, container.height - halfHeight - margin)
        let preferredY = below <= maxY || above < minY ? below : above
        return CGPoint(x: x, y: min(max(preferredY, minY), maxY))
    }
}
