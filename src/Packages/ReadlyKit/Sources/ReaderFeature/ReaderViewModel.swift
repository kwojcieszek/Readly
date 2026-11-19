import Foundation
import LibraryData
import Observation
import Preferences
import Speech
import ReadlyCore
import TranslationCore

@MainActor
@Observable
final class ReaderViewModel {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var publication: Publication?
    private(set) var chapterIndex: Int
    /// 0-based page inside the current chapter and that chapter's page count.
    private(set) var page = 0
    private(set) var chapterPageCount = 1
    private(set) var pageMap = PageMap(chapterCount: 0)
    /// Where the highlighted text sits in the reader, in the web view's coordinates.
    private(set) var selectionRect: CGRect?

    let engine = ReaderWebEngine()
    let measurer = ChapterMeasurer()
    let translation: TranslationController
    let speech: SpeechPlayer
    let readAloud: ReadAloudController
    /// Bumped when a phrase is starred, so views re-check the saved state.
    var savedPhraseRevision = 0

    @ObservationIgnored var openExternalLink: (URL) -> Void = { _ in }
    @ObservationIgnored let book: BookRecord
    @ObservationIgnored let library: BookLibrary
    @ObservationIgnored private var style: ReaderStyle?
    @ObservationIgnored private var measuredLayout: LayoutKey?
    @ObservationIgnored private var measureTask: Task<Void, Never>?
    /// `false` between asking for a chapter and its first layout.
    @ObservationIgnored private var isChapterShown = false

    init(book: BookRecord, library: BookLibrary, settings: AppSettings, translatorFactory: TranslatorFactory) {
        self.book = book
        self.library = library
        self.chapterIndex = book.chapterIndex
        self.speech = SpeechPlayer { settings.voiceQuality }
        self.readAloud = ReadAloudController { settings.voiceQuality }
        self.translation = TranslationController(settings: settings, factory: translatorFactory)
        engine.onEvent = { [weak self] in self?.handle($0) }
        engine.onLinkActivated = { [weak self] in self?.follow($0) }
        engine.onSwipe = { [weak self] in self?.turnPage(forward: $0) }
        readAloud.source = ReadAloudController.Source(
            pageText: { [engine] in await engine.pageText() },
            language: { [weak self] in LanguageGuesser.language(of: $0, declared: self?.publication?.metadata.language) },
            canTurnForward: { [weak self] in self?.canTurnForward ?? false },
            canTurnBack: { [weak self] in self?.canTurnBack ?? false },
            turnPage: { [weak self] in self?.turnPage(forward: $0) }
        )
    }

    var title: String { book.title }
    var author: String { book.author }
    /// Language code the book declares, e.g. "en".
    var sourceLanguageCode: String? {
        publication?.metadata.language.flatMap { $0.split(whereSeparator: { $0 == "-" || $0 == "_" }).first }
            .map { $0.lowercased() }
    }
    var chapterCount: Int { publication?.chapters.count ?? 0 }

    var chapterTitle: String {
        guard let publication, publication.chapters.indices.contains(chapterIndex) else { return "" }
        return publication.chapters[chapterIndex].title ?? "Section \(chapterIndex + 1) of \(chapterCount)"
    }

    /// 1-based page number in the whole book; `nil` while pages are being counted.
    var bookPage: Int? { pageMap.bookPage(chapter: chapterIndex, page: page) }
    var totalPages: Int? { pageMap.totalPages }

    /// Share of the book read, 0...1: by pages once they are counted, by chapters until then.
    var overallProgress: Double {
        if let bookPage, let totalPages {
            return totalPages > 1 ? Double(bookPage - 1) / Double(totalPages - 1) : 1
        }
        return position.overallProgress(chapterCount: chapterCount)
    }

