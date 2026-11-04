@MainActor
final class AppDependencies {
    enum State {
        case ready(AuthViewModel)
        case configurationFailed
    }

    // Amplify is process-wide. Lazy static initialization configures it only once.
    static let live = AppDependencies(configureAuthentication: CognitoConfiguration.configure)

    let taskService: any TaskService
    let state: State

    init(configureAuthentication: () throws -> Void, taskService: any TaskService = RESTTaskService()) {
        self.taskService = taskService
        do {
            try configureAuthentication()
            state = .ready(AuthViewModel(service: CognitoAuthService()))
        } catch {
            // Do not expose SDK error details that might contain sensitive values.
            state = .configurationFailed
        }
    }
}
