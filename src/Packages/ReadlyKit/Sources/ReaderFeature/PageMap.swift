import Foundation
import ReadlyCore

/// Page counts of every chapter for one layout (text style and viewport size),
/// used to number pages across the whole book.
struct PageMap: Equatable {
    private(set) var counts: [Int?]

    init(chapterCount: Int) {
        counts = Array(repeating: nil, count: chapterCount)
    }

    mutating func setPageCount(_ count: Int, forChapter index: Int) {
        guard counts.indices.contains(index) else { return }
        counts[index] = max(1, count)
    }

    var measuredChapters: Int { counts.count { $0 != nil } }
    var isComplete: Bool { !counts.isEmpty && measuredChapters == counts.count }

    /// Total pages in the book, once every chapter is measured.
    var totalPages: Int? {
        isComplete ? counts.reduce(0) { $0 + ($1 ?? 0) } : nil
    }

    /// 1-based page number in the book for a 0-based page of a chapter.
    func bookPage(chapter: Int, page: Int) -> Int? {
        guard isComplete, counts.indices.contains(chapter) else { return nil }
        let before = counts[..<chapter].reduce(0) { $0 + ($1 ?? 0) }
        return before + min(max(0, page), (counts[chapter] ?? 1) - 1) + 1
    }

    /// 1-based page number in the book for a position, whatever page it falls on in this layout.
    func bookPage(of position: ReadingPosition) -> Int? {
        guard counts.indices.contains(position.chapterIndex), let count = counts[position.chapterIndex] else {
            return nil
        }
        return bookPage(chapter: position.chapterIndex, page: position.page(inChapterWithPageCount: count))
    }

    /// Chapter and 0-based page for a 1-based page number in the book.
    func location(ofBookPage bookPage: Int) -> (chapter: Int, page: Int)? {
        guard let totalPages, totalPages > 0 else { return nil }
        var remaining = min(max(1, bookPage), totalPages) - 1
        for (chapter, count) in counts.enumerated() {
            let count = count ?? 0
            if remaining < count { return (chapter, remaining) }
            remaining -= count
        }
        return nil
    }
}
