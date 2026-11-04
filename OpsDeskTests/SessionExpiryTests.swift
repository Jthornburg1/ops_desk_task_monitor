import Amplify
import AWSPluginsCore
import Testing
@testable import OpsDesk

private struct ExpiryTokens: AuthCognitoTokens {
    let idToken = "test-id"
    let accessToken = "test-access"
    let refreshToken = "test-refresh"
}

private struct TokenSession: AuthSession, AuthCognitoTokensProvider {
    let isSignedIn = true
    let result: Result<any AuthCognitoTokens, AuthError>
    func getCognitoTokens() -> Result<any AuthCognitoTokens, AuthError> { result }
}

@MainActor
private final class LifecycleAuthService: AuthService {
    var status: SessionStatus = .valid
    func sessionStatus() async -> SessionStatus { status }
    func currentUserID() async -> String? { "account-a" }
    func currentUserEmail() async -> String? { "user@example.com" }
    var signOutCalls = 0
    var signInCalls = 0
    var signOutOutcome: SignOutOutcome = .signedOut
    func signIn() async -> SignInOutcome {
        signInCalls += 1
        return status == .expired && signOutCalls == 0 ? .failed : .signedIn
    }
    func signOut() async -> SignOutOutcome {
        signOutCalls += 1
        return signOutOutcome
    }
}

@MainActor
struct SessionExpiryTests {
    @Test
    func signedInFlagDoesNotHideExpiredTokenResult() async {
        let service = CognitoAuthService(fetchSession: {
            TokenSession(result: .failure(.sessionExpired("Expired", "Sign in")))
        })
        #expect(await service.sessionStatus() == .expired)
        let refreshed = CognitoAuthService(fetchSession: {
            TokenSession(result: .success(ExpiryTokens()))
        })
        #expect(await refreshed.sessionStatus() == .valid)
    }

    @Test
    func distinguishesThrownExpiryFromTemporaryFailure() async {
        let expired = CognitoAuthService(fetchSession: { throw AuthError.sessionExpired("Expired", "Sign in") })
        #expect(await expired.sessionStatus() == .expired)
        let unavailable = CognitoAuthService(fetchSession: {
            TokenSession(result: .failure(.service("Unavailable", "Retry")))
        })
        #expect(await unavailable.sessionStatus() == .unavailable)
    }

    @Test
    func expiryClearsIdentityAndAllowsSignInAgain() async {
        let service = LifecycleAuthService()
        let model = AuthViewModel(service: service)
        await model.checkSession()
        service.status = .expired
        await model.checkSession()
        #expect(model.state == .signedOut)
        #expect(model.userID == nil)
        #expect(model.userEmail == nil)
        #expect(model.signInMessage == "Your session has expired. Please sign in again.")
        await model.signIn()
        #expect(model.state == .signedIn)
        #expect(model.signInMessage == nil)
        #expect(service.signOutCalls == 1)
    }

    @Test
    func failedResetPreventsHostedSignInAndCanRetry() async {
        let service = LifecycleAuthService()
        service.status = .expired
        service.signOutOutcome = .failed
        let model = AuthViewModel(service: service)
        await model.checkSession()
        await model.signIn()
        #expect(model.state == .signedOut)
        #expect(service.signInCalls == 0)
        #expect(model.signInMessage == "Unable to reset your session. Please try again.")
        service.signOutOutcome = .locallySignedOut
        await model.signIn()
        #expect(model.state == .signedIn)
        #expect(service.signOutCalls == 2)
    }

    @Test
    func startupVerificationFailureOffersRetryBeforeSignIn() async {
        let service = LifecycleAuthService()
        service.status = .unavailable
        let model = AuthViewModel(service: service)
        await model.checkSession()
        #expect(model.state == .signedOut)
        #expect(model.userID == nil)
        #expect(model.sessionMessage != nil)
        await model.signIn()
        #expect(service.signInCalls == 0)
        service.status = .valid
        await model.checkSession()
        #expect(model.state == .signedIn)
        #expect(model.sessionMessage == nil)
    }

    @Test
    func temporaryFailurePreservesExistingAccountAndCanRetry() async {
        let service = LifecycleAuthService()
        let model = AuthViewModel(service: service)
        await model.checkSession()
        service.status = .unavailable
        await model.checkSession()
        #expect(model.state == .signedIn)
        #expect(model.userID == "account-a")
        #expect(model.userEmail == "user@example.com")
        #expect(model.sessionMessage != nil)
        service.status = .valid
        await model.checkSession()
        #expect(model.sessionMessage == nil)
    }
}
