import EPUBSupport
import Foundation
import LibraryData
import PDFSupport
import Preferences
import ReadlyCore
import SwiftData
import SystemTranslation
import TranslationCore

/// The app's composition root: builds and holds the shared services.
@MainActor
public final class AppEnvironment {
    public let settings: AppSettings
    public let keyStore: any APIKeyStoring
    public let container: ModelContainer
    public let library: BookLibrary
    /// Connects the app to Apple's built-in translator; hosted by the root views.
    public let systemTranslation: SystemTranslationBridge
    public let translatorFactory: TranslatorFactory

    public init(settings: AppSettings, keyStore: any APIKeyStoring, container: ModelContainer, fileStore: BookFileStore) {
        self.settings = settings
        self.keyStore = keyStore
        self.container = container
        let systemTranslation = SystemTranslationBridge()
        self.systemTranslation = systemTranslation
        self.translatorFactory = TranslatorFactory(
            keyStore: keyStore,
            systemTranslator: SystemTranslator(bridge: systemTranslation)
        )
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
            keyStore: KeychainAPIKeyStore(),
            container: container,
            fileStore: .default
        )
    }
}
