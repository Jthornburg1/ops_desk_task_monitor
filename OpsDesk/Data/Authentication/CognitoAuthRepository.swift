import Amplify
import AWSCognitoAuthPlugin

@MainActor
final class CognitoAuthRepository: AuthRepository {
    private let hostedSignIn: () async throws -> Bool
    private let fetchSession: () async throws -> any AuthSession

    init(fetchSession: @escaping () async throws -> any AuthSession = {
        try await Amplify.Auth.fetchAuthSession()
    }, hostedSignIn: @escaping () async throws -> Bool = {
        try await Amplify.Auth.signInWithWebUI().isSignedIn
    }) {
        self.hostedSignIn = hostedSignIn
        self.fetchSession = fetchSession
    }

    func signIn() async -> SignInOutcome {
        do {
            return try await hostedSignIn() ? .signedIn : .failed
        } catch let error as AuthError {
            if let cognitoError = error.underlyingError as? AWSCognitoAuthError,
               cognitoError == .userCancelled {
                return .cancelled
            }
            return .failed
        } catch {
            return .failed
        }
    }

    func hasSession() async -> Bool {
        do {
            let session = try await fetchSession()
            return session.isSignedIn
        } catch {
            return false
        }
    }
}
