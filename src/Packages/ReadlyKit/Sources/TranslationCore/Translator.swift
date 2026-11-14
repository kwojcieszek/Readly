import Foundation

public protocol Translating: Sendable {
    func translate(_ request: TranslationRequest) async throws -> String
}

/// Translates by prompting an LLM.
public struct LLMTranslator: Translating {
    private let client: any LLMClient
    private let promptBuilder: TranslationPromptBuilder

    public init(client: any LLMClient, promptBuilder: TranslationPromptBuilder = .init()) {
        self.client = client
        self.promptBuilder = promptBuilder
    }

    public func translate(_ request: TranslationRequest) async throws -> String {
        let prompt = promptBuilder.prompt(for: request)
        let answer = try await client.complete(system: prompt.system, user: prompt.user)
        let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw TranslationError.emptyResponse }
        return cleaned
    }
}

/// Builds a ready-to-use translator from the user's provider configuration.
public struct TranslatorFactory: Sendable {
    private let keyStore: any APIKeyStoring
    private let transport: any HTTPTransport
    private let systemTranslator: (any Translating)?

    /// - Parameter systemTranslator: Serves `.apple`; the app supplies it because it needs the UI.
    public init(
        keyStore: any APIKeyStoring,
        transport: any HTTPTransport = URLSessionTransport(),
        systemTranslator: (any Translating)? = nil
    ) {
        self.keyStore = keyStore
        self.transport = transport
        self.systemTranslator = systemTranslator
    }

    public func makeTranslator(provider: TranslationProviderKind, model: String) throws -> any Translating {
        guard provider.usesAPIKey else {
            guard let systemTranslator else { throw TranslationError.systemTranslationUnavailable }
            return systemTranslator
        }
        guard let key = keyStore.apiKey(for: provider), !key.isEmpty else {
            throw TranslationError.missingAPIKey(provider)
        }
        guard let client = LLMClientFactory.makeClient(for: provider, apiKey: key, model: model, transport: transport) else {
            throw TranslationError.systemTranslationUnavailable
        }
        return LLMTranslator(client: client)
    }
}
