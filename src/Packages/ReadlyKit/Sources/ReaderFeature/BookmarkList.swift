import DesignSystem
import LibraryData
import SwiftUI

/// The reader's bookmarks in reading order.
struct BookmarkList: View {
    let bookmarks: [Bookmark]
    let pageNumber: (Bookmark) -> Int?
    let isCurrent: (Bookmark) -> Bool
    let onSelect: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void

    var body: some View {
        if bookmarks.isEmpty {
            ContentUnavailableView(
                "No Bookmarks",
                systemImage: "bookmark",
                description: Text("Use the bookmark button while reading to mark a page.")
            )
        } else {
            List {
                ForEach(bookmarks) { bookmark in
                    row(for: bookmark)
                }
                .onDelete { offsets in offsets.map { bookmarks[$0] }.forEach(onDelete) }
            }
        }
    }

    private func row(for bookmark: Bookmark) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { onSelect(bookmark) } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(isCurrent(bookmark) ? Theme.accent : Color.secondary.opacity(0.6))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookmark.snippet.isEmpty ? bookmark.chapterTitle : bookmark.snippet)
                            .font(.callout)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(caption(for: bookmark))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button("Remove Bookmark", systemImage: "trash", role: .destructive) { onDelete(bookmark) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Remove Bookmark", systemImage: "trash", role: .destructive) { onDelete(bookmark) }
        }
    }

    private func caption(for bookmark: Bookmark) -> String {
        var parts: [String] = []
        if let page = pageNumber(bookmark) { parts.append("Page \(page)") }
        if !bookmark.snippet.isEmpty, !bookmark.chapterTitle.isEmpty { parts.append(bookmark.chapterTitle) }
        parts.append(bookmark.createdAt.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }
}
