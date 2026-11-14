import LibraryData
import SwiftUI

/// The actions offered for one book in the library grid.
struct BookMenu: View {
    let book: BookRecord
    let collections: [BookCollection]
    let library: BookLibrary
    let onOpen: () -> Void
    let onNewCollection: () -> Void
    let onDeletePermanently: () -> Void

    var body: some View {
        if book.isInTrash {
            Button("Put Back", systemImage: "arrow.uturn.backward") { library.restore(book) }
            Button("Delete Permanently…", systemImage: "trash", role: .destructive, action: onDeletePermanently)
        } else {
            Button("Open", systemImage: "book", action: onOpen)
            Button(
                book.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: book.isFavorite ? "heart.slash" : "heart"
            ) { library.toggleFavorite(book) }
            Menu("Collections", systemImage: "folder") {
                ForEach(collections) { collection in
                    Toggle(collection.name, isOn: membership(in: collection))
                }
                if !collections.isEmpty { Divider() }
                Button("New Collection…", systemImage: "folder.badge.plus", action: onNewCollection)
            }
            Divider()
            Button("Move to Trash", systemImage: "trash", role: .destructive) { library.moveToTrash(book) }
        }
    }

    private func membership(in collection: BookCollection) -> Binding<Bool> {
        Binding {
            book.collections.contains { $0.id == collection.id }
        } set: { _ in
            library.toggle(book, in: collection)
        }
    }
}
