import Foundation
import ReadlyCore

public struct EPUBFormatHandler: BookFormatHandler {
    public let format = BookFormat.epub

    public init() {}

    public func unpack(_ file: URL, into directory: URL) throws {
        try EPUBArchiveExtractor().extract(file, to: directory)
    }

    public func loadPublication(from directory: URL) throws -> Publication {
        try EPUBPublicationLoader().load(from: directory)
    }
}