    var progressLabel: String {
        overallProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    var canTurnBack: Bool { page > 0 || chapterIndex > 0 }
    var canTurnForward: Bool { page < chapterPageCount - 1 || chapterIndex < chapterCount - 1 }

    private var position: ReadingPosition {
        ReadingPosition(chapterIndex: chapterIndex, chapterProgress: Double(page) / Double(max(1, chapterPageCount)))
    }

    // MARK: Lifecycle

    func start(style: ReaderStyle) async {
        self.style = style
        guard publication == nil else { return }
        do {
            let publication = try await library.publication(for: book)
            self.publication = publication
            translation.sourceLanguageCode = sourceLanguageCode
            pageMap = PageMap(chapterCount: publication.chapters.count)
            library.markOpened(book)
            phase = .ready
            show(
                chapter: min(book.chapterIndex, publication.chapters.count - 1),
                start: .fraction(book.chapterProgress)
            )
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func update(style: ReaderStyle) {
        guard style != self.style else { return }
        self.style = style
        engine.apply(style)
    }

    /// Reads the original text aloud in the book's language, or stops reading it.
    func toggleSpeech(_ text: String) {
        readAloud.pause()
        let language = LanguageGuesser.language(of: text, declared: publication?.metadata.language)
        speech.toggle(text, language: language)
    }

    func close() {
        speech.stop()
        readAloud.stop()
        measureTask?.cancel()
        translation.dismiss()
        library.save()
    }

    // MARK: Navigation

    func turnPage(forward: Bool) {
        engine.turnPage(forward: forward)
    }

    /// Opens a 1-based page of the book.
    func goToBookPage(_ bookPage: Int) {
        guard let location = pageMap.location(ofBookPage: bookPage) else { return }
        if location.chapter == chapterIndex {
            engine.goToPage(location.page)
        } else {
            show(chapter: location.chapter, start: .page(location.page))
        }
    }

    func open(_ entry: TOCEntry) {
        guard let index = publication?.chapterIndex(for: entry.url) else { return }
        navigate(to: index, fragment: entry.fragment)
    }

    func isCurrent(_ entry: TOCEntry) -> Bool {
        publication?.chapterIndex(for: entry.url) == chapterIndex
    }

    func dismissTranslation() {
        speech.stop()
        translation.dismiss()
        engine.clearHighlight()
        selectionRect = nil
    }

    /// Starts or pauses reading the book aloud.
    func toggleReadAloud() {
        speech.stop()
        readAloud.toggle()
    }

    /// Translates the whole sentence around the word that is being shown.
    func translateSentenceOfCurrentWord() {
        guard let display = translation.display, display.kind == .word, let sentence = display.context else { return }
        speech.stop()
        engine.markSentence()
        translation.translate(kind: .sentence, text: sentence, context: nil)
    }

    func open(_ result: BookSearchResult) {
        if result.chapterIndex == chapterIndex {
            engine.goToMatch(query: result.query, index: result.occurrence)
        } else {
            show(chapter: result.chapterIndex, start: .match(query: result.query, index: result.occurrence))
        }
    }

    private func navigate(to index: Int, fragment: String?) {
        if index == chapterIndex, let fragment {
            engine.goToFragment(fragment)
        } else {
            show(chapter: index, start: fragment.map(ChapterStart.fragment) ?? .fraction(0))
        }
    }

    func show(chapter index: Int, start: ChapterStart) {
        guard let publication, let style, publication.chapters.indices.contains(index) else { return }
        translation.dismiss()
        selectionRect = nil
        chapterIndex = index
        isChapterShown = false
        engine.load(chapter: publication.chapters[index].url, root: publication.rootDirectory, style: style, start: start)
    }

    // MARK: Events

    private func handle(_ event: ReaderEvent) {
        switch event {
        case .translate(let kind, let text, let context, let selection):
            speech.stop()
            selectionRect = selection.map(engine.viewRect)
            translation.translate(kind: kind, text: text, context: context)
        case .layout(let layout):
            let pageChanged = page != layout.page || !isChapterShown
            isChapterShown = true
            selectionRect = layout.selection.map(engine.viewRect)
            if selectionRect == nil, translation.display != nil {
                dismissTranslation()
            }
            page = layout.page
            chapterPageCount = layout.pageCount
            pageMap.setPageCount(layout.pageCount, forChapter: chapterIndex)
            countPagesIfNeeded(for: layout)
            saveProgress()
            if pageChanged { readAloud.pageDidChange() }
        case .boundary(let forward):
            if forward, chapterIndex < chapterCount - 1 {
                show(chapter: chapterIndex + 1, start: .fraction(0))
            } else if !forward, chapterIndex > 0 {
                show(chapter: chapterIndex - 1, start: .lastPage)
            }
        case .dismiss:
            dismissTranslation()
        }
    }

    private func saveProgress() {
        library.updateProgress(of: book, to: position, overallProgress: overallProgress)
    }

    private func follow(_ url: URL) {
        guard url.isFileURL else {
            openExternalLink(url)
            return
        }
        if let index = publication?.chapterIndex(for: url) {
            navigate(to: index, fragment: url.fragment?.removingPercentEncoding)
        }
    }

    // MARK: Page counting

    private struct LayoutKey: Equatable {
        var style: ReaderStyle
        var width: Int
        var height: Int
    }

    /// Recounts the pages of every chapter whenever the text style or the viewport changes.
    private func countPagesIfNeeded(for layout: ReaderEvent.PageLayout) {
        guard let publication, let style, layout.width > 0, layout.height > 0 else { return }
        let key = LayoutKey(style: style, width: layout.width, height: layout.height)
        guard key != measuredLayout else { return }
        measuredLayout = key

        measureTask?.cancel()
        pageMap = PageMap(chapterCount: publication.chapters.count)
        pageMap.setPageCount(layout.pageCount, forChapter: chapterIndex)
        measureTask = Task { [measurer] in
            // Let a window resize or a run of font-size taps settle first.
            try? await Task.sleep(for: .milliseconds(350))
            for (index, chapter) in publication.chapters.enumerated() {
                guard !Task.isCancelled else { return }
                let count = await measurer.pageCount(of: chapter.url, root: publication.rootDirectory, style: style)
                guard !Task.isCancelled else { return }
                pageMap.setPageCount(count ?? 1, forChapter: index)
            }
            // Page numbers are known now, so the saved progress can be exact.
            saveProgress()
        }
    }
}
