import Foundation

public struct TranslationPrompt: Sendable, Equatable {
    public let system: String
    public let user: String
}

public struct TranslationPromptBuilder: Sendable {
    public init() {}

    public func prompt(for request: TranslationRequest) -> TranslationPrompt {
        let language = request.targetLanguage
        let system = """
        You are a translator built into an e-book reader. Translate into \(language). \
        Detect the source language yourself. Reply with the translation only: no quotes, \
        no explanations, no notes, no source text.
        """

        let user: String
        switch request.kind {
        case .word:
            if let context = request.context, !context.isEmpty {
                user = """
                Translate the word "\(request.text)" into \(language) as it is used in this sentence:
                "\(context)"
                Give the meaning that fits the sentence. If other meanings are common, add at most \
                two more, separated by commas.
                """
            } else {
                user = """
                Translate the word "\(request.text)" into \(language). Give at most three common \
                meanings, separated by commas.
                """
            }
        case .sentence, .selection:
            user = """
            Translate the text below into \(language), keeping its tone. After the translation \
            write a line containing only \(TranslationOutput.separator) and then up to four of the \
            text's less common words, one per line, in their dictionary form, as: \
            word = meaning, meaning (meanings in \(language)).

            \(request.text)
            """
        }
        return TranslationPrompt(system: system, user: user)
    }
}
