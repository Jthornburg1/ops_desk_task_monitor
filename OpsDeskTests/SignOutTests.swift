import Amplify
import AWSCognitoAuthPlugin
import Testing
@testable import OpsDesk

@MainActor
private final class LogoutService: AuthService {
    var outcome: SignOutOutcome = .signedOut
    var count = 0
    var sessionCount = 0
    var suspend = false
    var continuation: CheckedContinuation<SignOutOutcome, Never>?
    var started: CheckedContinuation<Void, Never>?
    func hasSession() async -> Bool { sessionCount += 1; return true }
    func signIn() async -> SignInOutcome { .signedIn }
    func signOut() async -> SignOutOutcome {
        count += 1
        guard suspend else { return outcome }
        return await withCheckedContinuation {
            continuation = $0
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if count == 0 { await withCheckedContinuation { started = $0 } }
    }
}

@MainActor
struct SignOutTests {
    @Test
    func mapsSDKLogoutResults() async {
        let complete = CognitoAuthService(hostedSignOut: { AWSCognitoSignOutResult.complete })
        #expect(await complete.signOut() == .signedOut)
        let partial = CognitoAuthService(hostedSignOut: {
            AWSCognitoSignOutResult.partial(revokeTokenError: nil, globalSignOutError: nil, hostedUIError: nil)
        })
        #expect(await partial.signOut() == .locallySignedOut)
        let failed = CognitoAuthService(hostedSignOut: {
            AWSCognitoSignOutResult.failed(AuthError.service("Unavailable", "Retry"))
        })
        #expect(await failed.signOut() == .failed)
    }

    @Test(arguments: [SignOutOutcome.signedOut, .locallySignedOut, .failed])
    func routesLogoutAndAllowsRetry(outcome: SignOutOutcome) async {
        let service = LogoutService()
        service.outcome = outcome
        let model = AuthViewModel(service: service)
        await model.checkSession()
        await model.signOut()
        #expect(service.count == 1)
        #expect(!model.isSigningOut)
        switch outcome {
        case .signedOut:
            #expect(model.state == .signedOut)
            #expect(model.signInMessage == nil)
        case .locallySignedOut:
            #expect(model.state == .signedOut)
            #expect(model.signInMessage != nil)
        case .failed:
            #expect(model.state == .signedIn)
            #expect(model.signOutMessage != nil)
            service.outcome = .signedOut
            await model.signOut()
            #expect(service.count == 2)
            #expect(model.state == .signedOut)
            #expect(model.signOutMessage == nil)
        }
        await model.signOut()
        #expect(service.count == (outcome == .failed ? 2 : 1))
    }

    @Test
    func pendingLogoutBlocksDuplicateAndSessionCheck() async {
        let service = LogoutService()
        service.suspend = true
        let model = AuthViewModel(service: service)
        await model.checkSession()
        let first = Task { await model.signOut() }
        await service.waitUntilStarted()
        #expect(model.isSigningOut)
        await model.signOut()
        await model.checkSession()
        await model.signIn()
        #expect(service.count == 1)
        #expect(service.sessionCount == 1)
        #expect(model.isSigningOut)
        service.continuation?.resume(returning: .signedOut)
        await first.value
        #expect(model.state == .signedOut)
        #expect(!model.isSigningOut)
    }
}
