#if !os(macOS)
import DesignSystem
import LibraryData
import LibraryFeature
import SettingsFeature
import SwiftUI
import TranslatorFeature

/// The iPhone and iPad layout: a tab bar over the library, translator and settings.
struct TabRootView: View {
    let environment: AppEnvironment
    @State private var isSettingsPresented = false

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                LibraryTab(environment: environment, section: .all, showsSectionChips: true) {
                    isSettingsPresented = true
                }
            }
            Tab("Reading", systemImage: "book") {
                LibraryTab(environment: environment, section: .reading, showsSectionChips: false) {
                    isSettingsPresented = true
                }
            }
            Tab("Translate", systemImage: "translate") {
                NavigationStack {
                    TranslatorView(
                        settings: environment.settings, translatorFactory: environment.translatorFactory, library: environment.library
                    )
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView(
                settings: environment.settings,
                keyStore: environment.keyStore,
                translatorFactory: environment.translatorFactory,
                showsDoneButton: false
            )
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            NavigationStack {
                SettingsView(
                settings: environment.settings,
                keyStore: environment.keyStore,
                translatorFactory: environment.translatorFactory
            )
            }
            .tint(Theme.accent)
        }
    }
}

/// One tab that lists books and opens them in the reader.
private struct LibraryTab: View {
    let environment: AppEnvironment
    @State var section: LibrarySection
    let showsSectionChips: Bool
    let onOpenSettings: () -> Void
    @State private var openedBook: BookRecord?

    var body: some View {
        NavigationStack {
            LibraryView(
                library: environment.library,
                section: $section,
                showsSectionChips: showsSectionChips,
                onOpen: { openedBook = $0 }
            )
            .readerDestination($openedBook, environment: environment, onOpenSettings: onOpenSettings)
        }
    }
}
#endif
