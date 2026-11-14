import Foundation

/// Book formats the app knows about. Add a case here and register a
/// `BookFormatHandler` to support a new format.
public enum BookFormat: String, Codable, Sendable, CaseIterable {
    case epub
    case pdf

    public var fileExtensions: [String] {
        switch self {
        case .epub: ["epub"]
        case .pdf: ["pdf"]
        }
    }
}
