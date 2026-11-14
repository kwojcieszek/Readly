import Foundation
import SwiftData

/// A translation the reader starred to come back to.
@Model
public final class SavedPhrase {
    @Attribute(.unique) public var id: UUID
    public var source: String
    public var translation: String
    /// Title of the book the phrase comes from; empty for the standalone translator.
    public var bookTitle: String
    public var createdAt: Date

    public init(source: String, translation: String, bookTitle: String = "", createdAt: Date = .now) {
        self.id = UUID()
        self.source = source
        self.translation = translation
        self.bookTitle = bookTitle
        self.createdAt = createdAt
    }
}
