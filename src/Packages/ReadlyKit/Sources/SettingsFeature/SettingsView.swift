import DesignSystem
import Preferences
import Speech
import SwiftUI
import TranslationCore

public struct SettingsView: View {
    @Environment(\.locale) private var locale
    @Bindable private var settings: AppSettings
    private let keyStore: any APIKeyStoring
    private let translatorFactory: TranslatorFactory
    private let showsDoneButton: Bool

    @State private var tester = ConnectionTester()
    @Environment(\.dismiss) private var dismiss

    public init(
        settings: AppSettings,
        keyStore: any APIKeyStoring,
        translatorFactory: TranslatorFactory,
        showsDoneButton: Bool = true
    ) {
        self.settings = settings
        self.keyStore = keyStore
        self.translatorFactory = translatorFactory
        self.showsDoneButton = showsDoneButton
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                languageCard
                appThemeCard
                translationCard
                readingCard
                speechCard
            }
            .frame(maxWidth: 560)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .tint(Theme.accent)
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: settings.provider) { tester.reset() }
        .onChange(of: settings.targetLanguageCode) { tester.reset() }
    }

    private var languageCard: some View {
        SettingsCard(title: "App Language", systemImage: "globe") {
            Picker("App Language", selection: $settings.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(LocalizedStringKey(language.displayName)).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appThemeCard: some View {
        SettingsCard(title: "App Theme", systemImage: "circle.lefthalf.filled") {
            Picker("App Theme", selection: $settings.appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var translationCard: some View {
        SettingsCard(
            title: "Translation",
            subtitle: "Tap a word, double-tap a sentence",
            systemImage: "character.bubble.fill"
        ) {
            ProviderPicker(selection: $settings.provider)

            if settings.provider.usesAPIKey {
                SettingsField(label: "API Key") {
                    APIKeyField(provider: settings.provider, keyStore: keyStore)
                }
            } else {
                SystemTranslationNote(targetCode: settings.targetLanguageCode)
            }

            HStack(alignment: .top, spacing: 12) {
                if settings.provider.usesAPIKey {
                    SettingsField(label: "Model") {
                        ModelField(settings: settings)
                    }
                }
                SettingsField(label: "Translate Into") {
                    Picker("Translate Into", selection: $settings.targetLanguageCode) {
                        ForEach(TargetLanguage.all) { Text($0.displayName(in: locale)).tag($0.code) }
                    }
                    .settingsMenuPicker()
                }
            }

            ConnectionTestRow(settings: settings, factory: translatorFactory, tester: tester)
        }
    }

    private var speechCard: some View {
        SettingsCard(title: "Read Aloud", systemImage: "speaker.wave.2") {
            SettingsField(label: "Voice Quality") {
                Picker("Voice Quality", selection: $settings.voiceQuality) {
                    ForEach(VoiceQuality.allCases, id: \.self) { quality in
                        Text(verbatim: quality.rawValue).tag(quality)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var readingCard: some View {
        SettingsCard(
            title: "Reading",
            subtitle: "How books look on the page",
            systemImage: "textformat.size"
        ) {
            ReadingPreview(settings: settings)

            SettingsField(label: "Theme") {
                ThemePicker(selection: $settings.theme)
            }

            SettingsField(label: "Text Size · \(settings.fontSize)%") {
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                    Slider(
                        value: $settings.fontSize.asDouble,
                        in: ReaderFontSize.range.asDouble,
                        step: Double(ReaderFontSize.step)
                    )
                    Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
                }
            }

            SettingsField(label: "Font") {
                Picker("Font", selection: $settings.font) {
                    ForEach(ReaderFont.allCases) { Text(LocalizedStringKey($0.displayName)).tag($0) }
                }
                .settingsMenuPicker()
            }

            marginSlider(
                "Top & Bottom Margins · \(settings.verticalMargin) px",
                value: $settings.verticalMargin
            )
            marginSlider(
                "Left & Right Margins · \(settings.horizontalMargin) px",
                value: $settings.horizontalMargin
            )
        }
    }

    private func marginSlider(_ label: LocalizedStringKey, value: Binding<Int>) -> some View {
        SettingsField(label: label) {
            Slider(value: value.asDouble, in: ReaderMargin.range.asDouble, step: Double(ReaderMargin.step)) {
                Text(label)
            }
            .labelsHidden()
        }
    }
}
