import Testing
@testable import ReaderFeature

@Suite struct PageMapTests {
    private func map(_ counts: [Int]) -> PageMap {
        var map = PageMap(chapterCount: counts.count)
        for (index, count) in counts.enumerated() { map.setPageCount(count, forChapter: index) }
        return map
    }

    @Test func numbersPagesAcrossChapters() {
        let map = map([3, 5, 2])
        #expect(map.totalPages == 10)
        #expect(map.bookPage(chapter: 0, page: 0) == 1)
        #expect(map.bookPage(chapter: 1, page: 0) == 4)
        #expect(map.bookPage(chapter: 2, page: 1) == 10)
    }

    @Test func findsTheChapterOfABookPage() {
        let map = map([3, 5, 2])
        #expect(map.location(ofBookPage: 1).map { [$0.chapter, $0.page] } == [0, 0])
        #expect(map.location(ofBookPage: 4).map { [$0.chapter, $0.page] } == [1, 0])
        #expect(map.location(ofBookPage: 8).map { [$0.chapter, $0.page] } == [1, 4])
        #expect(map.location(ofBookPage: 99).map { [$0.chapter, $0.page] } == [2, 1])
        #expect(map.location(ofBookPage: -4).map { [$0.chapter, $0.page] } == [0, 0])
    }

    @Test func isUnknownUntilEveryChapterIsMeasured() {
        var map = PageMap(chapterCount: 2)
        map.setPageCount(4, forChapter: 0)
        #expect(!map.isComplete)
        #expect(map.totalPages == nil)
        #expect(map.bookPage(chapter: 0, page: 1) == nil)
        #expect(map.location(ofBookPage: 2) == nil)
    }
}
