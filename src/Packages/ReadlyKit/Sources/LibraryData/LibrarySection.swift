import Foundation

/// A slice of the library the user can browse.
public enum LibrarySection: Hashable, Sendable {
    case all
    case reading
    case favorites
    case collection(UUID)
    case trash

    public func contains(_ book: BookRecord) -> Bool {
        switch self {
        case .all: !book.isInTrash
        case .reading: !book.isInTrash && book.isBeingRead
        case .favorites: !book.isInTrash && book.isFavorite
        case .collection(let id): !book.isInTrash && book.collections.contains { $0.id == id }
        case .trash: book.isInTrash
        }
    }
}
