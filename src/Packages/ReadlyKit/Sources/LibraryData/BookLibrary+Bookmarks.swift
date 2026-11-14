import Foundation
import ReadlyCore

extension BookLibrary {
    @discardableResult
    public func addBookmark(
        to book: BookRecord,
        at position: ReadingPosition,
        chapterTitle: String,
        snippet: String
    ) -> Bookmark {
        let bookmark = Bookmark(position: position, chapterTitle: chapterTitle, snippet: snippet)
        context.insert(bookmark)
        bookmark.book = book
        save()
        return bookmark
    }

    public func removeBookmark(_ bookmark: Bookmark) {
        context.delete(bookmark)
        save()
    }
}
