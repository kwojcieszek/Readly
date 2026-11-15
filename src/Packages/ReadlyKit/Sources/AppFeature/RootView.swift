import DesignSystem
import SettingsFeature
import SwiftData
import SwiftUI
import SystemTranslation
import TranslationCore

public struct RootView: View {
    @Environment(\.locale) private var systemLocale
    private let environment: AppEnvironment
    @State private var translation = WindowTranslation()

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        let factory = translation.factory(keyStore: environment.keyStore)
        Group {
            #if os(macOS)
            SidebarRootView(environment: environment, translatorFactory: factory)
            #else
            TabRootView(environment: environment, translatorFactory: factory)
            #endif
        }
        .modelContainer(environment.container)
        .systemTranslationHost(translation.bridge)
        .preferredColorScheme(environment.settings.appTheme.colorScheme)
        .tint(Theme.accent)
        .environment(\.locale, environment.settings.appLanguage.localeOverride ?? systemLocale)
    }
}

/// Content of the macOS Settings window.
public struct SettingsWindowContent: View {
    @Environment(\.locale) private var systemLocale
    private let environment: AppEnvironment
    @State private var translation = WindowTranslation()

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        SettingsView(
            settings: environment.settings,
            keyStore: environment.keyStore,
            translatorFactory: translation.factory(keyStore: environment.keyStore),
            showsDoneButton: false
        )
        .frame(width: 560, height: 720)
        .systemTranslationHost(translation.bridge)
        .preferredColorScheme(environment.settings.appTheme.colorScheme)
        .tint(Theme.accent)
        .environment(\.locale, environment.settings.appLanguage.localeOverride ?? systemLocale)
    }
}

/// Keeps translation prompts and their requests in the same window or sheet.
@MainActor
struct WindowTranslation {
    let bridge = SystemTranslationBridge()

    func factory(keyStore: any APIKeyStoring) -> TranslatorFactory {
        TranslatorFactory(keyStore: keyStore, systemTranslator: SystemTranslator(bridge: bridge))
    }
}
