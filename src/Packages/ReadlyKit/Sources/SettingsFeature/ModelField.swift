import Preferences
import SwiftUI
import TranslationCore

/// Model id with quick picks for the selected provider.
struct ModelField: View {
    @Bindable var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            TextField("Model", text: binding, prompt: Text(settings.provider.defaultModel))
                .labelsHidden()
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            Menu("Choose Model", systemImage: "chevron.up.chevron.down") {
                ForEach(settings.provider.suggestedModels, id: \.self) { model in
                    Button(model) { settings.setModel(model, for: settings.provider) }
                }
            }
            .labelStyle(.iconOnly)
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
        }
        .settingsInput()
    }

    private var binding: Binding<String> {
        Binding {
            let model = settings.model(for: settings.provider)
            return model == settings.provider.defaultModel ? "" : model
        } set: {
            settings.setModel($0, for: settings.provider)
        }
    }
}
