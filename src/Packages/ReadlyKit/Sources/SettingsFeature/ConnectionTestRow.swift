import DesignSystem
import Preferences
import SwiftUI
import TranslationCore

struct ConnectionTestRow: View {
    let settings: AppSettings
    let factory: TranslatorFactory
    let tester: ConnectionTester

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                Task {
                    await tester.run(
                        provider: settings.provider,
                        model: settings.model(for: settings.provider),
                        language: settings.targetLanguage,
                        factory: factory
                    )
                }
            } label: {
                Label(settings.provider.usesAPIKey ? "Test Connection" : "Test Translation", systemImage: "bolt.horizontal")
            }
            .buttonStyle(.bordered)
            .disabled(tester.state == .testing)

            switch tester.state {
            case .idle:
                EmptyView()
            case .testing:
                ProgressView().controlSize(.small)
            case .succeeded(let sample):
                Label("Works: “\(sample)”", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.callout)
        .lineLimit(3)
    }
}
