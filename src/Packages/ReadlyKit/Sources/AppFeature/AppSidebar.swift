#if os(macOS)
import DesignSystem
import LibraryData
import LibraryFeature
import SwiftData
import SwiftUI

/// What the sidebar can show in the detail area.
enum SidebarDestination: Hashable {
    case section(LibrarySection)
    case translator
}

/// The dark sidebar: library sections with their book counts, collections, translator and trash.
struct AppSidebar: View {
    @Binding var selection: SidebarDestination
    let library: BookLibrary

    @Query private var books: [BookRecord]
    @Query(sort: \BookCollection.name) private var collections: [BookCollection]

    @State private var isCollectionsExpanded = true
    @State private var isNamingCollection = false
    @State private var isRenamingCollection = false
    @State private var collectionBeingRenamed: BookCollection?

    var body: some View {
        List(selection: optionalSelection) {
            Section {
                row("Library", .all)
                row("Reading", .reading)
                row("Favorites", .favorites)
            }
            Section("Collections", isExpanded: $isCollectionsExpanded) {
                ForEach(collections) { collection in
                    row(collection.name, .collection(collection.id))
                        .contextMenu {
                            Button("Rename…", systemImage: "pencil") {
                                collectionBeingRenamed = collection
                                isRenamingCollection = true
                            }
                            Button("Delete Collection", systemImage: "trash", role: .destructive) { delete(collection) }
                        }
                }
                Button("New Collection…", systemImage: "plus") { isNamingCollection = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Section {
                Label("Translator", systemImage: "translate").tag(SidebarDestination.translator)
                row("Trash", .trash)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.chrome)
        .safeAreaInset(edge: .top, spacing: 0) { brand }
        .environment(\.colorScheme, .dark)
        .modifier(CollectionNamePrompt(title: "New Collection", isPresented: $isNamingCollection) { name in
            if let collection = library.createCollection(named: name) {
                selection = .section(.collection(collection.id))
            }
        })
        .modifier(CollectionNamePrompt(
            title: "Rename Collection",
            isPresented: $isRenamingCollection,
            initialName: collectionBeingRenamed?.name ?? ""
        ) { name in
            if let collection = collectionBeingRenamed { library.rename(collection, to: name) }
        })
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.accent.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("Readly").font(.title3.weight(.bold))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func row(_ title: String, _ section: LibrarySection) -> some View {
        Label(title, systemImage: section.systemImage)
            .badge(books.count(where: section.contains))
            .tag(SidebarDestination.section(section))
    }

    private func delete(_ collection: BookCollection) {
        if selection == .section(.collection(collection.id)) { selection = .section(.all) }
        library.deleteCollection(collection)
    }

    /// `List` selects optionals; an emptied selection keeps the current destination.
    private var optionalSelection: Binding<SidebarDestination?> {
        Binding { selection } set: { if let value = $0 { selection = value } }
    }
}
#endif
