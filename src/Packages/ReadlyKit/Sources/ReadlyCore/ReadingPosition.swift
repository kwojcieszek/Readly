import Foundation

public struct ReadingPosition: Sendable, Equatable {
    public var chapterIndex: Int
    /// Scroll progress inside the chapter, 0...1.
    public var chapterProgress: Double

    public init(chapterIndex: Int = 0, chapterProgress: Double = 0) {
        self.chapterIndex = max(0, chapterIndex)
        self.chapterProgress = min(1, max(0, chapterProgress))
    }

    /// The middle of a 0-based page, so the position lands on the same text
    /// after the chapter is laid out again with a different page count.
    public init(chapterIndex: Int, page: Int, pageCount: Int) {
        self.init(
            chapterIndex: chapterIndex,
            chapterProgress: (Double(max(0, page)) + 0.5) / Double(max(1, pageCount))
        )
    }

    /// The 0-based page this position falls on in a chapter of `pageCount` pages.
    public func page(inChapterWithPageCount pageCount: Int) -> Int {
        let count = max(1, pageCount)
        return min(count - 1, Int(chapterProgress * Double(count)))
    }

    /// Progress through the whole book, 0...1.
    public func overallProgress(chapterCount: Int) -> Double {
        guard chapterCount > 0 else { return 0 }
        let value = (Double(chapterIndex) + chapterProgress) / Double(chapterCount)
        return min(1, max(0, value))
    }
}
