import Foundation
import LibraryData
import ReadlyCore

extension ReaderViewModel {
    /// The book's bookmarks in reading order.
    var bookmarks: [Bookmark] { book.sortedBookmarks }

    var isCurrentPageBookmarked: Bool { !bookmarksOnCurrentPage.isEmpty }

    /// Bookmarks the visible page, or removes the bookmark it already has.
    func toggleBookmark() async {
        let existing = bookmarksOnCurrentPage
        guard existing.isEmpty else {
            existing.forEach(library.removeBookmark)
            return
        }
        let position = ReadingPosition(chapterIndex: chapterIndex, page: page, pageCount: chapterPageCount)
        let chapterTitle = chapterTitle
        let snippet = await engine.pageSnippet()
        library.addBookmark(to: book, at: position, chapterTitle: chapterTitle, snippet: snippet)
    }

    func open(_ bookmark: Bookmark) {
        if bookmark.chapterIndex == chapterIndex {
            engine.goToPage(bookmark.position.page(inChapterWithPageCount: chapterPageCount))
        } else {
            show(chapter: bookmark.chapterIndex, start: .fraction(bookmark.chapterProgress))
        }
    }

    func remove(_ bookmark: Bookmark) {
        library.removeBookmark(bookmark)
    }

    /// 1-based page of the book the bookmark is on; `nil` until its chapter is counted.
    func bookPage(of bookmark: Bookmark) -> Int? {
        pageMap.bookPage(of: bookmark.position)
    }

    func isOnCurrentPage(_ bookmark: Bookmark) -> Bool {
        bookmark.chapterIndex == chapterIndex
            && bookmark.position.page(inChapterWithPageCount: chapterPageCount) == page
    }

    private var bookmarksOnCurrentPage: [Bookmark] {
        book.bookmarks.filter(isOnCurrentPage)
    }
}
