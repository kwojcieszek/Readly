import DesignSystem
import ReadlyCore
import SwiftUI

/// The book's table of contents; the current chapter is highlighted.
struct TableOfContentsView: View {
    let entries: [TOCEntry]
    let isCurrent: (TOCEntry) -> Bool
    let onSelect: (TOCEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("No Contents", systemImage: "list.bullet", description: Text("This book has no table of contents."))
        } else {
            List(entries) { entry in
                Button { onSelect(entry) } label: {
                    HStack {
                        Text(entry.title)
                            .font(entry.level == 0 ? .body : .callout)
                            .foregroundStyle(isCurrent(entry) ? Theme.accent : .primary)
                            .padding(.leading, CGFloat(entry.level) * 16)
                        Spacer()
                        if isCurrent(entry) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
