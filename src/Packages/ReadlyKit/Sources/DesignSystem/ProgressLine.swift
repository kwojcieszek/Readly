import SwiftUI

/// A thin, unobtrusive progress indicator.
public struct ProgressLine: View {
    private let value: Double

    public init(value: Double) {
        self.value = min(1, max(0, value))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.22))
                Capsule().fill(Theme.accent).frame(width: proxy.size.width * value)
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Reading progress")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}
