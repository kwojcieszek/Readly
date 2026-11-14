import SwiftUI

/// Arrow keys turn pages even when the page itself does not have the keyboard focus.
struct PageTurnShortcuts: View {
    let model: ReaderViewModel

    var body: some View {
        Group {
            Button("Previous Page") { model.turnPage(forward: false) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!model.canTurnBack)
            Button("Next Page") { model.turnPage(forward: true) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!model.canTurnForward)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
