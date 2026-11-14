import Foundation

public struct BookMetadata: Sendable, Equatable {
    public var title: String
    public var author: String
    public var language: String?

    public init(title: String, author: String, language: String? = nil) {
        self.title = title
        self.author = author
        self.language = language
    }
}

/// One readable document of a publication, in reading order.
public struct Chapter: Sendable, Identifiable, Equatable {
    public let id: String
    public let url: URL
    public let title: String?

    public init(id: String, url: URL, title: String?) {
        self.id = id
        self.url = url
        self.title = title
    }
}

public struct TOCEntry: Sendable, Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let url: URL
    public let fragment: String?
    public let level: Int

    public init(id: Int, title: String, url: URL, fragment: String?, level: Int) {
        self.id = id
        self.title = title
        self.url = url
        self.fragment = fragment
        self.level = level
    }
}

/// A format-independent, ready-to-render book: HTML chapters on disk plus navigation.
public struct Publication: Sendable, Equatable {
    public let metadata: BookMetadata
    public let rootDirectory: URL
    public let chapters: [Chapter]
    public let tableOfContents: [TOCEntry]
    public let coverImageURL: URL?

    public init(
        metadata: BookMetadata,
        rootDirectory: URL,
        chapters: [Chapter],
        tableOfContents: [TOCEntry],
        coverImageURL: URL?
    ) {
        self.metadata = metadata
        self.rootDirectory = rootDirectory
        self.chapters = chapters
        self.tableOfContents = tableOfContents
        self.coverImageURL = coverImageURL
    }

    /// Index of the chapter stored at `url` (any fragment is ignored).
    public func chapterIndex(for url: URL) -> Int? {
        let path = url.standardizedFileURL.path
        return chapters.firstIndex { $0.url.standardizedFileURL.path == path }
    }
}
