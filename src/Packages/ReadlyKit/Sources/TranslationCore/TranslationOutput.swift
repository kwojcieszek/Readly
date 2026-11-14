import Foundation

/// A word from the translated passage with its meanings.
public struct GlossaryEntry: Sendable, Hashable, Identifiable {
    public var term: String
    public var meanings: String

    public var id: String { term }

    public init(term: String, meanings: String) {
        self.term = term
        self.meanings = meanings
    }
}

/// A translator's answer, split into the translation and an optional glossary.
///
/// Passages are answered as the translation, a line of dashes, then one
/// `word = meaning, meaning` line per key word.
public struct TranslationOutput: Sendable, Equatable {
    public static let separator = "---"

    public var text: String
    public var glossary: [GlossaryEntry]

    public init(text: String, glossary: [GlossaryEntry] = []) {
        self.text = text
        self.glossary = glossary
    }

    public init(parsing answer: String) {
        let lines = answer.components(separatedBy: .newlines)
        guard let split = lines.firstIndex(where: Self.isSeparator) else {
            self.init(text: answer.trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }
        let text = lines[..<split].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        let glossary = lines[(split + 1)...].compactMap(Self.entry).filter { seen.insert($0.term.lowercased()).inserted }
        self.init(text: text, glossary: glossary)
    }

    private static func isSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.allSatisfy { $0 == "-" }
    }

    private static func entry(_ line: String) -> GlossaryEntry? {
        guard let equals = line.firstIndex(of: "=") else { return nil }
        let bullets = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-•*"))
        let term = line[..<equals].trimmingCharacters(in: bullets)
        let meanings = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !meanings.isEmpty else { return nil }
        return GlossaryEntry(term: term, meanings: meanings)
    }
}
