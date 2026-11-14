import Foundation
import ReadlyCore

public struct ImportedBook: Sendable {
    public let id: UUID
    public let format: BookFormat
    public let metadata: BookMetadata
    public let coverData: Data?
}

/// Unpacks book files into the file store. Runs off the main actor.
public struct BookImporter: Sendable {
    private let registry: BookFormatRegistry
    private let fileStore: BookFileStore

    public init(registry: BookFormatRegistry, fileStore: BookFileStore) {
        self.registry = registry
        self.fileStore = fileStore
    }

    public func importBook(from source: URL) async throws -> ImportedBook {
        let isScoped = source.startAccessingSecurityScopedResource()
        defer { if isScoped { source.stopAccessingSecurityScopedResource() } }

        guard let handler = registry.handler(forFileExtension: source.pathExtension) else {
            throw LibraryError.unsupportedFormat(source.pathExtension)
        }
        let id = UUID()
        let directory = try fileStore.createDirectory(for: id)
        do {
            try handler.unpack(source, into: directory)
            let publication = try handler.loadPublication(from: directory)
            return ImportedBook(
                id: id,
                format: handler.format,
                metadata: publication.metadata,
                coverData: publication.coverImageURL.flatMap { CoverThumbnailer.thumbnailData(from: $0) }
            )
        } catch {
            fileStore.removeDirectory(for: id)
            throw error
        }
    }

    public func loadPublication(id: UUID, format: BookFormat) async throws -> Publication {
        guard let handler = registry.handler(for: format), fileStore.hasFiles(for: id) else {
            throw LibraryError.missingFiles
        }
        return try handler.loadPublication(from: fileStore.directory(for: id))
    }
}
