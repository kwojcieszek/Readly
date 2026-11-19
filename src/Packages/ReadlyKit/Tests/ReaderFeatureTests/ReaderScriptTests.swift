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
    private func tap(characters range: Range<Int>, times: Int, hold: Bool = true) async throws {
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
            if (\(hold)) {
              window.testPointerTarget = target; window.testPointerOptions = options;
            } else {
              target.dispatchEvent(new PointerEvent('pointerup', options));
            }
          }
          return true;
        })();
        """
        _ = try await engine.webView.evaluateJavaScript(script)
        guard hold else { return }
        try await Task.sleep(for: .milliseconds(400))
        _ = try await engine.webView.evaluateJavaScript("""
        window.testPointerTarget.dispatchEvent(new PointerEvent('pointerup', window.testPointerOptions));
        true;
        """)
    }

    @Test func holdingTranslatesTheWordWithItsSentence() async throws {
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

    @Test func tapOnAnotherWordSwitchesTheOpenTranslation() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 1)
        try await recorder.wait { if case .translate = $0 { true } else { false } }
        _ = try await engine.webView.evaluateJavaScript("""
        window.previousHighlight = CSS.highlights.get('readly');
        true;
        """)
        try await tap(characters: 9..<12, times: 1)
        let clearedBeforeNextWord = try await engine.webView.evaluateJavaScript("""
        window.previousHighlight.size === 0 &&
          window.getSelection().isCollapsed
        """) as? Bool
        #expect(clearedBeforeNextWord == true)
        try await recorder.wait { if case .translate(_, "was", _, _) = $0 { true } else { false } }
        #expect(translations().map(\.text) == ["gate", "was"])
        #expect(!recorder.events.contains { if case .dismiss = $0 { true } else { false } })
        let highlightedText = try await engine.webView.evaluateJavaScript("""
        Array.from(CSS.highlights.get('readly')).map(range => range.toString())
        """) as? [String]
        #expect(highlightedText == ["was"])
    }

    @Test func tappingTheSameWordAgainDismissesTheOpenTranslation() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 1)
        try await recorder.wait { if case .translate = $0 { true } else { false } }
        try await tap(characters: 4..<8, times: 1, hold: false)
        try await recorder.wait { if case .dismiss = $0 { true } else { false } }
        let cleared = try await engine.webView.evaluateJavaScript("""
        !CSS.highlights.has('readly') && window.getSelection().isCollapsed
        """) as? Bool
        #expect(cleared == true)
    }

    @Test func closingTranslationClearsHighlightRangesAndNativeSelection() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 1)
        try await recorder.wait { if case .translate = $0 { true } else { false } }
        _ = try await engine.webView.evaluateJavaScript("""
        window.previousHighlight = CSS.highlights.get('readly');
        var selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(Array.from(window.previousHighlight)[0].cloneRange());
        true;
        """)
        engine.clearHighlight()
        try await Task.sleep(for: .milliseconds(100))
        let cleared = try await engine.webView.evaluateJavaScript("""
        !CSS.highlights.has('readly') &&
          window.previousHighlight.size === 0 &&
          window.getSelection().isCollapsed
        """) as? Bool
        #expect(cleared == true)
    }

    @Test func fixedWidthBookTextFitsAfterReaderResizes() async throws {
        let chapter = directory.appending(path: "chapter.xhtml")
        try """
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><meta name="viewport" content="width=1400"/></head>
          <body style="min-width: 1400px !important">
            <p style="width: 1400px; white-space: nowrap">
              A narrow reading area must wrap this paragraph so it stays visible.
            </p>
          </body>
        </html>
        """.write(to: chapter, atomically: true, encoding: .utf8)
        try await loadChapter()
        engine.webView.frame.size = CGSize(width: 320, height: 600)
        try await recorder.wait {
            if case .layout(let layout) = $0 { return layout.width == 320 }
            return false
        }
        let measurements = try await engine.webView.evaluateJavaScript("""
            (function () {
                var viewport = document.querySelector('meta[name="viewport"]');
                var paragraph = document.querySelector('p');
                var text = document.createRange();
                text.selectNodeContents(paragraph);
                var lines = Array.from(text.getClientRects());
                return [
                    viewport.getAttribute('content').includes('width=device-width'),
                    lines.length > 1,
                    lines.every(function (line) { return line.left >= 0 && line.right <= innerWidth; })
                ];
            })();
            """) as? [Bool]
        #expect(measurements == [true, true, true])
    }

    @Test func changingMarginsRepaginatesTheOpenChapter() async throws {
        try await loadChapter()
        let suiteName = "ReadlyMarginTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.horizontalMargin == ReaderMargin.default)
        #expect(settings.verticalMargin == ReaderMargin.default)
        settings.horizontalMargin = 48
        settings.verticalMargin = 32
        let restoredSettings = AppSettings(defaults: defaults)

        engine.apply(ReaderStyle(settings: restoredSettings, colorScheme: .light))
        try await recorder.wait { if case .layout = $0 { true } else { false } }

        let margins = try await engine.webView.evaluateJavaScript("""
            (function () {
                var style = getComputedStyle(document.body);
                return [
                    style.paddingTop, style.paddingBottom, style.paddingLeft, style.paddingRight,
                    style.columnWidth, style.columnGap
                ];
            })();
            """) as? [String]
        #expect(margins == ["32px", "32px", "48px", "48px", "704px", "96px"])
    }

    @Test func shortTapDoesNotTranslate() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 1, hold: false)
        try await Task.sleep(for: .milliseconds(700))
        #expect(translations().isEmpty)
    }

    @Test func twoShortTapsTranslateAndHighlightTheSentence() async throws {
        try await loadChapter()
        try await tap(characters: 4..<8, times: 2, hold: false)
        try await recorder.wait { if case .translate = $0 { true } else { false } }
        let translation = try #require(translations().first)
        #expect(translation.kind == .sentence)
        #expect(translation.text == "The gate was wide open.")
        let highlightedText = try await engine.webView.evaluateJavaScript("""
        Array.from(CSS.highlights.get('readly')).map(range => range.toString())
        """) as? [String]
        #expect(highlightedText == ["The gate was wide open."])
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
        // Text scaling leaves the viewport at its original width.
        #expect(layout.width == 800)

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

    private func wheel(_ deltas: [Double], horizontal: Bool = true) async throws {
        let script = """
        \(deltas).forEach(function (delta) {
          window.dispatchEvent(new WheelEvent('wheel', { \(horizontal ? "deltaX" : "deltaY"): delta, cancelable: true }));
        });
        true;
        """
        _ = try await engine.webView.evaluateJavaScript(script)
    }

    private func currentPage() async throws -> Int? {
        (try await engine.webView.evaluateJavaScript("Math.round(window.scrollX / window.innerWidth)") as? NSNumber)?.intValue
    }

    @Test func horizontalSwipeTurnsExactlyOnePagePerGesture() async throws {
        try await loadChapter()

        try await wheel([5, 20, 40], horizontal: false)
        try await Task.sleep(for: .milliseconds(450))
        #expect(try await currentPage() == 0)

        // One small horizontal swipe is enough.
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
        let offset = try await engine.webView.evaluateJavaScript("window.scrollX") as? Double
        #expect(offset == Double(atEnd.page * atEnd.width))

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
        let bodyWidthBefore = try await bodyWidth()

        let defaults = try #require(UserDefaults(suiteName: "ReadlyReaderTests"))
        let settings = AppSettings(defaults: defaults)
        settings.fontSize = 220
        defer { settings.fontSize = ReaderFontSize.default }
        engine.apply(ReaderStyle(settings: settings, colorScheme: .light))
        try await Task.sleep(for: .milliseconds(400))

        let after = try #require(await pageCount())
        #expect(after > before)
        // Letters grow while the reading area stays the same width.
        #expect(try await textWidth() > widthBefore * 1.8)
        #expect(try await bodyWidth() == bodyWidthBefore)

        settings.fontSize = ReaderFontSize.default
        engine.apply(ReaderStyle(settings: settings, colorScheme: .light))
        _ = try await pageCount()
        #expect(abs(try await textWidth() - widthBefore) < 0.001)
    }

    private func bodyWidth() async throws -> Double? {
        try await engine.webView.evaluateJavaScript("document.body.getBoundingClientRect().width") as? Double
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
