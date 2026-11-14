import Foundation
import ReadlyCore
import SwiftData

/// A place in a book the reader wants to come back to.
@Model
public final class Bookmark {
    @Attribute(.unique) public var id: UUID
    public var book: BookRecord?
    public var chapterIndex: Int
    public var chapterProgress: Double
    public var chapterTitle: String
    /// The first words of the bookmarked page.
    public var snippet: String
    public var createdAt: Date

    public init(
        position: ReadingPosition,
        chapterTitle: String,
        snippet: String,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.chapterIndex = position.chapterIndex
        self.chapterProgress = position.chapterProgress
        self.chapterTitle = chapterTitle
        self.snippet = snippet
        self.createdAt = createdAt
    }

    public var position: ReadingPosition {
        ReadingPosition(chapterIndex: chapterIndex, chapterProgress: chapterProgress)
    }
}
