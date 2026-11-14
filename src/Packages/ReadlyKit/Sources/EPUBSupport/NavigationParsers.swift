import Foundation

/// A table-of-contents item as written in the book, before URLs are resolved.
struct RawNavigationItem: Equatable {
    var title: String
    var href: String
    var level: Int
}

/// Parses the EPUB 3 navigation document (`<nav epub:type="toc">`).
final class NavDocumentParser: NSObject, XMLParserDelegate {
    private var items: [RawNavigationItem] = []
    private var isInsideTOC = false
    private var hasFinishedTOC = false
    private var listDepth = 0
    private var currentHref: String?
    private var currentTitle = ""

    func parse(_ data: Data) -> [RawNavigationItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName.lowercased() {
        case "nav" where !hasFinishedTOC:
            let type = attributeDict["epub:type"] ?? attributeDict["type"] ?? "toc"
            isInsideTOC = type.contains("toc")
        case "ol" where isInsideTOC:
            listDepth += 1
        case "a" where isInsideTOC:
            currentHref = attributeDict["href"]
            currentTitle = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentHref != nil { currentTitle += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName.lowercased() {
        case "nav" where isInsideTOC:
            isInsideTOC = false
            hasFinishedTOC = true
        case "ol" where isInsideTOC:
            listDepth -= 1
        case "a" where isInsideTOC:
            let title = currentTitle.collapsingWhitespace()
            if let href = currentHref, !title.isEmpty {
                items.append(.init(title: title, href: href, level: max(0, listDepth - 1)))
            }
            currentHref = nil
        default:
            break
        }
    }
}

/// Parses the EPUB 2 `toc.ncx` navigation map.
final class NCXParser: NSObject, XMLParserDelegate {
    private var items: [RawNavigationItem] = []
    private var depth = 0
    private var isInsideLabel = false
    private var pendingTitle = ""

    func parse(_ data: Data) -> [RawNavigationItem] {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "navPoint":
            depth += 1
            pendingTitle = ""
        case "text" where depth > 0:
            isInsideLabel = true
            pendingTitle = ""
        case "content" where depth > 0:
            let title = pendingTitle.collapsingWhitespace()
            if let src = attributeDict["src"], !title.isEmpty {
                items.append(.init(title: title, href: src, level: depth - 1))
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideLabel { pendingTitle += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "navPoint": depth -= 1
        case "text": isInsideLabel = false
        default: break
        }
    }
}

extension String {
    func collapsingWhitespace() -> String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
