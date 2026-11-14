import Foundation
import WebKit

/// Owns the web view that renders chapters and bridges it to Swift.
@MainActor
final class ReaderWebEngine: NSObject {
    let webView: WKWebView
    var onEvent: (ReaderEvent) -> Void = { _ in }
    var onLinkActivated: (URL) -> Void = { _ in }
    /// A horizontal swipe on touch devices; `true` means "next page".
    var onSwipe: (Bool) -> Void = { _ in }

    private static let handlerName = "readly"
    private let readerScript: String

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        readerScript = Bundle.module.url(forResource: "reader", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        super.init()

        webView.configuration.userContentController.add(WeakMessageHandler(self), name: Self.handlerName)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        // Pages are turned by the reader script, never by free scrolling.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        installSwipeRecognizers()
        #endif
    }

    /// Loads a chapter and opens it at `start`. `token` is echoed in layout events.
    func load(chapter: URL, root: URL, style: ReaderStyle, start: ChapterStart, token: Int = 0) {
        let config = PageConfig(style: style, start: start, token: token)
        applyTextSize(of: style)
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(
            source: "window.__readlyConfig = \(Self.json(config));",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: readerScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        webView.loadFileURL(chapter, allowingReadAccessTo: root)
    }

    func apply(_ style: ReaderStyle) {
        applyTextSize(of: style)
        run("window.Readly && window.Readly.applyStyle(\(Self.json(style)));")
    }

    /// Text size is native page zoom: unlike a CSS font size it also scales books
    /// that hard-code their sizes in points or pixels.
    private func applyTextSize(of style: ReaderStyle) {
        let zoom = CGFloat(style.fontSize) / 100
        if abs(webView.pageZoom - zoom) > 0.001 { webView.pageZoom = zoom }
    }

    func turnPage(forward: Bool) {
        run("window.Readly && window.Readly.turnPage(\(forward ? 1 : -1));")
    }

    /// Shows a 0-based page of the loaded chapter.
    func goToPage(_ page: Int) {
        run("window.Readly && window.Readly.goToPage(\(page));")
    }

    func goToMatch(query: String, index: Int) {
        run("window.Readly && window.Readly.goToMatch(\(Self.json(query)), \(index));")
    }

    func goToFragment(_ fragment: String) {
        run("window.Readly && window.Readly.goToFragment(\(Self.json(fragment)));")
    }

    func clearHighlight() {
        run("window.Readly && window.Readly.clearHighlight();")
    }

    func markSentence() {
        run("window.Readly && window.Readly.markSentence();")
    }

    /// The text of the visible page, one line per paragraph.
    func pageText() async -> String {
        let result = try? await webView.evaluateJavaScript("window.Readly ? window.Readly.pageText() : '';")
        return result as? String ?? ""
    }

    /// Converts a rectangle reported by the page into the web view's coordinates.
    func viewRect(for selection: ReaderEvent.SelectionRect) -> CGRect {
        let zoom = webView.pageZoom
        return CGRect(
            x: selection.x * zoom, y: selection.y * zoom, width: selection.width * zoom, height: selection.height * zoom
        )
    }

    /// The first words of the visible page.
    func pageSnippet() async -> String {
        let result = try? await webView.evaluateJavaScript("window.Readly ? window.Readly.pageSnippet() : '';")
        return result as? String ?? ""
    }

    private func run(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private static func json<Value: Encodable>(_ value: Value) -> String {
        let data = (try? JSONEncoder().encode(value)) ?? Data("null".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private struct PageConfig: Encodable {
        var style: ReaderStyle
        var token: Int
        var fraction: Double?
        var page: Int?
        var fragment: String?
        var match: Match?
        var fromEnd = false

        struct Match: Encodable {
            var query: String
            var index: Int
        }

        init(style: ReaderStyle, start: ChapterStart, token: Int) {
            self.style = style
            self.token = token
            switch start {
            case .fraction(let fraction): self.fraction = fraction
            case .page(let page): self.page = page
            case .fragment(let fragment): self.fragment = fragment
            case .match(let query, let index): match = Match(query: query, index: index)
            case .lastPage: fromEnd = true
            }
        }
    }
}

/// Where to open a chapter.
enum ChapterStart: Equatable {
    /// Progress through the chapter, 0...1.
    case fraction(Double)
    /// A 0-based page.
    case page(Int)
    /// The page containing the element with this id.
    case fragment(String)
    /// The page containing the `index`-th (0-based) occurrence of `query`.
    case match(query: String, index: Int)
    case lastPage
}

#if os(iOS)
extension ReaderWebEngine: UIGestureRecognizerDelegate {
    fileprivate func installSwipeRecognizers() {
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
            recognizer.direction = direction
            recognizer.delegate = self
            webView.addGestureRecognizer(recognizer)
        }
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        onSwipe(recognizer.direction == .left)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
#endif

extension ReaderWebEngine: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = ReaderEvent(messageBody: message.body) else { return }
        onEvent(event)
    }
}

extension ReaderWebEngine: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
            return .allow
        }
        onLinkActivated(url)
        return .cancel
    }
}

/// Breaks the retain cycle between the web view's content controller and the engine.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
