import LibraryData
import ReaderFeature
import SwiftUI

extension View {
    /// Pushes the reader for the book that was opened.
    func readerDestination(
        _ book: Binding<BookRecord?>,
        environment: AppEnvironment,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        navigationDestination(item: book) { book in
            ReaderView(
                book: book,
                library: environment.library,
                settings: environment.settings,
                translatorFactory: environment.translatorFactory,
                onOpenSettings: onOpenSettings
            )
            .id(book.id)
        }
    }
}
