import LibraryData
import ReaderFeature
import SwiftUI
import TranslationCore

extension View {
    /// Pushes the reader for the book that was opened.
    func readerDestination(
        _ book: Binding<BookRecord?>,
        environment: AppEnvironment,
        translatorFactory: TranslatorFactory,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        navigationDestination(item: book) { book in
            ReaderView(
                book: book,
                library: environment.library,
                settings: environment.settings,
                translatorFactory: translatorFactory,
                onOpenSettings: onOpenSettings
            )
            .id(book.id)
        }
    }
}
