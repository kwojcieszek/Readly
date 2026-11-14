import SwiftUI
import WebKit

#if os(macOS)
struct ReaderWebView: NSViewRepresentable {
    let engine: ReaderWebEngine

    func makeNSView(context: Context) -> WKWebView { engine.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
struct ReaderWebView: UIViewRepresentable {
    let engine: ReaderWebEngine

    func makeUIView(context: Context) -> WKWebView { engine.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
