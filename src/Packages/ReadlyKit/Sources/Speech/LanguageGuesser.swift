import NaturalLanguage

/// Decides which language a passage should be read in.
public enum LanguageGuesser {
    /// The book's declared language, or the language detected in `text` when the book has none.
    public static func language(of text: String, declared: String?) -> String? {
        if let declared = declared?.trimmingCharacters(in: .whitespaces), !declared.isEmpty {
            return declared
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }
}
