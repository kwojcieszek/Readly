import Foundation
import ReadlyCore
import SwiftData

/// The library's write side: adding and removing books and recording progress.
/// Views read books with SwiftData queries.
@MainActor
public final class BookLibrary {
    public let registry: BookFormatRegistry
    let context: ModelContext
    private let importer: BookImporter
    private let fileStore: BookFileStore

    public init(context: ModelContext, registry: BookFormatRegistry, fileStore: BookFileStore = .default) {
        self.context = context
        self.registry = registry
        self.fileStore = fileStore
        self.importer = BookImporter(registry: registry, fileStore: fileStore)
    }

    @discardableResult
    public func addBook(from url: URL) async throws -> BookRecord {
        let imported = try await importer.importBook(from: url)
        let record = BookRecord(
            id: imported.id,
            title: imported.metadata.title,
            author: imported.metadata.author,
            format: imported.format,
            coverData: imported.coverData
        )
        context.insert(record)
        try context.save()
        return record
    }

    /// Removes the book and its files for good; `moveToTrash` is the reversible way.
    public func delete(_ book: BookRecord) {
        fileStore.removeDirectory(for: book.id)
        context.delete(book)
        try? context.save()
    }

    public func publication(for book: BookRecord) async throws -> Publication {
        try await importer.loadPublication(id: book.id, format: book.format)
    }

    public func markOpened(_ book: BookRecord) {
        book.lastOpenedAt = .now
    }

    /// Records where the reader is; `overallProgress` is the share of the whole book read, 0...1.
    public func updateProgress(of book: BookRecord, to position: ReadingPosition, overallProgress: Double) {
        book.chapterIndex = position.chapterIndex
        book.chapterProgress = position.chapterProgress
        book.overallProgress = min(1, max(0, overallProgress))
    }

    public func save() {
        try? context.save()
    }
}

public enum LibraryContainer {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: BookRecord.self, Bookmark.self, BookCollection.self, SavedPhrase.self, configurations: configuration)
    }
}
