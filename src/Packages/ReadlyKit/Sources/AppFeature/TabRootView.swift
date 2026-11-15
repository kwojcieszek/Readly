#if !os(macOS)
import DesignSystem
import LibraryData
import LibraryFeature
import SettingsFeature
import SwiftUI
import SystemTranslation
import TranslationCore
import TranslatorFeature

/// The iPhone and iPad layout: a tab bar over the library, translator and settings.
struct TabRootView: View {
    let environment: AppEnvironment
    let translatorFactory: TranslatorFactory
    @State private var settingsTranslation = WindowTranslation()
    @State private var isSettingsPresented = false

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                LibraryTab(environment: environment, translatorFactory: translatorFactory, section: .all, showsSectionChips: true) {
                    isSettingsPresented = true
                }
            }
            Tab("Reading", systemImage: "book") {
                LibraryTab(environment: environment, translatorFactory: translatorFactory, section: .reading, showsSectionChips: false) {
                    isSettingsPresented = true
                }
            }
            Tab("Translate", systemImage: "translate") {
                NavigationStack {
                    TranslatorView(
                        settings: environment.settings, translatorFactory: translatorFactory, library: environment.library
                    )
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView(
                        settings: environment.settings,
                        keyStore: environment.keyStore,
                        translatorFactory: translatorFactory,
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
                    translatorFactory: settingsTranslation.factory(keyStore: environment.keyStore)
                )
            }
            .systemTranslationHost(settingsTranslation.bridge)
            .preferredColorScheme(environment.settings.appTheme.colorScheme)
            .tint(Theme.accent)
        }
    }
}

/// One tab that lists books and opens them in the reader.
private struct LibraryTab: View {
    let environment: AppEnvironment
    let translatorFactory: TranslatorFactory
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
            .readerDestination($openedBook, environment: environment, translatorFactory: translatorFactory, onOpenSettings: onOpenSettings)
        }
    }
}
#endif
