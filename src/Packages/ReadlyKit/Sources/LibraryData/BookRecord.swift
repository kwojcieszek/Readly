import Foundation
import ReadlyCore
import SwiftData

/// A book in the user's library together with its reading progress.
@Model
public final class BookRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String
    public var formatRawValue: String
    public var addedAt: Date
    public var lastOpenedAt: Date?
    @Attribute(.externalStorage) public var coverData: Data?
    public var chapterIndex: Int
    public var chapterProgress: Double
    public var overallProgress: Double
    public var isFavorite: Bool = false
    /// When the book was moved to the trash; `nil` for books in the library.
    public var deletedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    public var bookmarks: [Bookmark] = []
    @Relationship(inverse: \BookCollection.books)
    public var collections: [BookCollection] = []

    public init(
        id: UUID,
        title: String,
        author: String,
        format: BookFormat,
        coverData: Data?,
        addedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.formatRawValue = format.rawValue
        self.coverData = coverData
        self.addedAt = addedAt
        self.chapterIndex = 0
        self.chapterProgress = 0
        self.overallProgress = 0
    }

    public var format: BookFormat {
        BookFormat(rawValue: formatRawValue) ?? .epub
    }

    public var position: ReadingPosition {
        ReadingPosition(chapterIndex: chapterIndex, chapterProgress: chapterProgress)
    }

    public var isInTrash: Bool { deletedAt != nil }
    public var isFinished: Bool { overallProgress >= 0.995 }
    /// Opened at least once and not read to the end yet.
    public var isBeingRead: Bool { lastOpenedAt != nil && !isFinished }

    /// Bookmarks in reading order.
    public var sortedBookmarks: [Bookmark] {
        bookmarks.sorted {
            ($0.chapterIndex, $0.chapterProgress, $0.createdAt) < ($1.chapterIndex, $1.chapterProgress, $1.createdAt)
        }
    }
}
