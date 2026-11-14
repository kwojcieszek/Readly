import Foundation
import Observation
import Preferences
import TranslationCore

/// Translates free text typed into the translator screen.
@MainActor
@Observable
final class QuickTranslator {
    enum Phase: Equatable {
        case idle
        case loading
        case translated(source: String, output: TranslationOutput)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let factory: TranslatorFactory
    @ObservationIgnored private var task: Task<Void, Never>?

    init(settings: AppSettings, factory: TranslatorFactory) {
        self.settings = settings
        self.factory = factory
    }

    func translate(_ text: String) {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        task?.cancel()
        phase = .loading
        let provider = settings.provider
        let model = settings.model(for: provider)
        let isWord = !source.contains(where: \.isWhitespace)
        let request = TranslationRequest(
            kind: isWord ? .word : .selection,
            text: source,
            targetLanguage: settings.targetLanguage.englishName,
            targetLanguageCode: settings.targetLanguageCode
        )
        task = Task { [factory] in
            let result: Phase
            do {
                let translator = try factory.makeTranslator(provider: provider, model: model)
                let answer = try await translator.translate(request)
                result = .translated(source: source, output: TranslationOutput(parsing: answer))
            } catch is CancellationError {
                return
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled else { return }
            phase = result
        }
    }

    func reset() {
        task?.cancel()
        phase = .idle
    }
}
