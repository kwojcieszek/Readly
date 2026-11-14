import Foundation
import Observation
import Preferences
import TranslationCore

struct TranslationDisplay: Equatable {
    enum Phase: Equatable {
        case loading
        case translated(TranslationOutput)
        case failed(message: String, needsAPIKey: Bool)
    }

    var source: String
    /// The sentence around a translated word.
    var context: String?
    var kind: TranslationRequest.Kind
    var providerName: String
    var phase: Phase

    /// The finished translation, if there is one.
    var translatedText: String? {
        if case .translated(let output) = phase { output.text } else { nil }
    }
}

/// Runs translations for the reader and exposes what the panel should show.
@MainActor
@Observable
final class TranslationController {
    private(set) var display: TranslationDisplay?
    /// The book's language, if it declares one.
    @ObservationIgnored var sourceLanguageCode: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let factory: TranslatorFactory
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var cache: [CacheKey: TranslationOutput] = [:]

    init(settings: AppSettings, factory: TranslatorFactory) {
        self.settings = settings
        self.factory = factory
    }

    func translate(kind: TranslationRequest.Kind, text: String, context: String?) {
        task?.cancel()
        let provider = settings.provider
        let model = settings.model(for: provider)
        let request = TranslationRequest(
            kind: kind,
            text: text,
            context: context,
            targetLanguage: settings.targetLanguage.englishName,
            targetLanguageCode: settings.targetLanguageCode,
            sourceLanguageCode: sourceLanguageCode
        )
        let key = CacheKey(request: request, provider: provider, model: model)
        var display = TranslationDisplay(source: text, context: context, kind: kind, providerName: provider.displayName, phase: .loading)

        if let cached = cache[key] {
            display.phase = .translated(cached)
            self.display = display
            return
        }
        self.display = display

        task = Task { [factory] in
            let phase: TranslationDisplay.Phase
            do {
                let translator = try factory.makeTranslator(provider: provider, model: model)
                let result = TranslationOutput(parsing: try await translator.translate(request))
                cache[key] = result
                phase = .translated(result)
            } catch is CancellationError {
                return
            } catch let error as TranslationError {
                var needsKey = false
                if case .missingAPIKey = error { needsKey = true }
                phase = .failed(message: error.localizedDescription, needsAPIKey: needsKey)
            } catch {
                phase = .failed(message: error.localizedDescription, needsAPIKey: false)
            }
            guard !Task.isCancelled else { return }
            display.phase = phase
            self.display = display
        }
    }

    /// Runs the shown translation again, e.g. after the target language changed.
    func retranslate() {
        guard let display else { return }
        translate(kind: display.kind, text: display.source, context: display.context)
    }

    func dismiss() {
        task?.cancel()
        task = nil
        display = nil
    }

    private struct CacheKey: Hashable {
        let request: TranslationRequest
        let provider: TranslationProviderKind
        let model: String
    }
}
