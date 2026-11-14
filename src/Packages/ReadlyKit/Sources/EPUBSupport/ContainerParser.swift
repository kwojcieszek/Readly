import Foundation

/// Reads `META-INF/container.xml` and returns the package document path.
final class ContainerParser: NSObject, XMLParserDelegate {
    private var rootFilePath: String?

    func packagePath(from data: Data) -> String? {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
        return rootFilePath
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "rootfile", rootFilePath == nil {
            rootFilePath = attributeDict["full-path"]
        }
    }
}
