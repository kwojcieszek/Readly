import EPUBFixtures
import EPUBSupport
import PDFSupport
import Foundation
import ReadlyCore
import SwiftData
import Testing
@testable import LibraryData

@MainActor
@Suite struct BookLibraryTests {
    private let container: ModelContainer
    private let fileStore: BookFileStore
    private let library: BookLibrary

    init() throws {
        container = try LibraryContainer.make(inMemory: true)
        fileStore = BookFileStore(
            baseDirectory: FileManager.default.temporaryDirectory.appending(path: "ReadlyLibrary-\(UUID().uuidString)")
        )
        library = BookLibrary(
            context: container.mainContext,
            registry: BookFormatRegistry(handlers: [EPUBFormatHandler(), PDFFormatHandler()]),
            fileStore: fileStore
        )
    }

    private func storedBooks() throws -> [BookRecord] {
        try container.mainContext.fetch(FetchDescriptor<BookRecord>())
    }

    @Test func addsBookWithMetadataAndCover() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        #expect(book.title == SampleEPUB.title)
        #expect(book.author == SampleEPUB.author)
        #expect(book.format == .epub)
        #expect(book.coverData?.isEmpty == false)
        #expect(fileStore.hasFiles(for: book.id))
        #expect(try storedBooks().count == 1)

        let publication = try await library.publication(for: book)
        #expect(publication.chapters.count == 2)
    }

    @Test func deletingRemovesRecordAndFiles() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        let id = book.id
        library.delete(book)
        #expect(try storedBooks().isEmpty)
        #expect(!fileStore.hasFiles(for: id))
    }

    @Test func savesReadingProgress() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        library.updateProgress(of: book, to: ReadingPosition(chapterIndex: 1, chapterProgress: 0.5), overallProgress: 0.75)
        library.save()

        let stored = try #require(try storedBooks().first)
        #expect(stored.position == ReadingPosition(chapterIndex: 1, chapterProgress: 0.5))
        #expect(stored.overallProgress == 0.75)
    }

    @Test func addsAndRemovesBookmarksInReadingOrder() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        let later = library.addBookmark(
            to: book, at: ReadingPosition(chapterIndex: 1, chapterProgress: 0.2), chapterTitle: "Two", snippet: "later"
        )
        library.addBookmark(
            to: book, at: ReadingPosition(chapterIndex: 0, chapterProgress: 0.9), chapterTitle: "One", snippet: "earlier"
        )
        #expect(book.sortedBookmarks.map(\.snippet) == ["earlier", "later"])

        library.removeBookmark(later)
        #expect(book.sortedBookmarks.map(\.snippet) == ["earlier"])
        #expect(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count == 1)
    }

    @Test func deletingBookRemovesItsBookmarks() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        library.addBookmark(to: book, at: ReadingPosition(), chapterTitle: "One", snippet: "start")
        library.delete(book)
        #expect(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).isEmpty)
    }

    @Test func rejectsUnsupportedFilesWithoutLeavingTraces() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mobi")
        try Data("x".utf8).write(to: file)
        await #expect(throws: LibraryError.unsupportedFormat("mobi")) {
            _ = try await library.addBook(from: file).id
        }
        let brokenPDF = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
        try Data("x".utf8).write(to: brokenPDF)
        await #expect(throws: PDFBookError.unreadable) {
            _ = try await library.addBook(from: brokenPDF).id
        }
        #expect(try storedBooks().isEmpty)
        let leftovers = try? FileManager.default.contentsOfDirectory(atPath: fileStore.baseDirectory.path)
        #expect(leftovers?.isEmpty ?? true)
    }

    @Test func trashHidesBooksUntilTheyAreRestoredOrDeleted() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        library.moveToTrash(book)
        #expect(LibrarySection.trash.contains(book))
        #expect(!LibrarySection.all.contains(book))
        #expect(fileStore.hasFiles(for: book.id))

        library.restore(book)
        #expect(LibrarySection.all.contains(book))

        library.moveToTrash(book)
        library.emptyTrash()
        #expect(try storedBooks().isEmpty)
    }

    @Test func sectionsFollowFavoritesProgressAndCollections() async throws {
        let book = try await library.addBook(from: SampleEPUB.make())
        #expect(!LibrarySection.reading.contains(book))
        #expect(!LibrarySection.favorites.contains(book))

        library.markOpened(book)
        library.toggleFavorite(book)
        #expect(LibrarySection.reading.contains(book))
        #expect(LibrarySection.favorites.contains(book))

        library.updateProgress(of: book, to: ReadingPosition(chapterIndex: 1, chapterProgress: 1), overallProgress: 1)
        #expect(!LibrarySection.reading.contains(book))

        let collection = try #require(library.createCollection(named: "  Sci-Fi "))
        #expect(collection.name == "Sci-Fi")
        #expect(library.createCollection(named: "  ") == nil)
        library.toggle(book, in: collection)
        #expect(LibrarySection.collection(collection.id).contains(book))
        #expect(collection.visibleBooks.count == 1)

        library.deleteCollection(collection)
        #expect(try storedBooks().count == 1)
        #expect(book.collections.isEmpty)
    }

    @Test func savesAndRemovesPhrases() throws {
        let phrase = library.savePhrase(source: "gate", translation: "brama", bookTitle: "Sample")
        #expect(library.savedPhrase(source: "gate", translation: "brama")?.id == phrase.id)
        #expect(library.savedPhrase(source: "gate", translation: "furtka") == nil)
        library.removePhrase(phrase)
        #expect(library.savedPhrase(source: "gate", translation: "brama") == nil)
    }

    @Test func addsAPDFBook() async throws {
        let pdf = FileManager.default.temporaryDirectory.appending(path: "Sample-\(UUID().uuidString).pdf")
        let page = "BT /F1 12 Tf 50 700 Td (A short story about a quiet garden and its pond.) Tj ET"
        let body = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 420 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj
        4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
        5 0 obj << /Length \(page.utf8.count) >> stream
        \(page)
        endstream endobj
        trailer << /Root 1 0 R >>
        %%EOF
        """
        try Data(body.utf8).write(to: pdf)

        let book = try await library.addBook(from: pdf)
        #expect(book.format == .pdf)
        #expect(book.title.hasPrefix("Sample-"))
        #expect(book.coverData?.isEmpty == false)
        let publication = try await library.publication(for: book)
        #expect(publication.chapters.count == 1)
    }
}
