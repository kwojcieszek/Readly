import DesignSystem
import SwiftUI

/// Full-text search in the open book.
struct SearchSheet: View {
    let model: ReaderViewModel

    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Search")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search in book")
                #else
                .searchable(text: $query, placement: .toolbar, prompt: "Search in book")
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(Theme.accent)
        .task(id: query) { await search() }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    @ViewBuilder private var content: some View {
        if trimmedQuery.count < 2 {
            ContentUnavailableView(
                "Search in Book", systemImage: "magnifyingglass", description: Text("Type at least two characters.")
            )
        } else if isSearching {
            ProgressView()
        } else if results.isEmpty {
            ContentUnavailableView.search(text: trimmedQuery)
        } else {
            List(results) { result in
                Button {
                    model.open(result)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.snippet).font(.callout).lineLimit(3).multilineTextAlignment(.leading)
                        Text(result.chapterTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() async {
        let text = trimmedQuery
        guard text.count >= 2, let publication = model.publication else {
            results = []
            return
        }
        isSearching = true
        // Wait for a pause in typing.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        let found = await BookSearcher().search(text, in: publication)
        guard !Task.isCancelled else { return }
        results = found
        isSearching = false
    }
}
