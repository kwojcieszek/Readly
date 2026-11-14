import Foundation
import ReadlyCore
import Testing
@testable import PDFSupport

@Suite struct PDFFormatHandlerTests {
    /// Writes a three-page PDF: text, an empty page, text; with bookmarks and metadata.
    private func makePDF() throws -> URL {
        let data = MinimalPDF.make(
            pages: [
                ["Chapter One", "", "The gate was wide open & nobody came. Water stood", "still in the pond behind the old garden wall, and the", "morning was quiet."],
                [],
                ["Chapter Two", "", "Later that day the rain began. It fell on the roofs", "and on the road for a long time."],
            ],
            outline: [("Chapter One", 0), ("Chapter Two", 2)],
            title: "The Quiet Garden",
            author: "Ada Reader"
        )
        let url = FileManager.default.temporaryDirectory.appending(path: "garden-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    @Test func convertsAPDFIntoChaptersWithContentsAndCover() throws {
        let pdf = try makePDF()
        let output = FileManager.default.temporaryDirectory.appending(path: "ReadlyPDFBook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let handler = PDFFormatHandler()
        try handler.unpack(pdf, into: output)
        let publication = try handler.loadPublication(from: output)

        #expect(publication.metadata.title == "The Quiet Garden")
        #expect(publication.metadata.author == "Ada Reader")
        #expect(publication.metadata.language == "en")
        #expect(publication.chapters.map(\.title) == ["Chapter One", "Chapter Two"])
        #expect(publication.tableOfContents.map(\.title) == ["Chapter One", "Chapter Two"])
        #expect(publication.coverImageURL.map { FileManager.default.fileExists(atPath: $0.path) } == true)

        let first = try String(contentsOf: publication.chapters[0].url, encoding: .utf8)
        #expect(first.contains("The gate was wide open &amp; nobody came."))
        #expect(first.contains("id=\"page-1\""))
        // The empty page becomes a picture of the page.
        #expect(first.contains("images/page-2.jpg"))
        #expect(FileManager.default.fileExists(atPath: output.appending(path: "images/page-2.jpg").path))
        // Every chapter must be well-formed XHTML for the web view.
        for chapter in publication.chapters {
            #expect(XMLParser(data: try Data(contentsOf: chapter.url)).parse())
        }
        #expect(BookFormatRegistry(handlers: [handler]).handler(forFileExtension: "PDF")?.format == .pdf)
    }

    @Test func rejectsFilesThatAreNotPDFs() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "not-a-\(UUID().uuidString).pdf")
        try Data("hello".utf8).write(to: file)
        #expect(throws: PDFBookError.unreadable) {
            try PDFFormatHandler().unpack(file, into: FileManager.default.temporaryDirectory)
        }
    }
}
