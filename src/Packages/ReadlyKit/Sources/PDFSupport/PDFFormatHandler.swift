import Foundation
import ReadlyCore

/// Reads PDFs by converting their text into reflowable chapters at import time.
public struct PDFFormatHandler: BookFormatHandler {
    public let format = BookFormat.pdf

    public init() {}

    public func unpack(_ file: URL, into directory: URL) throws {
        try PDFBookConverter().convert(file, into: directory)
    }

    public func loadPublication(from directory: URL) throws -> Publication {
        let root = directory.standardizedFileURL
        let manifest = try PDFManifest.read(from: root)
        let chapters = manifest.chapters.enumerated().map { index, chapter in
            Chapter(id: "chapter-\(index + 1)", url: root.appending(path: chapter.file), title: chapter.title)
        }
        guard !chapters.isEmpty else { throw PDFBookError.empty }
        let toc = manifest.tableOfContents.enumerated().map { index, entry in
            TOCEntry(
                id: index,
                title: entry.title,
                url: root.appending(path: entry.file),
                fragment: entry.fragment,
                level: entry.level
            )
        }
        return Publication(
            metadata: BookMetadata(title: manifest.title, author: manifest.author, language: manifest.language),
            rootDirectory: root,
            chapters: chapters,
            tableOfContents: toc,
            coverImageURL: manifest.cover.map { root.appending(path: $0) }
        )
    }
}
