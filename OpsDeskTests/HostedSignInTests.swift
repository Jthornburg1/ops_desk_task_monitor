import Amplify
import AWSCognitoAuthPlugin
import Testing
@testable import OpsDesk

@MainActor
private final class SignInRepository: AuthRepository {
    var outcome: SignInOutcome = .signedIn
    var signInCount = 0
    var sessionCount = 0
    var continuation: CheckedContinuation<SignInOutcome, Never>?
    var started: CheckedContinuation<Void, Never>?
    var suspend = false

    func hasSession() async -> Bool { sessionCount += 1; return false }
    func signIn() async -> SignInOutcome {
        signInCount += 1
        guard suspend && signInCount == 1 else { return outcome }
        return await withCheckedContinuation {
            continuation = $0
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        guard signInCount == 0 else { return }
        await withCheckedContinuation { started = $0 }
    }
}

@MainActor
struct HostedSignInTests {
    @Test(arguments: [SignInOutcome.signedIn, .cancelled, .failed])
    func presentsSignInOutcome(outcome: SignInOutcome) async {
        let repository = SignInRepository()
        repository.outcome = outcome
        let model = AuthViewModel(repository: repository)
        await model.checkSession()
        await model.signIn()
        #expect(repository.signInCount == 1)
        #expect(!model.isSigningIn)
        switch outcome {
        case .signedIn:
            #expect(model.state == .signedIn)
            #expect(model.signInMessage == nil)
        case .cancelled:
            #expect(model.state == .signedOut)
            #expect(model.signInMessage == "Sign-in cancelled. You can try again.")
        case .failed:
            #expect(model.state == .signedOut)
            #expect(model.signInMessage == "Unable to sign in. Please try again.")
        }
    }

    @Test
    func failureAllowsRetryAndClearsMessage() async {
        let repository = SignInRepository()
        repository.outcome = .failed
        let model = AuthViewModel(repository: repository)
        await model.checkSession()
        await model.signIn()
        #expect(model.signInMessage != nil)
        repository.outcome = .signedIn
        await model.signIn()
        #expect(repository.signInCount == 2)
        #expect(model.state == .signedIn)
        #expect(model.signInMessage == nil)
    }

    @Test
    func pendingSignInRejectsDuplicateAndSessionCheck() async {
        let repository = SignInRepository()
        repository.suspend = true
        let model = AuthViewModel(repository: repository)
        await model.checkSession()
        let first = Task { await model.signIn() }
        await repository.waitUntilStarted()
        #expect(model.isSigningIn)

        await model.signIn()
        await model.checkSession()
        #expect(repository.signInCount == 1)
        #expect(repository.sessionCount == 1)
        #expect(model.isSigningIn)
        #expect(model.state == .signedOut)

        repository.continuation?.resume(returning: .signedIn)
        repository.continuation = nil
        await first.value
        #expect(model.state == .signedIn)
        #expect(!model.isSigningIn)
    }

    @Test
    func mapsHostedSDKResultsAndCancellation() async {
        var count = 0
        let success = CognitoAuthRepository(hostedSignIn: { count += 1; return true })
        #expect(await success.signIn() == .signedIn)
        #expect(count == 1)
        let incomplete = CognitoAuthRepository(hostedSignIn: { false })
        #expect(await incomplete.signIn() == .failed)
        let cancelled = CognitoAuthRepository(hostedSignIn: {
            throw AuthError.service("Cancelled", "Retry", AWSCognitoAuthError.userCancelled)
        })
        #expect(await cancelled.signIn() == .cancelled)
        let failure = CognitoAuthRepository(hostedSignIn: {
            throw AuthError.service("Unavailable", "Retry")
        })
        #expect(await failure.signIn() == .failed)
    }
}
