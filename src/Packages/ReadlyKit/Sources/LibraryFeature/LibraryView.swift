import DesignSystem
import LibraryData
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

public struct LibraryView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \BookRecord.addedAt, order: .reverse) private var books: [BookRecord]
    @Query(sort: \BookCollection.name) private var collections: [BookCollection]

    private let library: BookLibrary
    @Binding private var section: LibrarySection
    private let showsSectionChips: Bool
    private let onOpen: (BookRecord) -> Void

    @State private var importer = BookImportController()
    @State private var isImporterPresented = false
    #if os(iOS)
    @State private var isPickingFolders = false
    #endif
    @State private var isDropTargeted = false
    @State private var isNamingCollection = false
    @State private var isEmptyingTrash = false
    @State private var bookForNewCollection: BookRecord?
    @State private var bookPendingDeletion: BookRecord?
    @State private var searchText = ""

    /// - Parameter showsSectionChips: Shows the filter chips and the trash menu, for layouts without a sidebar.
    public init(
        library: BookLibrary,
        section: Binding<LibrarySection>,
        showsSectionChips: Bool,
        onOpen: @escaping (BookRecord) -> Void
    ) {
        self.library = library
        _section = section
        self.showsSectionChips = showsSectionChips
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsSectionChips, section != .trash {
                SectionChips(section: $section, collections: collections).padding(.vertical, 10)
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .overlay { if isDropTargeted { dropHighlight } }
        .overlay(alignment: .bottomTrailing) { if showsSectionChips, section != .trash { addButton } }
        .navigationTitle(section.title(collections: collections, locale: locale))
        #if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search books")
        #else
        .searchable(text: $searchText, prompt: "Search books")
        #endif
        .toolbar { toolbar }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                #if os(iOS)
                importer.importBooks(at: urls, into: library, pickingFolders: isPickingFolders)
                #else
                importer.importBooks(at: urls, into: library)
                #endif
            case .failure(let error): importer.errorMessage = error.localizedDescription
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !importer.isImporting else { return false }
            importer.importBooks(at: urls, into: library)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .alert("Couldn’t Add Book", isPresented: Binding(isPresent: $importer.errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importer.errorMessage ?? "")
        }
        .modifier(CollectionNamePrompt(title: "New Collection", isPresented: $isNamingCollection) { name in
            if let collection = library.createCollection(named: name), let book = bookForNewCollection {
                library.toggle(book, in: collection)
            }
            bookForNewCollection = nil
        })
        .confirmationDialog(
            "Delete “\(bookPendingDeletion?.title ?? "")” permanently?",
            isPresented: Binding(isPresent: $bookPendingDeletion),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let book = bookPendingDeletion { library.delete(book) }
            }
        } message: {
            Text("The book, its bookmarks and your reading progress will be deleted.")
        }
        .confirmationDialog("Delete all books in the trash permanently?", isPresented: $isEmptyingTrash, titleVisibility: .visible) {
            Button("Empty Trash", role: .destructive) { library.emptyTrash() }
        }
    }

    @ViewBuilder private var content: some View {
        if sectionBooks.isEmpty {
            ContentUnavailableView {
                Label(section.emptyTitle, systemImage: section == .all ? "books.vertical" : section.systemImage)
            } description: {
                Text(section.emptyDescription)
            } actions: {
                if section == .all {
                    #if os(iOS)
                    Menu("Add Books") { importActions }
                        .buttonStyle(.borderedProminent)
                    #else
                    Button("Add Book") { isImporterPresented = true }
                        .buttonStyle(.borderedProminent)
                    #endif
                }
            }
            .disabled(importer.isImporting)
        } else if filteredBooks.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 26) {
                    ForEach(filteredBooks) { book in
                        Button { open(book) } label: { BookCard(book: book) }
                            .buttonStyle(.plain)
                            .contextMenu { menu(for: book) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, showsSectionChips ? 90 : 24)
            }
        }
    }

    private func menu(for book: BookRecord) -> some View {
        BookMenu(
            book: book,
            collections: collections,
            library: library,
            onOpen: { onOpen(book) },
            onNewCollection: {
                bookForNewCollection = book
                isNamingCollection = true
            },
            onDeletePermanently: { bookPendingDeletion = book }
        )
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if importer.isImporting {
                ProgressView().controlSize(.small)
            }
            if section == .trash {
                Button("Empty Trash", systemImage: "trash.slash") { isEmptyingTrash = true }
                    .disabled(sectionBooks.isEmpty)
                if showsSectionChips {
                    Button("Done") { section = .all }
                }
            } else if showsSectionChips {
                Menu("More", systemImage: "ellipsis") {
                    Button("New Collection…", systemImage: "folder.badge.plus") { isNamingCollection = true }
                    if case .collection(let id) = section, let collection = collections.first(where: { $0.id == id }) {
                        Button("Delete Collection", systemImage: "folder.badge.minus", role: .destructive) {
                            section = .all
                            library.deleteCollection(collection)
                        }
                    }
                    Divider()
                    Button("Trash", systemImage: "trash") { section = .trash }
                }
            } else {
                #if os(iOS)
                Menu("Add Books", systemImage: "plus") { importActions }
                    .disabled(importer.isImporting)
                #else
                Button("Add Book", systemImage: "plus") { isImporterPresented = true }
                    .keyboardShortcut("o")
                    .disabled(importer.isImporting)
                #endif
            }
        }
    }

    #if os(iOS)
    @ViewBuilder private var importActions: some View {
        Button("Choose Files", systemImage: "doc") {
            isPickingFolders = false
            isImporterPresented = true
        }
        Button("Choose Folders", systemImage: "folder") {
            isPickingFolders = true
            isImporterPresented = true
        }
    }
    #endif

    /// The floating "add" button of the phone layout.
    private var addButton: some View {
        Group {
            #if os(iOS)
            Menu { importActions } label: { addButtonLabel }
            #else
            Button { isImporterPresented = true } label: { addButtonLabel }
            #endif
        }
        .buttonStyle(.plain)
        .disabled(importer.isImporting)
        .padding(20)
        .accessibilityLabel("Add Books")
    }

    private var addButtonLabel: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Theme.accent, in: Circle())
            .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 4)
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .background(Theme.accent.opacity(0.06))
            .padding(10)
            .allowsHitTesting(false)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 140, maximum: 190), spacing: 20, alignment: .top)]
    }

    private var sectionBooks: [BookRecord] {
        let matching = books.filter(section.contains)
        guard section == .reading else { return matching }
        return matching.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    private var filteredBooks: [BookRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sectionBooks }
        return sectionBooks.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query)
        }
    }

    private var importTypes: [UTType] {
        #if os(iOS)
        if isPickingFolders { return [.folder] }
        #endif
        let types = library.registry.supportedFileExtensions.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.epub] : types
    }

    /// Books in the trash have to be put back before they can be read.
    private func open(_ book: BookRecord) {
        if !book.isInTrash { onOpen(book) }
    }
}
