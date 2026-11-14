import Foundation
import ZIPFoundation

/// Builds a small EPUB on disk for tests.
public enum SampleEPUB {
    public enum Navigation: Sendable {
        case navDocument
        case ncx
        case none
    }

    public static let title = "The Quiet Garden"
    public static let author = "Ada Reader"

    /// Writes the book into a fresh temporary directory and returns the `.epub` URL.
    public static func make(navigation: Navigation = .navDocument) throws -> URL {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory.appending(path: "ReadlyTests-\(UUID().uuidString)")
        let source = workspace.appending(path: "book")
        let text = source.appending(path: "OEBPS/text")
        try fileManager.createDirectory(at: text, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: source.appending(path: "META-INF"), withIntermediateDirectories: true)

        try write("application/epub+zip", to: source.appending(path: "mimetype"))
        try write(container, to: source.appending(path: "META-INF/container.xml"))
        try write(package(navigation), to: source.appending(path: "OEBPS/content.opf"))
        try write(chapter("Arrival", "The gate was open. Nobody came."), to: text.appending(path: "chapter1.xhtml"))
        try write(chapter("The Pond", "Water stood still."), to: text.appending(path: "chapter 2.xhtml"))
        try Data(base64Encoded: pixelPNG)!.write(to: source.appending(path: "OEBPS/cover.png"))
        switch navigation {
        case .navDocument: try write(navDocument, to: source.appending(path: "OEBPS/nav.xhtml"))
        case .ncx: try write(ncx, to: source.appending(path: "OEBPS/toc.ncx"))
        case .none: break
        }

        let archive = workspace.appending(path: "sample.epub")
        try fileManager.zipItem(at: source, to: archive, shouldKeepParent: false)
        return archive
    }

    private static func write(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }

    private static let container = """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
    """

    private static func package(_ navigation: Navigation) -> String {
        let navigationItem = switch navigation {
        case .navDocument: #"<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>"#
        case .ncx: #"<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>"#
        case .none: ""
        }
        let spineAttributes = navigation == .ncx ? #" toc="ncx""# : ""
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="id">urn:uuid:readly-sample</dc:identifier>
            <dc:title>\(title)</dc:title>
            <dc:creator>\(author)</dc:creator>
            <dc:language>en</dc:language>
            <meta name="cover" content="cover"/>
          </metadata>
          <manifest>
            <item id="c1" href="text/chapter1.xhtml" media-type="application/xhtml+xml"/>
            <item id="c2" href="text/chapter%202.xhtml" media-type="application/xhtml+xml"/>
            <item id="cover" href="cover.png" media-type="image/png"/>
            \(navigationItem)
          </manifest>
          <spine\(spineAttributes)>
            <itemref idref="c1"/>
            <itemref idref="c2"/>
          </spine>
        </package>
        """
    }

    private static func chapter(_ heading: String, _ body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
          <head><title>\(heading)</title></head>
          <body><h1 id="top">\(heading)</h1><p>\(body)</p></body>
        </html>
        """
    }

    private static let navDocument = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
      <head><title>Contents</title></head>
      <body>
        <nav epub:type="toc">
          <ol>
            <li><a href="text/chapter1.xhtml">Arrival</a>
              <ol><li><a href="text/chapter1.xhtml#top">The <em>Gate</em></a></li></ol>
            </li>
            <li><a href="text/chapter%202.xhtml">The Pond</a></li>
          </ol>
        </nav>
        <nav epub:type="landmarks"><ol><li><a href="text/chapter1.xhtml">Start</a></li></ol></nav>
      </body>
    </html>
    """

    private static let ncx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
      <docTitle><text>Ignored</text></docTitle>
      <navMap>
        <navPoint id="n1" playOrder="1">
          <navLabel><text>Arrival</text></navLabel>
          <content src="text/chapter1.xhtml"/>
          <navPoint id="n2" playOrder="2">
            <navLabel><text>The Gate</text></navLabel>
            <content src="text/chapter1.xhtml#top"/>
          </navPoint>
        </navPoint>
        <navPoint id="n3" playOrder="3">
          <navLabel><text>The Pond</text></navLabel>
          <content src="text/chapter%202.xhtml"/>
        </navPoint>
      </navMap>
    </ncx>
    """

    /// A 1×1 PNG.
    private static let pixelPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
}
