import DesignSystem
import LibraryData
import Preferences
import Speech
import SwiftData
import SwiftUI
import TranslationCore

/// A standalone translator plus the phrases starred while reading.
public struct TranslatorView: View {
    @Query(sort: \SavedPhrase.createdAt, order: .reverse) private var phrases: [SavedPhrase]

    @Bindable private var settings: AppSettings
    private let library: BookLibrary
    @State private var translator: QuickTranslator
    @State private var speech = SpeechPlayer()
    @State private var text = ""

    public init(settings: AppSettings, translatorFactory: TranslatorFactory, library: BookLibrary) {
        self.settings = settings
        self.library = library
        _translator = State(initialValue: QuickTranslator(settings: settings, factory: translatorFactory))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LanguagePairPicker(
                    sourceCode: nil,
                    targetCode: $settings.targetLanguageCode,
                    options: TargetLanguage.all.map { .init(code: $0.code, name: $0.displayName) }
                )
                inputCard
                resultCard
                savedPhrases
            }
            .frame(maxWidth: 620)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("Translator")
        .tint(Theme.accent)
        .onDisappear { speech.stop() }
    }

    private var inputCard: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextField("Type or paste text to translate", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...8)
            HStack {
                if !text.isEmpty {
                    Button("Clear") {
                        text = ""
                        translator.reset()
                    }
                    .buttonStyle(.borderless)
                }
                Button("Translate", systemImage: "translate") { translator.translate(text) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .card()
    }

    @ViewBuilder private var resultCard: some View {
        switch translator.phase {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Translating…").foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        case .translated(let source, let output):
            VStack(alignment: .leading, spacing: 10) {
                Text(output.text)
                    .font(.title3.weight(.medium))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(output.glossary) { entry in
                    Text("\(Text(entry.term).fontWeight(.semibold)) — \(entry.meanings)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    IconButton("Copy", systemImage: "doc.on.doc") { Pasteboard.copy(output.text) }
                    IconButton(
                        speech.isSpeaking(source) ? "Stop" : "Listen to the Original",
                        systemImage: speech.isSpeaking(source) ? "stop.fill" : "speaker.wave.2",
                        isActive: speech.isSpeaking(source)
                    ) { speak(source) }
                    IconButton(
                        isSaved(source, output.text) ? "Remove from Saved Phrases" : "Save Phrase",
                        systemImage: isSaved(source, output.text) ? "star.fill" : "star",
                        isActive: isSaved(source, output.text)
                    ) { toggleSaved(source, output.text) }
                    Spacer()
                }
            }
            .padding(14)
            .card()
        }
    }

    @ViewBuilder private var savedPhrases: some View {
        Text("Saved Phrases")
            .font(.headline)
            .padding(.top, 8)
        if phrases.isEmpty {
            Text("Star a translation while reading to keep it here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                    if index > 0 { Divider() }
                    SavedPhraseRow(
                        phrase: phrase,
                        isSpeaking: speech.isSpeaking(phrase.source),
                        onSpeak: { speak(phrase.source) },
                        onDelete: { library.removePhrase(phrase) }
                    )
                }
            }
            .padding(.horizontal, 14)
            .card()
        }
    }

    private func speak(_ text: String) {
        speech.toggle(text, language: LanguageGuesser.language(of: text, declared: nil))
    }

    private func isSaved(_ source: String, _ translation: String) -> Bool {
        phrases.contains { $0.source == source && $0.translation == translation }
    }

    private func toggleSaved(_ source: String, _ translation: String) {
        if let saved = phrases.first(where: { $0.source == source && $0.translation == translation }) {
            library.removePhrase(saved)
        } else {
            library.savePhrase(source: source, translation: translation)
        }
    }
}
