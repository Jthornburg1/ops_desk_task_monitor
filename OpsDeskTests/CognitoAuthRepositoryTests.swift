import Amplify
import Testing
@testable import OpsDesk

private struct StubAuthSession: AuthSession {
    let isSignedIn: Bool
}

private enum SessionFailure: Error {
    case unavailable
}

@MainActor
struct CognitoAuthRepositoryTests {
    @Test(arguments: [true, false])
    func mapsSDKSessionState(isSignedIn: Bool) async {
        var fetchCount = 0
        let repository = CognitoAuthRepository(fetchSession: {
            fetchCount += 1
            return StubAuthSession(isSignedIn: isSignedIn)
        })

        let hasSession = await repository.hasSession()

        #expect(fetchCount == 1)
        #expect(hasSession == isSignedIn)
    }

    @Test
    func sessionFetchFailureDoesNotReportSignedIn() async {
        var fetchCount = 0
        let repository = CognitoAuthRepository(fetchSession: {
            fetchCount += 1
            throw SessionFailure.unavailable
        })

        let hasSession = await repository.hasSession()

        #expect(fetchCount == 1)
        #expect(!hasSession)
    }
}
