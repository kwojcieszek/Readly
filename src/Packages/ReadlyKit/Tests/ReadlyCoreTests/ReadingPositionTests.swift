import Foundation
import Testing
@testable import ReadlyCore

@Suite struct ReadingPositionTests {
    @Test func overallProgressCombinesChapterAndScroll() {
        let position = ReadingPosition(chapterIndex: 1, chapterProgress: 0.5)
        #expect(position.overallProgress(chapterCount: 4) == 0.375)
    }

    @Test func pagePositionSurvivesRelayout() {
        let position = ReadingPosition(chapterIndex: 2, page: 3, pageCount: 10)
        #expect(position.page(inChapterWithPageCount: 10) == 3)
        #expect(position.page(inChapterWithPageCount: 20) == 7)
        #expect(position.page(inChapterWithPageCount: 1) == 0)
        #expect(ReadingPosition(chapterIndex: 0, page: 9, pageCount: 10).page(inChapterWithPageCount: 10) == 9)
    }

    @Test func valuesAreClamped() {
        let position = ReadingPosition(chapterIndex: -3, chapterProgress: 7)
        #expect(position.chapterIndex == 0)
        #expect(position.chapterProgress == 1)
        #expect(position.overallProgress(chapterCount: 0) == 0)
        #expect(ReadingPosition(chapterIndex: 9, chapterProgress: 1).overallProgress(chapterCount: 2) == 1)
    }

    @Test func registryFindsHandlersByExtension() {
        let registry = BookFormatRegistry(handlers: [StubHandler()])
        #expect(registry.handler(forFileExtension: "EPUB") != nil)
        #expect(registry.handler(forFileExtension: "pdf") == nil)
        #expect(registry.supportedFileExtensions == ["epub"])
    }
}

private struct StubHandler: BookFormatHandler {
    let format = BookFormat.epub
    func unpack(_ file: URL, into directory: URL) throws {}
    func loadPublication(from directory: URL) throws -> Publication {
        Publication(
            metadata: .init(title: "", author: ""),
            rootDirectory: directory,
            chapters: [],
            tableOfContents: [],
            coverImageURL: nil
        )
    }
}
