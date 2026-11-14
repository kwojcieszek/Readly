import Foundation
import LibraryData
import Observation

/// Imports picked or dropped files into the library and collects what went wrong.
@MainActor
@Observable
final class BookImportController {
    private(set) var isImporting = false
    var errorMessage: String?

    func importBooks(at urls: [URL], into library: BookLibrary) {
        guard !urls.isEmpty else { return }
        isImporting = true
        Task {
            var failures: [String] = []
            for url in urls {
                do {
                    try await library.addBook(from: url)
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            isImporting = false
            if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
        }
    }
}
