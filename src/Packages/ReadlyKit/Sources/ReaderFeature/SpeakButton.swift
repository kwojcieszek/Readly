import DesignSystem
import SwiftUI

/// Plays the original text aloud; shows a stop button while it is being read.
struct SpeakButton: View {
    let title: String
    let isSpeaking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isSpeaking ? "Stop" : title, systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                .font(.caption.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(Theme.accent)
        .fixedSize()
        .help(isSpeaking ? "Stop reading" : "Read the original aloud")
        .accessibilityLabel(isSpeaking ? "Stop reading" : "Read \(title.lowercased()) aloud")
    }
}
