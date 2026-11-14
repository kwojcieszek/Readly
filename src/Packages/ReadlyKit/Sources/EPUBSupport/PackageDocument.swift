import Foundation

/// The parts of an OPF package document the reader uses.
struct PackageDocument: Equatable {
    struct ManifestItem: Equatable {
        var href: String
        var mediaType: String
        var properties: Set<String>
    }

    var title: String?
    var creator: String?
    var language: String?
    var manifest: [String: ManifestItem] = [:]
    var spine: [String] = []
    var ncxID: String?
    var coverID: String?

    var navigationItem: ManifestItem? {
        manifest.values.first { $0.properties.contains("nav") }
    }

    var ncxItem: ManifestItem? {
        if let ncxID, let item = manifest[ncxID] { return item }
        return manifest.values.first { $0.mediaType == "application/x-dtbncx+xml" }
    }

    var coverItem: ManifestItem? {
        if let item = manifest.values.first(where: { $0.properties.contains("cover-image") }) {
            return item
        }
        if let coverID, let item = manifest[coverID], item.mediaType.hasPrefix("image/") {
            return item
        }
        return nil
    }
}
