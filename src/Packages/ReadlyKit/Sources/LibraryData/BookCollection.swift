import Foundation
import SwiftData

/// A named group of books; a book can be in any number of collections.
@Model
public final class BookCollection {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date
    public var books: [BookRecord] = []

    public init(name: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
    }

    /// The collection's books that are not in the trash.
    public var visibleBooks: [BookRecord] {
        books.filter { !$0.isInTrash }
    }
}
