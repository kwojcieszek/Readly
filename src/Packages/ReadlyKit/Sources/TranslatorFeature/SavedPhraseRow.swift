import DesignSystem
import LibraryData
import SwiftUI

/// One starred translation.
struct SavedPhraseRow: View {
    let phrase: SavedPhrase
    let isSpeaking: Bool
    let onSpeak: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(phrase.source).font(.callout.weight(.semibold))
                Text(phrase.translation).font(.callout).foregroundStyle(.secondary)
                if !phrase.bookTitle.isEmpty {
                    Text(phrase.bookTitle).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            IconButton.speak(isSpeaking: isSpeaking, action: onSpeak)
            IconButton("Remove", systemImage: "star.slash", action: onDelete)
        }
        .padding(.vertical, 10)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { Pasteboard.copy("\(phrase.source)\n\(phrase.translation)") }
            Button("Remove", systemImage: "star.slash", role: .destructive, action: onDelete)
        }
    }
}
