import Foundation

/// Turns the line-by-line text of PDF pages back into paragraphs.
///
/// PDF text has a hard line break at the end of every printed line, words split
/// by hyphens, and running page numbers. Paragraphs end at blank lines, or where a
/// line that finishes a sentence is clearly shorter than a full line.
struct PDFTextFlow {
    enum Piece: Equatable {
        /// The start of a page (0-based), placed where its text begins.
        case pageStart(Int)
        case paragraph(String)
        /// A page without a text layer, shown as a picture.
        case pageImage(Int)
    }

    private var pieces: [Piece] = []
    private var current = ""
    /// Typical length of a full line, learned from the text so far.
    private var lineLengths: [Int] = []

    /// Adds the text of the next page.
    mutating func append(pageText: String, pageIndex: Int) {
        let lines = Self.contentLines(of: pageText)
        if current.isEmpty {
            pieces.append(.pageStart(pageIndex))
        } else {
            // The paragraph runs on from the previous page; the marker goes after it.
            pendingPageStarts.append(pageIndex)
        }
        lineLengths.append(contentsOf: lines.map(\.count).filter { $0 > 0 })

        var previous: String?
        for line in lines {
            if line.isEmpty {
                closeParagraph()
                previous = nil
                continue
            }
            if let previous, endsParagraph(previous), startsParagraph(line) {
                closeParagraph()
            }
            add(line)
            previous = line
        }
        // The paragraph may continue on the next page, unless this page ended it clearly.
        if let previous, endsParagraph(previous) { closeParagraph() }
    }

    /// Adds a page that has no text, such as a scan or a full-page illustration.
    mutating func appendImage(pageIndex: Int) {
        closeParagraph()
        pieces.append(.pageImage(pageIndex))
    }

    /// Finishes the text and returns its pieces.
    mutating func finish() -> [Piece] {
        closeParagraph()
        pieces.append(contentsOf: pendingPageStarts.map(Piece.pageStart))
        pendingPageStarts.removeAll()
        return pieces
    }

    private var pendingPageStarts: [Int] = []

    private mutating func add(_ line: String) {
        if current.isEmpty {
            current = line
        } else if current.hasSuffix("-"), current.dropLast().last?.isLetter == true, line.first?.isLowercase == true {
            current.removeLast()
            current += line
        } else {
            current += " " + line
        }
    }

    private mutating func closeParagraph() {
        if !current.isEmpty { pieces.append(.paragraph(current)) }
        current = ""
        pieces.append(contentsOf: pendingPageStarts.map(Piece.pageStart))
        pendingPageStarts.removeAll()
    }

    private func endsParagraph(_ line: String) -> Bool {
        guard let last = line.last(where: { !"”\"’)]»".contains($0) }), ".!?:…".contains(last) else { return false }
        return Double(line.count) < Double(typicalLineLength) * 0.8
    }

    private func startsParagraph(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        return first.isUppercase || first.isNumber || "“\"‘'«—–-•(".contains(first)
    }

    private var typicalLineLength: Int {
        guard !lineLengths.isEmpty else { return 60 }
        let sorted = lineLengths.sorted()
        // The upper quartile: most lines in a paragraph are full width.
        return sorted[min(sorted.count - 1, sorted.count * 3 / 4)]
    }

    /// The page's lines, trimmed, without running page numbers at the top or bottom.
    static func contentLines(of pageText: String) -> [String] {
        var lines = pageText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: "\u{00AD}", with: "").trimmingCharacters(in: .whitespaces) }
        while let first = lines.first, first.isEmpty || isPageNumber(first) { lines.removeFirst() }
        while let last = lines.last, last.isEmpty || isPageNumber(last) { lines.removeLast() }
        return lines
    }

    private static func isPageNumber(_ line: String) -> Bool {
        let core = line.trimmingCharacters(in: CharacterSet(charactersIn: "-–— "))
        return !core.isEmpty && core.count <= 4 && core.allSatisfy(\.isNumber)
    }
}
