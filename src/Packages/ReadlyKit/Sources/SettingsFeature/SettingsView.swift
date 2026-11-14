import DesignSystem
import Preferences
import SwiftUI
import TranslationCore

public struct SettingsView: View {
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
                translationCard
                readingCard
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
                        ForEach(TargetLanguage.all) { Text($0.displayName).tag($0.code) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 36)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }

            ConnectionTestRow(settings: settings, factory: translatorFactory, tester: tester)
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
                    Slider(value: fontSize, in: fontSizeRange, step: Double(ReaderFontSize.step))
                    Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
                }
            }

            SettingsField(label: "Font") {
                Picker("Font", selection: $settings.font) {
                    ForEach(ReaderFont.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .frame(minHeight: 36)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }

    private var fontSizeRange: ClosedRange<Double> {
        Double(ReaderFontSize.range.lowerBound)...Double(ReaderFontSize.range.upperBound)
    }

    private var fontSize: Binding<Double> {
        Binding { Double(settings.fontSize) } set: { settings.fontSize = Int($0.rounded()) }
    }
}
