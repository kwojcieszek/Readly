import Foundation

/// Writes one chapter of reflowed PDF text as an XHTML document.
struct PDFChapterWriter {
    var language: String?

    func document(title: String, pieces: [PDFTextFlow.Piece]) -> String {
        let body = pieces.map(html).joined(separator: "\n")
        let lang = language.map { " lang=\"\(Self.escape($0))\" xml:lang=\"\(Self.escape($0))\"" } ?? ""
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml"\(lang)>
        <head>
        <meta charset="UTF-8"/>
        <title>\(Self.escape(title))</title>
        <style>
        p { margin: 0 0 0.55em; text-indent: 1.3em; text-align: justify; }
        figure.page { margin: 0.8em 0; text-align: center; break-inside: avoid; }
        figure.page img { max-width: 100%; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    static func anchor(forPage page: Int) -> String { "page-\(page + 1)" }
    static func imagePath(forPage page: Int) -> String { "images/page-\(page + 1).jpg" }

    private func html(_ piece: PDFTextFlow.Piece) -> String {
        switch piece {
        case .pageStart(let page):
            "<span id=\"\(Self.anchor(forPage: page))\"></span>"
        case .paragraph(let text):
            "<p>\(Self.escape(text))</p>"
        case .pageImage(let page):
            """
            <figure class="page" id="\(Self.anchor(forPage: page))">\
            <img src="\(Self.imagePath(forPage: page))" alt="Page \(page + 1)"/></figure>
            """
        }
    }

    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            // Control characters are not allowed in XML.
            case _ where scalar.value < 0x20 && scalar != "\n" && scalar != "\t": result += " "
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
