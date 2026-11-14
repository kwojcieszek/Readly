import DesignSystem
import LibraryData
import SwiftUI

/// "All · Reading · Favorites" and one chip per collection.
struct SectionChips: View {
    @Binding var section: LibrarySection
    let collections: [BookCollection]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("All", .all)
                chip("Reading", .reading)
                chip("Favorites", .favorites)
                ForEach(collections) { chip($0.name, .collection($0.id)) }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, _ value: LibrarySection) -> some View {
        FilterChip(title, isSelected: section == value) { section = value }
    }
}
