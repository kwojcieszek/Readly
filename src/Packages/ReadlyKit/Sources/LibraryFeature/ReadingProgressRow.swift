import DesignSystem
import SwiftUI

/// How much of a book has been read: a bar with "New", a percentage or "Finished".
struct ReadingProgressRow: View {
    let progress: Double
    let hasBeenOpened: Bool

    var body: some View {
        HStack(spacing: 8) {
            ProgressLine(value: progress)
            if isFinished {
                Label("Finished", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Theme.accent)
            } else {
                Text(label)
                    .monospacedDigit()
                    .foregroundStyle(hasBeenOpened ? Color.primary : Color.secondary)
            }
        }
        .font(.caption2.weight(.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFinished ? "Finished" : hasBeenOpened ? "\(label) read" : "Not started")
    }

    private var isFinished: Bool { progress >= 0.995 }

    private var label: String {
        hasBeenOpened ? progress.formatted(.percent.precision(.fractionLength(0))) : "New"
    }
}
