import DesignSystem
import SwiftUI
import SystemTranslation

/// Explains the built-in translator and whether it handles the chosen language.
struct SystemTranslationNote: View {
    let targetCode: String
    @State private var isSupported: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Translates on this device with Apple’s built-in translator. Free, private, no API key.", systemImage: "lock.shield")
            Text("The first translation into a language may ask to download it. \(managementHint)")
                .foregroundStyle(.secondary)
            if isSupported == false {
                Label("The built-in translator doesn’t support this language. Pick another one or an AI provider.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Text("Single words are translated without the dictionary meanings an AI provider gives.")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: targetCode) { isSupported = await SystemLanguageSupport.supports(targetCode: targetCode) }
    }

    private var managementHint: String {
        #if os(macOS)
        "Downloaded languages are listed in System Settings › General › Language & Region › Translation Languages."
        #else
        "Downloaded languages are listed in Settings › Apps › Translate › Downloaded Languages."
        #endif
    }
}
