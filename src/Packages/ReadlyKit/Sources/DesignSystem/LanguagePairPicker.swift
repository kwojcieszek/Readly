import SwiftUI

/// "EN → PL": the fixed source language and a menu for the target language.
public struct LanguagePairPicker: View {
    public struct Option: Identifiable, Hashable, Sendable {
        public let code: String
        public let name: String
        public var id: String { code }

        public init(code: String, name: String) {
            self.code = code
            self.name = name
        }
    }

    private let sourceCode: String?
    @Binding private var targetCode: String
    private let options: [Option]

    public init(sourceCode: String?, targetCode: Binding<String>, options: [Option]) {
        self.sourceCode = sourceCode
        _targetCode = targetCode
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 8) {
            pill(Text(sourceCode?.uppercased() ?? "Auto"))
                .accessibilityLabel("Source language")
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Menu {
                Picker("Translate Into", selection: $targetCode) {
                    ForEach(options) { Text($0.name).tag($0.code) }
                }
                .pickerStyle(.inline)
            } label: {
                pill(HStack(spacing: 6) {
                    Text(targetCode.uppercased())
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
                })
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Translate into")
        }
    }

    private func pill(_ content: some View) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Theme.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.hairline) }
            .contentShape(Capsule())
    }
}
