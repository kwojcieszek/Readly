#if os(macOS)
import LibraryData
import LibraryFeature
import SwiftUI
import TranslationCore
import TranslatorFeature

/// The Mac layout: a sidebar of library sections next to the books or the reader.
struct SidebarRootView: View {
    let environment: AppEnvironment
    let translatorFactory: TranslatorFactory
    @State private var destination: SidebarDestination = .section(.all)
    @State private var openedBook: BookRecord?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $destination, library: environment.library)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            NavigationStack {
                detail.readerDestination($openedBook, environment: environment, translatorFactory: translatorFactory) { openSettings() }
            }
        }
        .onChange(of: destination) { openedBook = nil }
    }

    @ViewBuilder private var detail: some View {
        switch destination {
        case .section:
            LibraryView(
                library: environment.library,
                section: sectionBinding,
                showsSectionChips: false,
                onOpen: { openedBook = $0 }
            )
        case .translator:
            TranslatorView(settings: environment.settings, translatorFactory: translatorFactory, library: environment.library)
        }
    }

    private var sectionBinding: Binding<LibrarySection> {
        Binding {
            if case .section(let section) = destination { section } else { .all }
        } set: {
            destination = .section($0)
        }
    }
}
#endif
