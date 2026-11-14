import Foundation

final class PackageDocumentParser: NSObject, XMLParserDelegate {
    private var document = PackageDocument()
    private var text = ""
    private var isInsideMetadata = false

    func parse(_ data: Data) -> PackageDocument? {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
        return document.manifest.isEmpty ? nil : document
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        text = ""
        switch elementName {
        case "metadata":
            isInsideMetadata = true
        case "meta" where attributeDict["name"] == "cover":
            document.coverID = attributeDict["content"]
        case "item":
            guard let id = attributeDict["id"], let href = attributeDict["href"] else { return }
            let properties = (attributeDict["properties"] ?? "").split(separator: " ").map(String.init)
            document.manifest[id] = .init(
                href: href,
                mediaType: attributeDict["media-type"] ?? "",
                properties: Set(properties)
            )
        case "spine":
            document.ncxID = attributeDict["toc"]
        case "itemref":
            if let idref = attributeDict["idref"] { document.spine.append(idref) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        if elementName == "metadata" { isInsideMetadata = false }
        guard isInsideMetadata, !value.isEmpty else { return }
        switch elementName {
        case "title" where document.title == nil: document.title = value
        case "creator" where document.creator == nil: document.creator = value
        case "language" where document.language == nil: document.language = value
        default: break
        }
    }
}
