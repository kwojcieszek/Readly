import DesignSystem
import Preferences
import SwiftUI
import TranslationCore

/// The translation of the tapped text, with its languages, actions and a small dictionary.
struct TranslationPanel: View {
    struct Actions {
        var speak: (String) -> Void
        var toggleSaved: () -> Void
        var translateSentence: () -> Void
        var openSettings: () -> Void
        var close: () -> Void
    }

    let display: TranslationDisplay?
    let sourceLanguageCode: String?
    @Bindable var settings: AppSettings
    let isSaved: Bool
    let isSpeaking: (String) -> Bool
    let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Translation").font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark", action: actions.close)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }

            LanguagePairPicker(
                sourceCode: sourceLanguageCode,
                targetCode: $settings.targetLanguageCode,
                options: TargetLanguage.all.map { .init(code: $0.code, name: $0.displayName) }
            )

            if let display {
                TranslationResultCard(
                    display: display,
                    isSaved: isSaved,
                    isSpeaking: isSpeaking(display.source),
                    actions: actions
                )
                DictionaryCard(display: display, onTranslateSentence: actions.translateSentence)
            } else {
                Text("Tap a word to translate it. Double-tap to translate the whole sentence.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        }
    }
}

/// The translated text and what can be done with it.
private struct TranslationResultCard: View {
    let display: TranslationDisplay
    let isSaved: Bool
    let isSpeaking: Bool
    let actions: TranslationPanel.Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(display.source)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                result
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                IconButton("Copy Translation", systemImage: "doc.on.doc") {
                    Pasteboard.copy(display.translatedText ?? display.source)
                }
                Spacer()
                IconButton(
                    isSpeaking ? "Stop" : "Listen to the Original",
                    systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2",
                    isActive: isSpeaking
                ) { actions.speak(display.source) }
                Spacer()
                IconButton(
                    isSaved ? "Remove from Saved Phrases" : "Save Phrase",
                    systemImage: isSaved ? "star.fill" : "star",
                    isActive: isSaved,
                    action: actions.toggleSaved
                )
                .disabled(display.translatedText == nil)
                Spacer()
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
                .help("Share")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .card()
    }

    @ViewBuilder private var result: some View {
        switch display.phase {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Translating…").foregroundStyle(.secondary)
            }
            .font(.callout)
        case .translated(let output):
            ScrollView {
                Text(output.text)
                    .font(.body.weight(.medium))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .fixedSize(horizontal: false, vertical: true)
        case .failed(let message, let needsAPIKey):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                if needsAPIKey {
                    Button("Open Settings", action: actions.openSettings)
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                }
            }
        }
    }

    private var shareText: String {
        guard let translation = display.translatedText else { return display.source }
        return "\(display.source)\n\(translation)"
    }
}

/// Key words of a translated passage, or the sentence a translated word comes from.
private struct DictionaryCard: View {
    let display: TranslationDisplay
    let onTranslateSentence: () -> Void

    var body: some View {
        if display.kind == .word, let sentence = display.context, sentence != display.source {
            section("In Context") {
                Text(sentence).font(.callout).foregroundStyle(.secondary)
                Button("Translate Sentence", systemImage: "text.quote", action: onTranslateSentence)
                    .buttonStyle(.borderless)
                    .font(.footnote.weight(.semibold))
                    .tint(Theme.accent)
            }
        } else if case .translated(let output) = display.phase, !output.glossary.isEmpty {
            section("Dictionary") {
                ForEach(Array(output.glossary.enumerated()), id: \.element) { index, entry in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.term).font(.callout.weight(.semibold))
                        Text(entry.meanings).font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
