import DesignSystem
import SwiftUI

/// Contents and bookmarks of the open book.
struct NavigatorSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case contents = "Contents"
        case bookmarks = "Bookmarks"
        var id: Self { self }
    }

    let model: ReaderViewModel
    @State var tab: Tab
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Group {
                    switch tab {
                    case .contents:
                        TableOfContentsView(
                            entries: model.publication?.tableOfContents ?? [],
                            isCurrent: model.isCurrent,
                            onSelect: { model.open($0); dismiss() }
                        )
                    case .bookmarks:
                        BookmarkList(
                            bookmarks: model.bookmarks,
                            pageNumber: model.bookPage(of:),
                            isCurrent: model.isOnCurrentPage,
                            onSelect: { model.open($0); dismiss() },
                            onDelete: model.remove
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(model.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 500)
        #endif
    }
}
