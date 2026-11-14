import Foundation
import SwiftData

/// Favorites, the trash, collections and saved phrases.
extension BookLibrary {
    public func toggleFavorite(_ book: BookRecord) {
        book.isFavorite.toggle()
        save()
    }

    // MARK: Trash

    public func moveToTrash(_ book: BookRecord) {
        book.deletedAt = .now
        save()
    }

    public func restore(_ book: BookRecord) {
        book.deletedAt = nil
        save()
    }

    /// Permanently deletes every book in the trash.
    public func emptyTrash() {
        let trashed = (try? context.fetch(FetchDescriptor<BookRecord>())) ?? []
        trashed.filter(\.isInTrash).forEach(delete)
    }

    // MARK: Collections

    @discardableResult
    public func createCollection(named name: String) -> BookCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let collection = BookCollection(name: trimmed)
        context.insert(collection)
        save()
        return collection
    }

    public func rename(_ collection: BookCollection, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        collection.name = trimmed
        save()
    }

    /// Removes the collection; its books stay in the library.
    public func deleteCollection(_ collection: BookCollection) {
        context.delete(collection)
        save()
    }

    public func toggle(_ book: BookRecord, in collection: BookCollection) {
        if let index = book.collections.firstIndex(where: { $0.id == collection.id }) {
            book.collections.remove(at: index)
        } else {
            book.collections.append(collection)
        }
        save()
    }

    // MARK: Saved phrases

    @discardableResult
    public func savePhrase(source: String, translation: String, bookTitle: String = "") -> SavedPhrase {
        let phrase = SavedPhrase(source: source, translation: translation, bookTitle: bookTitle)
        context.insert(phrase)
        save()
        return phrase
    }

    public func removePhrase(_ phrase: SavedPhrase) {
        context.delete(phrase)
        save()
    }

    /// The saved phrase for this exact source and translation, if it was starred before.
    public func savedPhrase(source: String, translation: String) -> SavedPhrase? {
        var descriptor = FetchDescriptor<SavedPhrase>(
            predicate: #Predicate { $0.source == source && $0.translation == translation }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
