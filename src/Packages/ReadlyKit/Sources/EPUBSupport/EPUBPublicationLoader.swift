import Foundation
import ReadlyCore

/// Builds a `Publication` from an extracted EPUB directory.
struct EPUBPublicationLoader: Sendable {
    func load(from directory: URL) throws -> Publication {
        let root = directory.standardizedFileURL
        let containerURL = root.appending(path: "META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerURL),
              let packagePath = ContainerParser().packagePath(from: containerData)
        else { throw EPUBError.missingContainer }

        let packageURL = root.appending(path: packagePath)
        guard let packageData = try? Data(contentsOf: packageURL),
              let package = PackageDocumentParser().parse(packageData)
        else { throw EPUBError.missingPackageDocument }

        let resolver = HrefResolver(base: packageURL.deletingLastPathComponent(), root: root)
        let toc = tableOfContents(for: package, resolver: resolver)
        let chapters = chapters(for: package, resolver: resolver, toc: toc)
        guard !chapters.isEmpty else { throw EPUBError.emptySpine }

        return Publication(
            metadata: BookMetadata(
                title: package.title ?? directory.lastPathComponent,
                author: package.creator ?? "Unknown Author",
                language: package.language
            ),
            rootDirectory: root,
            chapters: chapters,
            tableOfContents: toc.isEmpty ? fallbackTOC(for: chapters) : toc,
            coverImageURL: package.coverItem.flatMap { resolver.resolve($0.href)?.url }
        )
    }

    private func chapters(
        for package: PackageDocument,
        resolver: HrefResolver,
        toc: [TOCEntry]
    ) -> [Chapter] {
        package.spine.compactMap { id in
            guard let item = package.manifest[id], let url = resolver.resolve(item.href)?.url else {
                return nil
            }
            let title = toc.first { $0.url == url }?.title
            return Chapter(id: id, url: url, title: title)
        }
    }

    private func tableOfContents(for package: PackageDocument, resolver: HrefResolver) -> [TOCEntry] {
        var rawItems: [RawNavigationItem] = []
        var navigationResolver = resolver

        if let nav = package.navigationItem, let navURL = resolver.resolve(nav.href)?.url,
           let data = try? Data(contentsOf: navURL) {
            rawItems = NavDocumentParser().parse(data)
            navigationResolver = HrefResolver(base: navURL.deletingLastPathComponent(), root: resolver.root)
        }
        if rawItems.isEmpty, let ncx = package.ncxItem, let ncxURL = resolver.resolve(ncx.href)?.url,
           let data = try? Data(contentsOf: ncxURL) {
            rawItems = NCXParser().parse(data)
            navigationResolver = HrefResolver(base: ncxURL.deletingLastPathComponent(), root: resolver.root)
        }

        var entries: [TOCEntry] = []
        for item in rawItems {
            guard let target = navigationResolver.resolve(item.href) else { continue }
            entries.append(TOCEntry(
                id: entries.count,
                title: item.title,
                url: target.url,
                fragment: target.fragment,
                level: item.level
            ))
        }
        return entries
    }

    private func fallbackTOC(for chapters: [Chapter]) -> [TOCEntry] {
        chapters.enumerated().map { index, chapter in
            TOCEntry(id: index, title: "Chapter \(index + 1)", url: chapter.url, fragment: nil, level: 0)
        }
    }
}

/// Resolves book-relative hrefs to file URLs and refuses anything outside the book.
struct HrefResolver: Sendable {
    let base: URL
    let root: URL

    func resolve(_ href: String) -> (url: URL, fragment: String?)? {
        let parts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = String(parts.first ?? "")
        guard !rawPath.isEmpty else { return nil }
        let path = rawPath.removingPercentEncoding ?? rawPath
        let url = base.appending(path: path).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { return nil }
        let fragment = parts.count > 1 ? String(parts[1]) : nil
        return (url, fragment?.isEmpty == true ? nil : fragment)
    }
}
