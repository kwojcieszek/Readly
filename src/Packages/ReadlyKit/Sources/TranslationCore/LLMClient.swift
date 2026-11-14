import Foundation

/// A minimal single-turn text completion interface over an LLM API.
public protocol LLMClient: Sendable {
    func complete(system: String, user: String) async throws -> String
}

public enum LLMClientFactory {
    public static func makeClient(
        for provider: TranslationProviderKind,
        apiKey: String,
        model: String,
        transport: any HTTPTransport = URLSessionTransport()
    ) -> (any LLMClient)? {
        let model = model.trimmingCharacters(in: .whitespaces).isEmpty ? provider.defaultModel : model
        return switch provider {
        case .openAI: OpenAIClient(apiKey: apiKey, model: model, transport: transport)
        case .anthropic: AnthropicClient(apiKey: apiKey, model: model, transport: transport)
        case .gemini: GeminiClient(apiKey: apiKey, model: model, transport: transport)
        case .apple: nil
        }
    }
}
