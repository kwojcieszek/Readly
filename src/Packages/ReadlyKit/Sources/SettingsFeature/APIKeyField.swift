import DesignSystem
import SwiftUI
import TranslationCore

/// Edits the encrypted API key of one provider.
struct APIKeyField: View {
    let provider: TranslationProviderKind
    let keyStore: any APIKeyStoring

    @State private var key = ""
    @State private var isRevealed = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField("API Key", text: $key, prompt: Text("Paste your \(provider.shortName) key"))
                    } else {
                        SecureField("API Key", text: $key, prompt: Text("Paste your \(provider.shortName) key"))
                    }
                }
                .labelsHidden()
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                Button(isRevealed ? "Hide Key" : "Show Key", systemImage: isRevealed ? "eye.slash" : "eye") {
                    isRevealed.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .settingsInput()

            status
        }
        .task(id: provider) {
            key = keyStore.apiKey(for: provider) ?? ""
            isRevealed = false
            errorMessage = nil
        }
        .onChange(of: key) { _, newValue in save(newValue) }
    }

    @ViewBuilder private var status: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        } else if key.isEmpty {
            HStack(spacing: 4) {
                Text("No key yet.").foregroundStyle(.secondary)
                if let url = provider.apiKeyURL {
                    Link("Get one from \(provider.shortName)", destination: url)
                }
            }
            .font(.caption)
        } else {
            Label("Encrypted in Readly settings, sent only to \(provider.shortName)", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save(_ value: String) {
        guard value != (keyStore.apiKey(for: provider) ?? "") else { return }
        do {
            try keyStore.setAPIKey(value, for: provider)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
