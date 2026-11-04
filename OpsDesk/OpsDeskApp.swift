import SwiftUI

@main struct OpsDeskApp: App {
    private let dependencies = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            switch dependencies.state {
            case .ready:
                ContentView()
            case .configurationFailed:
                ContentUnavailableView(
                    "Authentication setup failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Check the app’s Cognito configuration and relaunch OpsDesk.")
                )
            }
        }
    }
}
