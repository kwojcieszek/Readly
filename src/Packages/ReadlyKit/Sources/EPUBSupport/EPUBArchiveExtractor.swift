import Foundation
import ZIPFoundation

struct EPUBArchiveExtractor: Sendable {
    func extract(_ archive: URL, to directory: URL) throws {
        do {
            try FileManager.default.unzipItem(at: archive, to: directory)
        } catch {
            throw EPUBError.invalidArchive
        }
    }
}
