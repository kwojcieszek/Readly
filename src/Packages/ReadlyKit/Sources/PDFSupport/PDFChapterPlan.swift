import Foundation

/// How a PDF's pages are grouped into chapters, and its table of contents.
struct PDFChapterPlan: Equatable {
    struct Chapter: Equatable {
        var title: String
        /// 0-based page range.
        var pages: Range<Int>
    }

    struct Entry: Equatable {
        var title: String
        var page: Int
        var level: Int
    }

    var chapters: [Chapter]
    var entries: [Entry]

    static let pagesPerChapter = 20

    /// - Parameter outline: The PDF's bookmarks in document order, with their page and depth.
    init(pageCount: Int, outline: [Entry]) {
        let usable = outline.filter { (0..<pageCount).contains($0.page) && !$0.title.isEmpty }
        let topLevel = usable.map(\.level).min()
        var starts: [(title: String, page: Int)] = []
        for entry in usable where entry.level == topLevel {
            if let last = starts.last, last.page == entry.page { continue }
            if let last = starts.last, entry.page < last.page { continue }
            starts.append((entry.title, entry.page))
        }

        guard starts.count >= 2 || (starts.count == 1 && pageCount <= Self.pagesPerChapter) else {
            (chapters, entries) = Self.fixedChapters(pageCount: pageCount, outlineEntries: usable)
            return
        }
        var chapters: [Chapter] = []
        if let first = starts.first, first.page > 0 {
            chapters.append(Chapter(title: "Beginning", pages: 0..<first.page))
        }
        for (index, start) in starts.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1].page : pageCount
            chapters.append(Chapter(title: start.title, pages: start.page..<end))
        }
        self.chapters = chapters
        self.entries = usable.map { Entry(title: $0.title, page: $0.page, level: $0.level - (topLevel ?? 0)) }
    }

    /// Fixed-size chapters for PDFs without a usable outline.
    private static func fixedChapters(pageCount: Int, outlineEntries: [Entry]) -> ([Chapter], [Entry]) {
        let size = Self.pagesPerChapter
        let chapters = stride(from: 0, to: max(1, pageCount), by: size).map { start in
            let end = min(max(1, pageCount), start + size)
            let title = end - start == 1 ? "Page \(start + 1)" : "Pages \(start + 1)–\(end)"
            return Chapter(title: title, pages: start..<end)
        }
        let topLevel = outlineEntries.map(\.level).min() ?? 0
        let entries = outlineEntries.isEmpty
            ? chapters.map { Entry(title: $0.title, page: $0.pages.lowerBound, level: 0) }
            : outlineEntries.map { Entry(title: $0.title, page: $0.page, level: $0.level - topLevel) }
        return (chapters, entries)
    }

    func chapterIndex(containing page: Int) -> Int? {
        chapters.firstIndex { $0.pages.contains(page) }
    }
}
