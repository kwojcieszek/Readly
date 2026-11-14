import Foundation
import LibraryData

extension ReaderViewModel {
    var isFavorite: Bool { book.isFavorite }

    func toggleFavorite() {
        library.toggleFavorite(book)
    }

    /// Whether the translation on screen is among the saved phrases.
    var isCurrentTranslationSaved: Bool {
        savedPhraseForCurrentTranslation != nil
    }

    /// Stars the translation on screen, or removes its star.
    func toggleSavedPhrase() {
        guard let display = translation.display, let text = display.translatedText else { return }
        if let saved = savedPhraseForCurrentTranslation {
            library.removePhrase(saved)
        } else {
            library.savePhrase(source: display.source, translation: text, bookTitle: book.title)
        }
        savedPhraseRevision += 1
    }

    private var savedPhraseForCurrentTranslation: SavedPhrase? {
        _ = savedPhraseRevision
        guard let display = translation.display, let text = display.translatedText else { return nil }
        return library.savedPhrase(source: display.source, translation: text)
    }
}
