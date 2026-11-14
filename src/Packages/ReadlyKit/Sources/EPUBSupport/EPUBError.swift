import Foundation

public enum EPUBError: LocalizedError, Equatable {
    case invalidArchive
    case missingContainer
    case missingPackageDocument
    case emptySpine

    public var errorDescription: String? {
        switch self {
        case .invalidArchive: "The file is not a valid EPUB archive."
        case .missingContainer: "The EPUB is missing META-INF/container.xml."
        case .missingPackageDocument: "The EPUB package document could not be read."
        case .emptySpine: "The EPUB does not contain any readable chapters."
        }
    }
}
