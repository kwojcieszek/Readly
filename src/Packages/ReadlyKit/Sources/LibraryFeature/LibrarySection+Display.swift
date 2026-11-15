import LibraryData
import SwiftUI

extension LibrarySection {
    /// Title of the section; collections are named by the caller.
    public func title(collections: [BookCollection], locale: Locale) -> String {
        switch self {
        case .all: Self.localized("Library", locale: locale)
        case .reading: Self.localized("Reading", locale: locale)
        case .favorites: Self.localized("Favorites", locale: locale)
        case .collection(let id): collections.first { $0.id == id }?.name ?? Self.localized("Collection", locale: locale)
        case .trash: Self.localized("Trash", locale: locale)
        }
    }

    private static func localized(_ title: String, locale: Locale) -> String {
        guard let path = Bundle.main.path(forResource: locale.identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return title }
        return bundle.localizedString(forKey: title, value: title, table: nil)
    }

    public var systemImage: String {
        switch self {
        case .all: "book"
        case .reading: "clock"
        case .favorites: "heart"
        case .collection: "folder"
        case .trash: "trash"
        }
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .all: "No Books Yet"
        case .reading: "Nothing in Progress"
        case .favorites: "No Favorites"
        case .collection: "Empty Collection"
        case .trash: "Trash Is Empty"
        }
    }

    var emptyDescription: LocalizedStringKey {
        switch self {
        case .all: "Add an EPUB or PDF to start reading. Tap a word to translate it, double-tap for the whole sentence."
        case .reading: "Books you have started and not finished appear here."
        case .favorites: "Mark a book as a favorite to find it here."
        case .collection: "Add books to this collection from their menu."
        case .trash: "Books you remove from the library wait here until you delete them."
        }
    }
}
