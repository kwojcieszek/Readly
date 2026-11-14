import DesignSystem
import LibraryData
import SwiftUI

struct BookCard: View {
    let book: BookRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay { CoverImage(data: book.coverData, title: book.title) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.hairline)
                }
                .overlay(alignment: .topTrailing) { if book.isFavorite { favoriteBadge } }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
            }

            ReadingProgressRow(progress: book.overallProgress, hasBeenOpened: book.lastOpenedAt != nil)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title), \(book.author)\(book.isFavorite ? ", favorite" : "")")
    }

    private var favoriteBadge: some View {
        Image(systemName: "heart.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(Theme.accent, in: Circle())
            .padding(6)
    }
}
