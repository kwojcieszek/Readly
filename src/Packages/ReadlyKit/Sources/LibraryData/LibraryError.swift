import Foundation

public enum LibraryError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case missingFiles

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let fileExtension):
            "Files of type “.\(fileExtension)” are not supported."
        case .missingFiles:
            "The files of this book are missing. Remove it and add it again."
        }
    }
}
