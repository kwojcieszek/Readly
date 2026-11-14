import Foundation

/// Everything the app needs from a book format: unpack an imported file into a
/// working directory and describe its content as a `Publication`.
public protocol BookFormatHandler: Sendable {
    var format: BookFormat { get }
    func unpack(_ file: URL, into directory: URL) throws
    func loadPublication(from directory: URL) throws -> Publication
}

public struct BookFormatRegistry: Sendable {
    private let handlers: [any BookFormatHandler]

    public init(handlers: [any BookFormatHandler]) {
        self.handlers = handlers
    }

    public var supportedFileExtensions: [String] {
        handlers.flatMap(\.format.fileExtensions)
    }

    public func handler(for format: BookFormat) -> (any BookFormatHandler)? {
        handlers.first { $0.format == format }
    }

    public func handler(forFileExtension fileExtension: String) -> (any BookFormatHandler)? {
        let wanted = fileExtension.lowercased()
        return handlers.first { $0.format.fileExtensions.contains(wanted) }
    }
}
