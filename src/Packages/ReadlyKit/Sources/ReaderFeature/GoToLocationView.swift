import DesignSystem
import SwiftUI

/// Jump to a numbered location in the book.
struct GoToLocationView: View {
    let currentLocation: Int
    let totalLocations: Int
    let onGo: (Int) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Location")
                .font(.headline)
            HStack(spacing: 10) {
                TextField("Location", text: $text, prompt: Text("\(currentLocation)"))
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit(go)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("of \(totalLocations)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Go", action: go)
                    .buttonStyle(.borderedProminent)
                    .disabled(target == nil)
            }
            Slider(value: sliderValue, in: 1...Double(max(2, totalLocations)), step: 1)
                .disabled(totalLocations < 2)
                .accessibilityLabel("Location")
        }
        .padding(18)
        .frame(width: 300)
        .tint(Theme.accent)
        .defaultFocus($isFocused, true)
    }

    private var target: Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), (1...totalLocations).contains(value) else {
            return nil
        }
        return value
    }

    private var sliderValue: Binding<Double> {
        Binding {
            Double(target ?? currentLocation)
        } set: {
            text = String(Int($0))
        }
    }

    private func go() {
        guard let target else { return }
        onGo(target)
        dismiss()
    }
}
