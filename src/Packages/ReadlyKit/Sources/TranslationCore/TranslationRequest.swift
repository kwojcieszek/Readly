import Foundation

public struct TranslationRequest: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case word
        case sentence
        case selection
    }

    public var kind: Kind
    public var text: String
    /// The sentence a word was taken from, used to pick the right meaning.
    public var context: String?
    /// English name of the language to translate into, e.g. "Polish".
    public var targetLanguage: String
    /// Language code of the text to translate, e.g. "en", if known.
    public var sourceLanguageCode: String?
    /// Language code of `targetLanguage`, e.g. "pl", for translators that work with codes.
    public var targetLanguageCode: String?

    public init(
        kind: Kind,
        text: String,
        context: String? = nil,
        targetLanguage: String,
        targetLanguageCode: String? = nil,
        sourceLanguageCode: String? = nil
    ) {
        self.kind = kind
        self.text = text
        self.context = context
        self.targetLanguage = targetLanguage
        self.targetLanguageCode = targetLanguageCode
        self.sourceLanguageCode = sourceLanguageCode
    }
}
