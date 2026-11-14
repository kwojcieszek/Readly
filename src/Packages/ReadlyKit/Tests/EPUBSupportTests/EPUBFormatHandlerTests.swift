import EPUBFixtures
import Foundation
import ReadlyCore
import Testing
@testable import EPUBSupport

@Suite struct EPUBFormatHandlerTests {
    private func load(_ navigation: SampleEPUB.Navigation) throws -> Publication {
        let archive = try SampleEPUB.make(navigation: navigation)
        let directory = archive.deletingLastPathComponent().appending(path: "unpacked")
        let handler = EPUBFormatHandler()
        try handler.unpack(archive, into: directory)
        return try handler.loadPublication(from: directory)
    }

    @Test func readsMetadataSpineAndCover() throws {
        let publication = try load(.navDocument)
        #expect(publication.metadata.title == SampleEPUB.title)
        #expect(publication.metadata.author == SampleEPUB.author)
        #expect(publication.metadata.language == "en")
        #expect(publication.chapters.map(\.id) == ["c1", "c2"])
        #expect(publication.chapters[1].url.lastPathComponent == "chapter 2.xhtml")
        #expect(publication.chapters.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
        #expect(publication.coverImageURL?.lastPathComponent == "cover.png")
    }

    @Test(arguments: [SampleEPUB.Navigation.navDocument, .ncx])
    func readsTableOfContents(navigation: SampleEPUB.Navigation) throws {
        let publication = try load(navigation)
        let toc = publication.tableOfContents
        #expect(toc.map(\.title) == ["Arrival", "The Gate", "The Pond"])
        #expect(toc.map(\.level) == [0, 1, 0])
        #expect(toc[1].fragment == "top")
        #expect(publication.chapterIndex(for: toc[2].url) == 1)
        #expect(publication.chapters.map(\.title) == ["Arrival", "The Pond"])
    }

    @Test func fallsBackToSpineWhenNavigationIsMissing() throws {
        let publication = try load(.none)
        #expect(publication.tableOfContents.map(\.title) == ["Chapter 1", "Chapter 2"])
    }

    @Test func rejectsFilesThatAreNotArchives() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReadlyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "broken.epub")
        try Data("not a zip".utf8).write(to: file)
        #expect(throws: EPUBError.invalidArchive) {
            try EPUBFormatHandler().unpack(file, into: directory.appending(path: "out"))
        }
    }

    @Test func refusesPathsOutsideTheBook() {
        let root = URL(fileURLWithPath: "/tmp/book")
        let resolver = HrefResolver(base: root.appending(path: "OEBPS"), root: root)
        #expect(resolver.resolve("../../etc/passwd") == nil)
        #expect(resolver.resolve("text/a.xhtml#x")?.fragment == "x")
    }
}
