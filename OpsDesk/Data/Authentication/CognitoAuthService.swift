import AWSPluginsCore
import Amplify
import AWSCognitoAuthPlugin

@MainActor
final class CognitoAuthService: AuthService {
    private let fetchUserAttributes: () async throws -> [AuthUserAttribute]
    private let fetchUserID: () async throws -> String
    private let hostedSignOut: () async -> any AuthSignOutResult
    private let hostedSignIn: () async throws -> Bool
    private let fetchSession: () async throws -> any AuthSession

    init(fetchUserAttributes: @escaping () async throws -> [AuthUserAttribute] = {
        try await CognitoUserInfoService().fetchAttributes()
    }, fetchUserID: @escaping () async throws -> String = {
        try await Amplify.Auth.getCurrentUser().userId
    }, fetchSession: @escaping () async throws -> any AuthSession = {
        try await Amplify.Auth.fetchAuthSession()
    }, hostedSignIn: @escaping () async throws -> Bool = {
        try await Amplify.Auth.signInWithWebUI().isSignedIn
    }, hostedSignOut: @escaping () async -> any AuthSignOutResult = {
        await Amplify.Auth.signOut()
    }) {
        self.fetchUserAttributes = fetchUserAttributes
        self.fetchUserID = fetchUserID
        self.hostedSignOut = hostedSignOut
        self.hostedSignIn = hostedSignIn
        self.fetchSession = fetchSession
    }

    func currentUserEmail() async -> String? {
        guard let attributes = try? await fetchUserAttributes(),
              let email = attributes.first(where: { $0.key == .email })?.value,
              !email.isEmpty else { return nil }
        return email
    }

    func currentUserID() async -> String? {
        try? await fetchUserID()
    }

    func signOut() async -> SignOutOutcome {
        guard let result = await hostedSignOut() as? AWSCognitoSignOutResult else { return .failed }
        switch result {
        case .complete: return .signedOut
        case .partial: return .locallySignedOut
        case .failed: return .failed
        }
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

    func sessionStatus() async -> SessionStatus {
        do {
            // Amplify refreshes expired tokens when a usable refresh token exists.
            let session = try await fetchSession()
            guard session.isSignedIn else { return .signedOut }
            guard let provider = session as? any AuthCognitoTokensProvider else {
                return .unavailable
            }
            // isSignedIn alone remains true even after refresh-token expiry.
            let tokens = try provider.getCognitoTokens().get()
            guard !tokens.accessToken.isEmpty, !tokens.idToken.isEmpty else {
                return .unavailable
            }
            return .valid
        } catch let error as AuthError {
            switch error {
            case .sessionExpired, .notAuthorized: return .expired
            case .signedOut: return .signedOut
            default: return .unavailable
            }
        } catch {
            return .unavailable
        }
    }
}
