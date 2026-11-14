import SwiftUI
@preconcurrency import Translation

/// Gives the bridge access to the system translator from a view that stays on screen.
struct SystemTranslationHost: ViewModifier {
    let bridge: SystemTranslationBridge

    func body(content: Content) -> some View {
        content
            .translationTask(bridge.configuration) { session in
                await bridge.run(session)
            }
            .onAppear(perform: bridge.hostAppeared)
            .onDisappear(perform: bridge.hostDisappeared)
    }
}

extension View {
    /// Lets `SystemTranslator` translate while this view is shown; put it on a root view.
    public func systemTranslationHost(_ bridge: SystemTranslationBridge) -> some View {
        modifier(SystemTranslationHost(bridge: bridge))
    }
}
