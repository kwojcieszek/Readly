import Foundation
import LibraryData
import Observation

/// Imports picked or dropped files into the library and collects what went wrong.
@MainActor
@Observable
final class BookImportController {
    private(set) var isImporting = false
    var errorMessage: String?

    func importBooks(at urls: [URL], into library: BookLibrary, pickingFolders: Bool = false) {
        guard !urls.isEmpty, !isImporting else { return }
        isImporting = true
        Task {
            var failures: [String] = []
            for url in urls {
                do {
                    #if os(iOS)
                    if pickingFolders || url.hasDirectoryPath {
                        try await importFolder(at: url, into: library, failures: &failures)
                        continue
                    }
                    #endif
                    try await library.addBook(from: url)
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            isImporting = false
            if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
        }
    }

    #if os(iOS)
    private func importFolder(at url: URL, into library: BookLibrary, failures: inout [String]) async throws {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

        let extensions = Set(library.registry.supportedFileExtensions)
        let books = try await Self.books(in: url, extensions: extensions)
        if books.isEmpty {
            failures.append("\(url.lastPathComponent): No supported books found.")
        }
        for book in books {
            do {
                try await library.addBook(from: book)
            } catch {
                failures.append("\(book.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func books(in folder: URL, extensions: Set<String>) async throws -> [URL] {
        var coordinationError: NSError?
        var scanError: Error?
        var books: [URL] = []
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        NSFileCoordinator().coordinate(readingItemAt: folder, error: &coordinationError) { directory in
            guard let entries = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, error in
                    scanError = error
                    return false
                }
            ) else {
                scanError = CocoaError(.fileReadUnknown)
                return
            }
            do {
                for case let file as URL in entries where extensions.contains(file.pathExtension.lowercased()) {
                    if try file.resourceValues(forKeys: keys).isRegularFile == true {
                        books.append(file)
                    }
                }
            } catch {
                scanError = error
            }
        }
        if let error = coordinationError ?? scanError { throw error }
        return books
    }
    #endif
}
