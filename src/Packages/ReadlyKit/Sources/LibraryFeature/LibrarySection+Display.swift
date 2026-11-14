import LibraryData
import SwiftUI

extension LibrarySection {
    /// Title of the section; collections are named by the caller.
    public func title(collections: [BookCollection]) -> String {
        switch self {
        case .all: "Library"
        case .reading: "Reading"
        case .favorites: "Favorites"
        case .collection(let id): collections.first { $0.id == id }?.name ?? "Collection"
        case .trash: "Trash"
        }
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

    var emptyTitle: String {
        switch self {
        case .all: "No Books Yet"
        case .reading: "Nothing in Progress"
        case .favorites: "No Favorites"
        case .collection: "Empty Collection"
        case .trash: "Trash Is Empty"
        }
    }

    var emptyDescription: String {
        switch self {
        case .all: "Add an EPUB or PDF to start reading. Tap a word to translate it, double-tap for the whole sentence."
        case .reading: "Books you have started and not finished appear here."
        case .favorites: "Mark a book as a favorite to find it here."
        case .collection: "Add books to this collection from their menu."
        case .trash: "Books you remove from the library wait here until you delete them."
        }
    }
}
