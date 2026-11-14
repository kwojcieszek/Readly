import Foundation
import ReadlyCore

/// One place in the book where the searched text occurs.
struct BookSearchResult: Identifiable, Equatable, Sendable {
    let id: Int
    let query: String
    let chapterIndex: Int
    let chapterTitle: String
    /// 0-based occurrence of the query inside its chapter.
    let occurrence: Int
    /// The text around the match.
    let snippet: String
}

/// Full-text search over a book's chapters.
struct BookSearcher: Sendable {
    static let maximumResults = 200

    func search(_ query: String, in publication: Publication) async -> [BookSearchResult] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let pattern = words.map(NSRegularExpression.escapedPattern).joined(separator: "\\s+")
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }

        var results: [BookSearchResult] = []
        for (index, chapter) in publication.chapters.enumerated() {
            if Task.isCancelled || results.count >= Self.maximumResults { break }
            guard let data = try? Data(contentsOf: chapter.url) else { continue }
            let text = ChapterText.plainText(fromHTML: String(decoding: data, as: UTF8.self)) as NSString
            let matches = regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
            for (occurrence, match) in matches.enumerated() where results.count < Self.maximumResults {
                results.append(BookSearchResult(
                    id: results.count,
                    query: query,
                    chapterIndex: index,
                    chapterTitle: chapter.title ?? "Section \(index + 1)",
                    occurrence: occurrence,
                    snippet: Self.snippet(around: match.range, in: text)
                ))
            }
        }
        return results
    }

    private static func snippet(around range: NSRange, in text: NSString) -> String {
        let start = max(0, range.location - 50)
        let end = min(text.length, range.location + range.length + 70)
        let piece = text.substring(with: NSRange(location: start, length: end - start))
        let collapsed = piece.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return (start > 0 ? "…" : "") + collapsed + (end < text.length ? "…" : "")
    }
}

/// Reduces a chapter's HTML to the text a reader sees.
enum ChapterText {
    static func plainText(fromHTML html: String) -> String {
        var text = html
        if let body = text.range(of: "<body", options: .caseInsensitive) {
            text = String(text[body.lowerBound...])
        }
        for pattern in ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<!--[\\s\\S]*?-->", "<[^>]+>"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return decodeEntities(in: text)
    }

    private static let namedEntities = [
        "&nbsp;": "\u{00A0}", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
        "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&rsquo;": "’", "&lsquo;": "‘",
        "&rdquo;": "”", "&ldquo;": "“", "&amp;": "&",
    ]

    private static func decodeEntities(in text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        if let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            let source = result as NSString
            for match in regex.matches(in: result, range: NSRange(location: 0, length: source.length)).reversed() {
                let isHex = match.range(at: 1).length > 0
                guard let code = UInt32(source.substring(with: match.range(at: 2)), radix: isHex ? 16 : 10),
                      let scalar = Unicode.Scalar(code)
                else { continue }
                result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
            }
        }
        // `&amp;` goes last so that "&amp;lt;" stays "&lt;".
        for (entity, value) in namedEntities where entity != "&amp;" {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
