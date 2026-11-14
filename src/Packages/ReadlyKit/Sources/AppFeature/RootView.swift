import DesignSystem
import SettingsFeature
import SwiftData
import SwiftUI
import SystemTranslation

public struct RootView: View {
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        Group {
            #if os(macOS)
            SidebarRootView(environment: environment)
            #else
            TabRootView(environment: environment)
            #endif
        }
        .modelContainer(environment.container)
        .systemTranslationHost(environment.systemTranslation)
        .tint(Theme.accent)
    }
}

/// Content of the macOS Settings window.
public struct SettingsWindowContent: View {
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        SettingsView(
                settings: environment.settings,
                keyStore: environment.keyStore,
                translatorFactory: environment.translatorFactory,
                showsDoneButton: false
            )
            .frame(width: 560, height: 720)
            .systemTranslationHost(environment.systemTranslation)
            .tint(Theme.accent)
    }
}
