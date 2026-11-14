import DesignSystem
import LibraryData
import Preferences
import SwiftUI
import TranslationCore

public struct ReaderView: View {
    @State private var model: ReaderViewModel
    @State private var isPanelVisible = false
    @State private var navigatorTab: NavigatorSheet.Tab?
    @State private var isSearchPresented = false
    @State private var isAppearancePresented = false
    @State private var isGoToPagePresented = false
    @State private var barSize = CGSize(width: 220, height: 40)

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL

    private let settings: AppSettings
    private let onOpenSettings: () -> Void

    public init(
        book: BookRecord,
        library: BookLibrary,
        settings: AppSettings,
        translatorFactory: TranslatorFactory,
        onOpenSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        _model = State(initialValue: ReaderViewModel(
            book: book, library: library, settings: settings, translatorFactory: translatorFactory
        ))
    }

    public var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                content
                if isCompact, isPanelVisible {
                    ScrollView { translationPanel.padding(16) }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxHeight: 340)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline) }
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            if !isCompact, isPanelVisible {
                ScrollView { translationPanel.padding(16) }
                    .frame(width: 300)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(palette.background.color.ignoresSafeArea())
        .animation(.snappy(duration: 0.22), value: isPanelVisible)
        .background { PageTurnShortcuts(model: model) }
        .modifier(ReaderChrome(title: model.title, author: model.author))
        .toolbar { toolbar }
        .sheet(item: $navigatorTab) { NavigatorSheet(model: model, tab: $0) }
        .sheet(isPresented: $isSearchPresented) { SearchSheet(model: model) }
        .sheet(isPresented: $isGoToPagePresented) {
            GoToPageView(currentPage: model.bookPage ?? 1, totalPages: model.totalPages ?? 1, onGo: model.goToBookPage)
                .presentationDetents([.height(150)])
        }
        .task {
            model.openExternalLink = { openURL($0) }
            await model.start(style: style)
        }
        .onChange(of: style) { _, newStyle in model.update(style: newStyle) }
        .onChange(of: model.translation.display != nil) { _, isShown in
            if isShown { isPanelVisible = true }
        }
        .onChange(of: settings.targetLanguageCode) { model.translation.retranslate() }
        .onDisappear { model.close() }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            ZStack {
                // Invisible twin of the reader, same size, used to count pages.
                ReaderWebView(engine: model.measurer.engine)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                ReaderWebView(engine: model.engine)
                    .overlay { selectionBar }
            }
        case .failed(let message):
            ContentUnavailableView(
                "Couldn’t Open Book",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The action bar that follows the highlighted text.
    private var selectionBar: some View {
        GeometryReader { proxy in
            if let display = model.translation.display, let rect = model.selectionRect {
                SelectionBar(
                    display: display,
                    isSaved: model.isCurrentTranslationSaved,
                    isSpeaking: model.speech.isSpeaking(display.source),
                    actions: panelActions
                )
                .fixedSize()
                .onGeometryChange(for: CGSize.self, of: \.size) { barSize = $0 }
                .position(SelectionBarPlacement(selection: rect, barSize: barSize, container: proxy.size).center)
            }
        }
    }

    private var translationPanel: some View {
        TranslationPanel(
            display: model.translation.display,
            sourceLanguageCode: model.sourceLanguageCode,
            settings: settings,
            isSaved: model.isCurrentTranslationSaved,
            isSpeaking: model.speech.isSpeaking,
            actions: panelActions
        )
    }

    private var panelActions: TranslationPanel.Actions {
        TranslationPanel.Actions(
            speak: model.toggleSpeech,
            toggleSaved: model.toggleSavedPhrase,
            translateSentence: model.translateSentenceOfCurrentWord,
            openSettings: onOpenSettings,
            close: {
                isPanelVisible = false
                model.dismissTranslation()
            }
        )
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        #if os(macOS)
        // The system title is hidden, so nothing else pushes the buttons to the trailing edge.
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible)
        }
        #endif
        ToolbarItemGroup(placement: .primaryAction) {
            if !isCompact {
                Button("Contents", systemImage: "list.bullet") { navigatorTab = .contents }
                    .disabled(model.publication == nil)
                Button("Search", systemImage: "magnifyingglass") { isSearchPresented = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(model.publication == nil)
                bookmarkButton
            }
            Button("Appearance", systemImage: "textformat.size") { isAppearancePresented = true }
                .popover(isPresented: $isAppearancePresented) {
                    AppearanceControls(settings: settings)
                        .presentationCompactAdaptation(.popover)
                }
            Button("Translation", systemImage: "translate") { togglePanel() }
                .tint(isPanelVisible ? Theme.accent : nil)
            Button(
                model.readAloud.isPlaying ? "Pause Reading Aloud" : "Read Aloud",
                systemImage: model.readAloud.isPlaying ? "headphones.circle.fill" : "headphones",
                action: model.toggleReadAloud
            )
            .tint(model.readAloud.isActive ? Theme.accent : nil)
            .disabled(model.publication == nil)
            moreMenu
        }
    }

    private var bookmarkButton: some View {
        Button(
            model.isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
            systemImage: model.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark"
        ) {
            Task { await model.toggleBookmark() }
        }
        .tint(model.isCurrentPageBookmarked ? Theme.accent : nil)
        .keyboardShortcut("d", modifiers: .command)
        .disabled(model.publication == nil)
    }

    private var moreMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            if isCompact {
                Button("Contents", systemImage: "list.bullet") { navigatorTab = .contents }
                Button("Search", systemImage: "magnifyingglass") { isSearchPresented = true }
                bookmarkButton
            }
            Button("Bookmarks", systemImage: "bookmark") { navigatorTab = .bookmarks }
            Button(goToPageTitle, systemImage: "arrow.right.to.line") { isGoToPagePresented = true }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(model.totalPages == nil)
            Button(
                model.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: model.isFavorite ? "heart.fill" : "heart",
                action: model.toggleFavorite
            )
            Divider()
            Button("Settings", systemImage: "gearshape", action: onOpenSettings)
        }
        .menuIndicator(.hidden)
        .disabled(model.publication == nil)
    }

    /// Shows where the reader is, now that there is no bottom bar.
    private var goToPageTitle: String {
        model.totalPages == nil ? "Go to Page (counting pages…)" : "Go to Page… (\(model.pageLabel))"
    }

    private func togglePanel() {
        if isPanelVisible {
            isPanelVisible = false
            model.dismissTranslation()
        } else {
            isPanelVisible = true
        }
    }

    private var isCompact: Bool { sizeClass == .compact }

    private var palette: ReaderThemeColors {
        settings.theme.colors(isDark: colorScheme == .dark)
    }

    private var style: ReaderStyle {
        ReaderStyle(settings: settings, colorScheme: colorScheme)
    }
}

/// The reader's title area: a dark toolbar with title and author on the Mac,
/// a bare navigation bar that leaves room for the buttons on iOS.
private struct ReaderChrome: ViewModifier {
    let title: String
    let author: String

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .navigationTitle(title)
            .navigationSubtitle(author)
            .toolbarBackground(Theme.chrome, for: .windowToolbar)
            .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
            .toolbarColorScheme(.dark, for: .windowToolbar)
            // The window keeps its title; the toolbar shows it in light text instead.
            .toolbar(removing: .title)
            .toolbar { titleItem }
        #else
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar { ToolbarItem(placement: .principal) { Color.clear.accessibilityHidden(true) } }
        #endif
    }

    #if os(macOS)
    @ToolbarContentBuilder private var titleItem: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) { titleLabel }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) { titleLabel }
        }
    }

    private var titleLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.headline).foregroundStyle(.white)
            Text(author).font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .lineLimit(1)
        .frame(maxWidth: 420, alignment: .leading)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
    #endif
}
