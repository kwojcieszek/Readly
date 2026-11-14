import Foundation

/// What the converter learned about a PDF, stored next to the generated chapters.
struct PDFManifest: Codable, Equatable {
    struct Chapter: Codable, Equatable {
        var file: String
        var title: String
    }

    struct Entry: Codable, Equatable {
        var title: String
        var file: String
        var fragment: String?
        var level: Int
    }

    static let fileName = "readly-pdf.json"

    var title: String
    var author: String
    var language: String?
    var cover: String?
    var chapters: [Chapter]
    var tableOfContents: [Entry]

    func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: directory.appending(path: Self.fileName), options: .atomic)
    }

    static func read(from directory: URL) throws -> PDFManifest {
        guard let data = try? Data(contentsOf: directory.appending(path: fileName)) else {
            throw PDFBookError.notConverted
        }
        return try JSONDecoder().decode(PDFManifest.self, from: data)
    }
}

public enum PDFBookError: LocalizedError, Equatable {
    case unreadable
    case locked
    case empty
    case notConverted

    public var errorDescription: String? {
        switch self {
        case .unreadable: "The file is not a readable PDF."
        case .locked: "The PDF is password-protected."
        case .empty: "The PDF has no pages."
        case .notConverted: "The book’s files are incomplete. Remove it and add it again."
        }
    }
}
