import AppFeature
import SwiftUI

@main
struct ReadlyApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
        #if os(macOS)
        .defaultSize(width: 1040, height: 760)
        #endif

        #if os(macOS)
        Settings {
            SettingsWindowContent(environment: environment)
        }
        #endif
    }
}
