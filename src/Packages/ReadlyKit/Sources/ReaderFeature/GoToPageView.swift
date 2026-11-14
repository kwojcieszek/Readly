import DesignSystem
import SwiftUI

/// Jump to a page of the book by number.
struct GoToPageView: View {
    let currentPage: Int
    let totalPages: Int
    let onGo: (Int) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Page")
                .font(.headline)
            HStack(spacing: 10) {
                TextField("Page", text: $text, prompt: Text("\(currentPage)"))
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit(go)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("of \(totalPages)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Go", action: go)
                    .buttonStyle(.borderedProminent)
                    .disabled(target == nil)
            }
            Slider(value: sliderValue, in: 1...Double(max(2, totalPages)), step: 1)
                .disabled(totalPages < 2)
        }
        .padding(18)
        .frame(width: 300)
        .tint(Theme.accent)
        .onAppear { isFocused = true }
    }

    private var target: Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), (1...totalPages).contains(value) else {
            return nil
        }
        return value
    }

    private var sliderValue: Binding<Double> {
        Binding {
            Double(target ?? currentPage)
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
