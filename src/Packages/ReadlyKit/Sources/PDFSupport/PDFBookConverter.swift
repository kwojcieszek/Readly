import Foundation
import NaturalLanguage
import PDFKit

/// Converts a PDF into HTML chapters the reader can paginate, translate and search.
struct PDFBookConverter {
    /// Pages with less text than this are treated as pictures (scans, illustrations).
    static let minimumPageText = 24

    func convert(_ file: URL, into directory: URL) throws {
        guard let document = PDFDocument(url: file) else { throw PDFBookError.unreadable }
        if document.isLocked, !document.unlock(withPassword: "") { throw PDFBookError.locked }
        guard document.pageCount > 0 else { throw PDFBookError.empty }

        let pageTexts = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        let language = Self.language(of: pageTexts)
        let plan = PDFChapterPlan(pageCount: document.pageCount, outline: outline(of: document))
        let writer = PDFChapterWriter(language: language)
        let fileManager = FileManager.default

        var chapters: [PDFManifest.Chapter] = []
        for (index, chapter) in plan.chapters.enumerated() {
            var flow = PDFTextFlow()
            for page in chapter.pages {
                let text = pageTexts[page]
                if text.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumPageText {
                    flow.append(pageText: text, pageIndex: page)
                } else if let pdfPage = document.page(at: page),
                          let image = PDFPageRenderer.jpeg(of: pdfPage, maxPixelSize: 1600) {
                    let url = directory.appending(path: PDFChapterWriter.imagePath(forPage: page))
                    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try image.write(to: url)
                    flow.appendImage(pageIndex: page)
                }
            }
            let fileName = String(format: "chapter-%04d.xhtml", index + 1)
            let html = writer.document(title: chapter.title, pieces: flow.finish())
            try Data(html.utf8).write(to: directory.appending(path: fileName))
            chapters.append(PDFManifest.Chapter(file: fileName, title: chapter.title))
        }

        var cover: String?
        if let first = document.page(at: 0), let data = PDFPageRenderer.jpeg(of: first, maxPixelSize: 900) {
            try data.write(to: directory.appending(path: "cover.jpg"))
            cover = "cover.jpg"
        }

        let attributes = document.documentAttributes ?? [:]
        let manifest = PDFManifest(
            title: Self.clean(attributes[PDFDocumentAttribute.titleAttribute]) ?? file.deletingPathExtension().lastPathComponent,
            author: Self.clean(attributes[PDFDocumentAttribute.authorAttribute]) ?? "Unknown Author",
            language: language,
            cover: cover,
            chapters: chapters,
            tableOfContents: plan.entries.compactMap { entry in
                guard let index = plan.chapterIndex(containing: entry.page) else { return nil }
                let isChapterStart = plan.chapters[index].pages.lowerBound == entry.page
                return PDFManifest.Entry(
                    title: entry.title,
                    file: chapters[index].file,
                    fragment: isChapterStart ? nil : PDFChapterWriter.anchor(forPage: entry.page),
                    level: entry.level
                )
            }
        )
        try manifest.write(to: directory)
    }

    /// The PDF's bookmarks, depth first, with the page each one opens.
    private func outline(of document: PDFDocument) -> [PDFChapterPlan.Entry] {
        var entries: [PDFChapterPlan.Entry] = []
        func visit(_ item: PDFOutline, level: Int) {
            for index in 0..<item.numberOfChildren {
                guard let child = item.child(at: index) else { continue }
                if let page = child.destination?.page ?? (child.action as? PDFActionGoTo)?.destination.page {
                    let title = (child.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    entries.append(.init(title: title, page: document.index(for: page), level: level))
                }
                visit(child, level: level + 1)
            }
        }
        if let root = document.outlineRoot { visit(root, level: 0) }
        return entries
    }

    private static func language(of pages: [String]) -> String? {
        var sample = ""
        for text in pages where sample.count < 4000 { sample += text + "\n" }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        return recognizer.dominantLanguage?.rawValue
    }

    private static func clean(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}
