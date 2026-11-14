import Foundation

public enum TranslationError: LocalizedError, Equatable {
    case missingAPIKey(TranslationProviderKind)
    case http(status: Int, message: String)
    case refused
    case emptyResponse
    case network(String)
    /// The system translator cannot be used right now.
    case systemTranslationUnavailable
    /// The system translator failed with this message.
    case system(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "Add your \(provider.displayName) API key in Settings to translate."
        case .http(let status, let message):
            message.isEmpty ? "The translation service returned error \(status)." : "\(message) (\(status))"
        case .refused:
            "The model declined to translate this text."
        case .emptyResponse:
            "The translation service returned an empty answer."
        case .network(let message), .system(let message):
            message
        case .systemTranslationUnavailable:
            "The built-in translator isn’t available right now. Try again in a moment."
        }
    }
}
