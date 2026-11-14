import Testing
@testable import PDFSupport

@Suite struct PDFTextFlowTests {
    private func paragraphs(_ pages: [String]) -> [String] {
        var flow = PDFTextFlow()
        for (index, page) in pages.enumerated() { flow.append(pageText: page, pageIndex: index) }
        return flow.finish().compactMap { if case .paragraph(let text) = $0 { text } else { nil } }
    }

    @Test func joinsPrintedLinesAndSplitsShortSentenceEnds() {
        let page = """
        The Institute was in a place that did not appear on any
        map. For most people it simply didn’t exist at all, which
        suited everyone.
        Luke Ellis woke up in an unfamiliar room. For a moment he
        didn’t know where he was, or how he had gotten there.
        """
        #expect(paragraphs([page]) == [
            "The Institute was in a place that did not appear on any map. For most people it simply didn’t exist at all, which suited everyone.",
            "Luke Ellis woke up in an unfamiliar room. For a moment he didn’t know where he was, or how he had gotten there.",
        ])
    }

    @Test func rejoinsHyphenatedWordsAndDropsPageNumbers() {
        let page = "12\nThe walls were bright and the light never went out, and the air smel-\nled of nothing at all and nobody came to see him there\n– 12 –"
        #expect(paragraphs([page]) == [
            "The walls were bright and the light never went out, and the air smelled of nothing at all and nobody came to see him there",
        ])
    }

    @Test func paragraphsRunOnAcrossPagesWithThePageMarkerAfterThem() {
        var flow = PDFTextFlow()
        flow.append(pageText: "It was a long sentence that did not end on this page and went on", pageIndex: 0)
        flow.append(pageText: "to the next one.\n\nA new paragraph.", pageIndex: 1)
        flow.appendImage(pageIndex: 2)
        #expect(flow.finish() == [
            .pageStart(0),
            .paragraph("It was a long sentence that did not end on this page and went on to the next one."),
            .pageStart(1),
            .paragraph("A new paragraph."),
            .pageImage(2),
        ])
    }
}

@Suite struct PDFChapterPlanTests {
    @Test func splitsByTopLevelBookmarks() {
        let plan = PDFChapterPlan(pageCount: 30, outline: [
            .init(title: "One", page: 2, level: 1),
            .init(title: "Scene", page: 5, level: 2),
            .init(title: "Two", page: 12, level: 1),
        ])
        #expect(plan.chapters == [
            .init(title: "Beginning", pages: 0..<2),
            .init(title: "One", pages: 2..<12),
            .init(title: "Two", pages: 12..<30),
        ])
        #expect(plan.entries.map(\.level) == [0, 1, 0])
        #expect(plan.chapterIndex(containing: 5) == 1)
    }

    @Test func usesPageRangesWithoutAnOutline() {
        let plan = PDFChapterPlan(pageCount: 45, outline: [])
        #expect(plan.chapters.map(\.pages) == [0..<20, 20..<40, 40..<45])
        #expect(plan.chapters.map(\.title) == ["Pages 1–20", "Pages 21–40", "Pages 41–45"])
        #expect(plan.entries.count == 3)
    }

    @Test func ignoresBookmarksOutsideTheDocument() {
        let plan = PDFChapterPlan(pageCount: 3, outline: [.init(title: "Lost", page: 9, level: 0)])
        #expect(plan.chapters == [.init(title: "Pages 1–3", pages: 0..<3)])
    }

    @Test func escapesTextForXHTML() {
        #expect(PDFChapterWriter.escape("Fish & <chips> \"now\"\u{0001}") == "Fish &amp; &lt;chips&gt; &quot;now&quot; ")
    }
}
