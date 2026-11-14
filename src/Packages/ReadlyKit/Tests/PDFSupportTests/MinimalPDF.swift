import Foundation

/// Hand-writes a small PDF with text pages, bookmarks and metadata, for tests.
enum MinimalPDF {
    /// - Parameters:
    ///   - pages: The lines of each page; an empty array makes a page without text.
    ///   - outline: Bookmark titles and the 0-based page each opens.
    static func make(pages: [[String]], outline: [(String, Int)], title: String, author: String) -> Data {
        // Objects: 1 catalog, 2 pages, 3 font, 4 info, 5 outlines, then per page a page
        // and a content stream, then one object per bookmark.
        let pageBase = 6
        let itemBase = pageBase + pages.count * 2
        func pageObject(_ index: Int) -> Int { pageBase + index * 2 }

        var objects: [Int: String] = [
            1: "<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R /PageMode /UseOutlines >>",
            2: "<< /Type /Pages /Kids [\(pages.indices.map { "\(pageObject($0)) 0 R" }.joined(separator: " "))] /Count \(pages.count) >>",
            3: "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
            4: "<< /Title (\(escape(title))) /Author (\(escape(author))) >>",
        ]
        let items = outline.indices.map { itemBase + $0 }
        objects[5] = items.isEmpty
            ? "<< /Type /Outlines /Count 0 >>"
            : "<< /Type /Outlines /First \(items.first!) 0 R /Last \(items.last!) 0 R /Count \(items.count) >>"
        for (index, lines) in pages.enumerated() {
            var stream = "BT /F1 12 Tf 14 TL 50 780 Td\n"
            for line in lines { stream += "(\(escape(line))) Tj T*\n" }
            stream += "ET"
            objects[pageObject(index)] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 420 842] /Resources << /Font << /F1 3 0 R >> >> /Contents \(pageObject(index) + 1) 0 R >>"
            objects[pageObject(index) + 1] = "<< /Length \(stream.utf8.count) >>\nstream\n\(stream)\nendstream"
        }
        for (index, (label, page)) in outline.enumerated() {
            var item = "<< /Title (\(escape(label))) /Parent 5 0 R /Dest [\(pageObject(page)) 0 R /XYZ 0 842 0]"
            if index > 0 { item += " /Prev \(items[index - 1]) 0 R" }
            if index < items.count - 1 { item += " /Next \(items[index + 1]) 0 R" }
            objects[items[index]] = item + " >>"
        }

        var output = "%PDF-1.4\n"
        var offsets: [Int] = []
        let count = objects.keys.max()!
        for number in 1...count {
            offsets.append(output.utf8.count)
            output += "\(number) 0 obj\n\(objects[number]!)\nendobj\n"
        }
        let xref = output.utf8.count
        output += "xref\n0 \(count + 1)\n0000000000 65535 f \n"
        for offset in offsets { output += String(format: "%010d 00000 n \n", offset) }
        output += "trailer\n<< /Size \(count + 1) /Root 1 0 R /Info 4 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        return Data(output.utf8)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    }
}
