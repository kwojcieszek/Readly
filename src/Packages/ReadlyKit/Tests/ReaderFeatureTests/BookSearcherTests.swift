import Foundation
import ReadlyCore
import Testing
@testable import ReaderFeature

@Suite struct BookSearcherTests {
    @Test func plainTextDropsMarkupAndDecodesEntities() {
        let html = """
        <html><head><title>Skip me</title><style>p { color: red; }</style></head>
        <body><p>Fish &amp; chips &#8212; caf&#xE9;</p><script>var skip = 1;</script><!-- skip --></body></html>
        """
        let text = ChapterText.plainText(fromHTML: html)
        #expect(text.contains("Fish & chips — café"))
        #expect(!text.contains("skip"))
        #expect(!text.contains("Skip me"))
    }

    @Test func findsOccurrencesPerChapter() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReadlySearch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pages = ["<body><p>The old gate.</p></body>", "<body><p>A gate, and another\n GATE.</p></body>"]
        let chapters = try pages.enumerated().map { index, html in
            let url = directory.appending(path: "c\(index).xhtml")
            try Data(html.utf8).write(to: url)
            return Chapter(id: "c\(index)", url: url, title: index == 0 ? "One" : nil)
        }
        let publication = Publication(
            metadata: BookMetadata(title: "T", author: "A"),
            rootDirectory: directory,
            chapters: chapters,
            tableOfContents: [],
            coverImageURL: nil
        )

        let results = await BookSearcher().search("gate", in: publication)
        #expect(results.map(\.chapterIndex) == [0, 1, 1])
        #expect(results.map(\.occurrence) == [0, 0, 1])
        #expect(results.first?.chapterTitle == "One")
        #expect(results.first?.snippet == "The old gate.")
        #expect(await BookSearcher().search("another gate", in: publication).count == 1)
        #expect(await BookSearcher().search("  ", in: publication).isEmpty)
    }
}
