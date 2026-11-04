import Testing
@testable import OpsDesk

@MainActor
struct AppDependenciesTests {
    @Test
    func successfulConfigurationCreatesAuthenticationPresentation() {
        var configureCount = 0
        let dependencies = AppDependencies(configureAuthentication: {
            configureCount += 1
        })

        #expect(configureCount == 1)
        switch dependencies.state {
        case .ready(let viewModel):
            #expect(viewModel.state == .checkingSession)
        case .configurationFailed:
            Issue.record("Successful setup should create the authentication ViewModel")
        }
    }

    @Test
    func configurationFailureBlocksNormalStartup() {
        enum SetupFailure: Error { case unavailable }
        var configureCount = 0
        let dependencies = AppDependencies(configureAuthentication: {
            configureCount += 1
            throw SetupFailure.unavailable
        })

        #expect(configureCount == 1)
        switch dependencies.state {
        case .ready:
            Issue.record("Failed configuration must not enable authentication")
        case .configurationFailed:
            break
        }
    }
}
