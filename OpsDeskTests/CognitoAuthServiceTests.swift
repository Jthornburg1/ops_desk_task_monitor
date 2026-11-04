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
struct CognitoAuthServiceTests {
    @Test
    func readsEmailAttributeAndHandlesUnavailableEmail() async {
        var calls = 0
        let service = CognitoAuthService(fetchUserAttributes: {
            calls += 1
            return [AuthUserAttribute(.sub, value: "subject"),
                    AuthUserAttribute(.email, value: "user@example.com")]
        })
        #expect(await service.currentUserEmail() == "user@example.com")
        #expect(calls == 1)
        let missing = CognitoAuthService(fetchUserAttributes: { [] })
        #expect(await missing.currentUserEmail() == nil)
        let empty = CognitoAuthService(fetchUserAttributes: { [AuthUserAttribute(.email, value: "")] })
        #expect(await empty.currentUserEmail() == nil)
        let failing = CognitoAuthService(fetchUserAttributes: { throw SessionFailure.unavailable })
        #expect(await failing.currentUserEmail() == nil)
    }

    @Test(arguments: [true, false])
    func mapsSDKSessionState(isSignedIn: Bool) async {
        var fetchCount = 0
        let service = CognitoAuthService(fetchSession: {
            fetchCount += 1
            return StubAuthSession(isSignedIn: isSignedIn)
        })

        let hasSession = await service.hasSession()

        #expect(fetchCount == 1)
        #expect(hasSession == isSignedIn)
    }

    @Test
    func sessionFetchFailureDoesNotReportSignedIn() async {
        var fetchCount = 0
        let service = CognitoAuthService(fetchSession: {
            fetchCount += 1
            throw SessionFailure.unavailable
        })

        let hasSession = await service.hasSession()

        #expect(fetchCount == 1)
        #expect(!hasSession)
    }
}
