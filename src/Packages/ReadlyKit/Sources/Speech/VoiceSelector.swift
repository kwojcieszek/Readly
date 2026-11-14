import Foundation

/// Picks the voice for a language from the installed voices.
///
/// Prefers the exact language and region, then the same language with the
/// user's region, then any voice of that language; better quality wins ties.
public struct VoiceSelector: Sendable {
    public struct Candidate: Sendable, Equatable {
        public var identifier: String
        /// BCP 47 tag, e.g. "en-US".
        public var language: String
        /// Higher is better.
        public var quality: Int

        public init(identifier: String, language: String, quality: Int) {
            self.identifier = identifier
            self.language = language
            self.quality = quality
        }
    }

    private let candidates: [Candidate]
    private let preferredRegion: String?

    public init(candidates: [Candidate], preferredRegion: String? = Locale.current.region?.identifier) {
        self.candidates = candidates
        self.preferredRegion = preferredRegion?.uppercased()
    }

    /// The identifier of the best voice for `language`, or `nil` if none speaks it.
    public func voice(for language: String) -> String? {
        let wanted = Tag(language)
        let matching = candidates.filter { Tag($0.language).language == wanted.language }
        return matching.max { score($0, wanted) < score($1, wanted) }?.identifier
    }

    private func score(_ candidate: Candidate, _ wanted: Tag) -> Int {
        let region = Tag(candidate.language).region
        var score = candidate.quality
        if let wantedRegion = wanted.region, region == wantedRegion {
            score += 100
        } else if let preferredRegion, region == preferredRegion {
            score += 50
        }
        return score
    }

    private struct Tag {
        var language: String
        var region: String?

        init(_ tag: String) {
            let parts = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-")
            language = parts.first.map { $0.lowercased() } ?? ""
            // A region is the two-letter or three-digit subtag after the language (and script).
            region = parts.dropFirst()
                .first { $0.count == 2 || ($0.count == 3 && $0.allSatisfy(\.isNumber)) }
                .map { $0.uppercased() }
        }
    }
}
