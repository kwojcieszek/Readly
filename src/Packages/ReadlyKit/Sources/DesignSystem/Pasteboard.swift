#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Copies text to the system clipboard.
@MainActor
public enum Pasteboard {
    public static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
