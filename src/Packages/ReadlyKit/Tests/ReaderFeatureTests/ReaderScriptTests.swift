import Foundation
import Preferences
import Testing
import TranslationCore
import WebKit
@testable import ReaderFeature

/// Drives the real reader script inside WebKit: taps must turn into translation requests.
@MainActor
@Suite(.serialized) struct ReaderScriptTests {
    private let engine = ReaderWebEngine()
    private let recorder = EventRecorder()
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ReadlyReader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filler = String(repeating: "<p>Water stood still in the pond behind the old garden wall.</p>", count: 120)
        let chapter = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
          <head><title>Test</title><style>body, p { font-size: 12pt; }</style></head>
          <body><p>The gate was <em>wide</em> open. Nobody came.</p>\(filler)<h2 id="end">End</h2></body>
        </html>
        """
        try Data(chapter.utf8).write(to: directory.appending(path: "chapter.xhtml"))
        engine.webView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        engine.onEvent = { [recorder] in recorder.events.append($0) }
    }

    private func loadChapter() async throws {
        let defaults = try #require(UserDefaults(suiteName: "ReadlyReaderTests"))
        let style = ReaderStyle(settings: AppSettings(defaults: defaults), colorScheme: .light)
        engine.load(
            chapter: directory.appending(path: "chapter.xhtml"),
            root: directory,
            style: style,
            start: .fraction(0)
        )
        try await recorder.wait { if case .layout = $0 { true } else { false } }
        recorder.events.removeAll()
    }

    /// Taps the middle of the characters `range` of the paragraph's first text node.
    private func tap(characters range: Range<Int>, times: Int) async throws {
        let script = """
        (function () {
          var text = document.querySelector('p').firstChild;
          var range = document.createRange();
          range.setStart(text, \(range.lowerBound));
          range.setEnd(text, \(range.upperBound));
          var box = range.getBoundingClientRect();
          var x = box.left + box.width / 2, y = box.top + box.height / 2;
          var target = document.elementFromPoint(x, y) || document.body;
          var options = { clientX: x, clientY: y, isPrimary: true, pointerType: 'mouse', button: 0, bubbles: true };
          for (var i = 0; i < \(times); i++) {
            target.dispatchEvent(new PointerEvent('pointerdown', options));
            target.dispatchEvent(new PointerEvent('pointerup', options));
          }
          return true;
        })();
        """
        _ = try await engine.webView.evaluateJavaScript(script)
    }

    @Test func singleTapTranslatesTheWordWithItsSentence() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 1)
        try await recorder.wait { if case .translate = $0 { true } else { false } }
        let translation = try #require(translations().first)
        #expect(translation.kind == .word)
        #expect(translation.text == "gate")
        #expect(translation.context == "The gate was wide open.")
        // The highlighted word is reported so the action bar can sit under it.
        let selection = try #require(translation.selection)
        #expect(selection.width > 5 && selection.height > 5)
    }

    @Test func doubleTapTranslatesTheWholeSentence() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 2)
        try await recorder.wait { if case .translate = $0 { true } else { false } }
        try await Task.sleep(for: .milliseconds(500))
        let translations = translations()
        #expect(translations.count == 1)
        #expect(translations.first?.kind == .sentence)
        #expect(translations.first?.text == "The gate was wide open.")
        #expect(translations.first?.context == nil)
    }

    private struct Translation {
        var kind: TranslationRequest.Kind
        var text: String
        var context: String?
        var selection: ReaderEvent.SelectionRect?
    }

    private func translations() -> [Translation] {
        recorder.events.compactMap {
            if case .translate(let kind, let text, let context, let selection) = $0 {
                Translation(kind: kind, text: text, context: context, selection: selection)
            } else {
                nil
            }
        }
    }

    @Test func pageTextCoversOnlyTheVisiblePage() async throws {
        try await loadChapter()
        let first = await engine.pageText()
        #expect(first.hasPrefix("The gate was wide open. Nobody came.\nWater stood still"))
        #expect(!first.contains("End"))

        engine.turnPage(forward: true)
        try await waitForPage(1)
        let layout = try #require(lastLayout())
        engine.goToPage(layout.pageCount - 1)
        try await waitForPage(layout.pageCount - 1)
        let last = await engine.pageText()
        #expect(last.hasSuffix("End"))
        #expect(!last.contains("The gate"))
        #expect(last.count < first.count * 2)
    }

    @Test func searchMatchOpensItsPageAndHighlightsIt() async throws {
        try await loadChapter()
        engine.goToMatch(query: "garden  WALL", index: 100)
        try await recorder.wait { if case .layout(let layout) = $0 { layout.page > 0 && layout.selection != nil } else { false } }
        let text = await engine.pageText()
        #expect(text.contains("garden wall"))
    }

    private func lastLayout() -> ReaderEvent.PageLayout? {
        recorder.events.reversed().lazy.compactMap { if case .layout(let layout) = $0 { layout } else { nil } }.first
    }

    private func waitForPage(_ page: Int) async throws {
        try await recorder.wait { if case .layout(let layout) = $0 { layout.page == page } else { false } }
    }

    @Test func splitsTheChapterIntoPagesAndTurnsThem() async throws {
        try await loadChapter()
        engine.turnPage(forward: true)
        try await waitForPage(1)
        let layout = try #require(lastLayout())
        #expect(layout.pageCount > 2)
        // 800 pt wide view at the default 110 % text size.
        #expect((720...735).contains(layout.width))

        engine.goToPage(layout.pageCount - 1)
        try await waitForPage(layout.pageCount - 1)
        engine.turnPage(forward: true)
        try await recorder.wait { $0 == .boundary(forward: true) }

        engine.goToFragment("end")
        engine.goToPage(0)
        try await waitForPage(0)
        engine.turnPage(forward: false)
        try await recorder.wait { $0 == .boundary(forward: false) }
    }

    private func wheel(_ deltas: [Double]) async throws {
        let script = """
        \(deltas).forEach(function (delta) {
          window.dispatchEvent(new WheelEvent('wheel', { deltaY: delta, cancelable: true }));
        });
        true;
        """
        _ = try await engine.webView.evaluateJavaScript(script)
    }

    private func currentPage() async throws -> Int? {
        (try await engine.webView.evaluateJavaScript("Math.round(window.scrollX / window.innerWidth)") as? NSNumber)?.intValue
    }

    @Test func wheelTurnsExactlyOnePagePerGesture() async throws {
        try await loadChapter()

        // One small mouse-wheel step is enough.
        try await wheel([5])
        try await waitForPage(1)

        // A slow swipe that keeps accelerating long after the turn, then its
        // decaying momentum, is still one page.
        try await Task.sleep(for: .milliseconds(250))
        try await wheel([2, 3, 5, 9, 14, 22, 35, 50, 60])
        try await waitForPage(2)
        try await Task.sleep(for: .milliseconds(100))
        try await wheel([62, 58, 45, 30, 31, 20, 12, 8, 5, 3, 2, 1, 1])
        try await Task.sleep(for: .milliseconds(100))
        #expect(lastLayout()?.page == 2)

        // A second swipe that interrupts the momentum without any pause turns again.
        try await wheel([1, 3, 8, 16, 30, 44, 30, 12, 4, 1])
        try await waitForPage(3)
        try await Task.sleep(for: .milliseconds(450))
        #expect(lastLayout()?.page == 3)
        #expect(try await currentPage() == 3)

        // Backwards after a pause.
        try await wheel([-6])
        try await waitForPage(2)
    }

    @Test func opensOnTheLastPageAndAtFragments() async throws {
        let defaults = try #require(UserDefaults(suiteName: "ReadlyReaderTests"))
        let style = ReaderStyle(settings: AppSettings(defaults: defaults), colorScheme: .light)
        let chapter = directory.appending(path: "chapter.xhtml")

        engine.load(chapter: chapter, root: directory, style: style, start: .lastPage, token: 7)
        try await recorder.wait { if case .layout = $0 { true } else { false } }
        let atEnd = try #require(lastLayout())
        #expect(atEnd.page == atEnd.pageCount - 1)
        #expect(atEnd.token == 7)

        recorder.events.removeAll()
        engine.load(chapter: chapter, root: directory, style: style, start: .fragment("end"))
        try await recorder.wait { if case .layout = $0 { true } else { false } }
        #expect(lastLayout()?.page == atEnd.pageCount - 1)

        let measured = await ChapterMeasurer().pageCount(of: chapter, root: directory, style: style)
        #expect(measured != nil)
    }

    @Test func describesTheVisiblePageForBookmarks() async throws {
        try await loadChapter()
        #expect(await engine.pageSnippet().hasPrefix("The gate was wide open. Nobody came."))

        engine.goToPage(2)
        try await waitForPage(2)
        let snippet = await engine.pageSnippet()
        #expect(snippet.contains("pond"))
        #expect(!snippet.contains("gate"))
        #expect(snippet.count <= 140)
    }

    @Test func appliesTheReaderStyle() async throws {
        try await loadChapter()
        let css = try await engine.webView.evaluateJavaScript(
            "document.getElementById('readly-style').textContent"
        ) as? String
        #expect(css?.contains("ui-serif") == true)
    }

    /// The chapter hard-codes its size in points, which a CSS root font size would not scale.
    @Test func textSizeScalesHardCodedFontSizes() async throws {
        try await loadChapter()
        let before = try #require(await pageCount())
        let widthBefore = try await textWidth()

        let defaults = try #require(UserDefaults(suiteName: "ReadlyReaderTests"))
        let settings = AppSettings(defaults: defaults)
        settings.fontSize = 220
        defer { settings.fontSize = ReaderFontSize.default }
        engine.apply(ReaderStyle(settings: settings, colorScheme: .light))
        try await Task.sleep(for: .milliseconds(400))

        let after = try #require(await pageCount())
        #expect(after > before)
        // Zoomed text takes twice the share of the (fixed-size) view.
        #expect(try await textWidth() > widthBefore * 1.8)
    }

    private func pageCount() async throws -> Int? {
        recorder.events.removeAll()
        engine.goToPage(0)
        try await recorder.wait { if case .layout = $0 { true } else { false } }
        return lastLayout()?.pageCount
    }

    /// Width of the first word as a fraction of the viewport width.
    private func textWidth() async throws -> Double {
        let value = try await engine.webView.evaluateJavaScript("""
        (function () {
          var range = document.createRange();
          var text = document.querySelector('p').firstChild;
          range.setStart(text, 0); range.setEnd(text, 3);
          return range.getBoundingClientRect().width / window.innerWidth;
        })();
        """)
        return (value as? NSNumber)?.doubleValue ?? 0
    }
}

@MainActor
private final class EventRecorder {
    var events: [ReaderEvent] = []

    func wait(for matches: (ReaderEvent) -> Bool) async throws {
        for _ in 0..<100 {
            if events.contains(where: matches) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for a reader event; got \(events)")
    }
}
