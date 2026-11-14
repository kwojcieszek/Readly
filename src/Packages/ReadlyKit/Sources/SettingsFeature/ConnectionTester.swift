import Foundation
import Observation
import TranslationCore

/// Sends a tiny translation to verify the provider, key and model work.
@MainActor
@Observable
final class ConnectionTester {
    enum State: Equatable {
        case idle
        case testing
        case succeeded(String)
        case failed(String)
    }

    private(set) var state: State = .idle

    func reset() {
        state = .idle
    }

    func run(provider: TranslationProviderKind, model: String, language: TargetLanguage, factory: TranslatorFactory) async {
        state = .testing
        let request = TranslationRequest(
            kind: .sentence,
            text: "Good morning!",
            targetLanguage: language.englishName,
            targetLanguageCode: language.code,
            sourceLanguageCode: "en"
        )
        do {
            let translator = try factory.makeTranslator(provider: provider, model: model)
            state = .succeeded(try await translator.translate(request))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
