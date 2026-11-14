import Foundation

/// Owns the on-disk location of unpacked books: one directory per book id.
public struct BookFileStore: Sendable {
    public let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    public static var `default`: BookFileStore {
        BookFileStore(baseDirectory: URL.applicationSupportDirectory.appending(path: "Books", directoryHint: .isDirectory))
    }

    public func directory(for id: UUID) -> URL {
        baseDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    public func createDirectory(for id: UUID) throws -> URL {
        let directory = directory(for: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public func removeDirectory(for id: UUID) {
        try? FileManager.default.removeItem(at: directory(for: id))
    }

    public func hasFiles(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: directory(for: id).path)
    }
}
