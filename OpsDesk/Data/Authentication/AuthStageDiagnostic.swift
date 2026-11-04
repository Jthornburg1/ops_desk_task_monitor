import Amplify
import Foundation

// Temporary diagnostics: emit only fixed stage names, never SDK message contents.
nonisolated private struct AuthStageLogger: Logger {
    var logLevel: LogLevel = .verbose
    func verbose(_ message: @autoclosure () -> String) {
        let text = message()
        for stage in ["Wait for a valid state", "Start signIn flow", "Wait for signIn to complete",
                      "InitializeHostedUISignIn", "ShowHostedUISignIn", "Wait for signIn to cancel",
                      "Received result"] where text.contains(stage) {
            NSLog("AUTH_STAGE: %@", stage)
        }
    }
    func debug(_ message: @autoclosure () -> String) { verbose(message()) }
    func info(_ message: @autoclosure () -> String) { verbose(message()) }
    func warn(_ message: @autoclosure () -> String) { verbose(message()) }
    func error(_ message: @autoclosure () -> String) { verbose(message()) }
    func error(error: any Error) {}
}

nonisolated struct AuthStageDiagnostic: LoggingCategoryPlugin {
    let key = "AuthStageDiagnostic"
    var `default`: any Logger { AuthStageLogger() }
    func configure(using configuration: Any?) throws {}
    func reset() async {}
    func enable() {}
    func disable() {}
    func logger(forCategory category: String, logLevel: LogLevel) -> any Logger { AuthStageLogger() }
    func logger(forCategory category: String) -> any Logger { AuthStageLogger() }
    func logger(forNamespace namespace: String) -> any Logger { AuthStageLogger() }
    func logger(forCategory category: String, forNamespace namespace: String) -> any Logger { AuthStageLogger() }
}
