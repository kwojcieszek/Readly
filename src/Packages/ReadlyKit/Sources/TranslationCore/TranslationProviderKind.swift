import Foundation

public enum TranslationProviderKind: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The translator built into iOS and macOS: on device, free, no API key.
    case apple
    case openAI
    case anthropic
    case gemini

    public var id: String { rawValue }

    /// LLM providers need a key; the system translator does not.
    public var usesAPIKey: Bool { self != .apple }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Claude (Anthropic)"
        case .gemini: "Google Gemini"
        case .apple: "Apple Translate"
        }
    }

    public var defaultModel: String {
        switch self {
        case .openAI: "gpt-4.1-mini"
        case .anthropic: "claude-opus-5-5"
        case .gemini: "gemini-2.5-flash"
        case .apple: ""
        }
    }

    /// Models offered as quick picks; any other model id can be typed in.
    public var suggestedModels: [String] {
        switch self {
        case .openAI: ["gpt-4.1-mini", "gpt-4.1", "gpt-5-mini"]
        case .anthropic: ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
        case .gemini: ["gemini-2.5-flash", "gemini-2.5-pro"]
        case .apple: []
        }
    }

    /// Where the user can create an API key.
    public var apiKeyURL: URL? {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://platform.claude.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        case .apple: nil
        }
    }
}
