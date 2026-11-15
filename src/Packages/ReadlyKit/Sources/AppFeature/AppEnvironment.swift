import EPUBSupport
import Foundation
import LibraryData
import PDFSupport
import Preferences
import ReadlyCore
import SwiftData
import TranslationCore

/// The app's composition root: builds and holds the shared services.
@MainActor
public final class AppEnvironment {
    public let settings: AppSettings
    public let keyStore: any APIKeyStoring
    public let container: ModelContainer
    public let library: BookLibrary
    public init(settings: AppSettings, keyStore: any APIKeyStoring, container: ModelContainer, fileStore: BookFileStore) {
        self.settings = settings
        self.keyStore = keyStore
        self.container = container
        // Register additional `BookFormatHandler`s here to support more formats.
        let registry = BookFormatRegistry(handlers: [EPUBFormatHandler(), PDFFormatHandler()])
        self.library = BookLibrary(context: container.mainContext, registry: registry, fileStore: fileStore)
    }

    public static func live() -> AppEnvironment {
        let container: ModelContainer
        do {
            container = try LibraryContainer.make()
        } catch {
            // A damaged store must not keep the app from launching.
            container = try! LibraryContainer.make(inMemory: true)
        }
        return AppEnvironment(
            settings: AppSettings(),
            keyStore: EncryptedAPIKeyStore(),
            container: container,
            fileStore: .default
        )
    }
}
