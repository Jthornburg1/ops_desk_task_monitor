import Amplify

@MainActor
final class CognitoAuthRepository: AuthRepository {
    private let fetchSession: () async throws -> any AuthSession

    init(fetchSession: @escaping () async throws -> any AuthSession = {
        try await Amplify.Auth.fetchAuthSession()
    }) {
        self.fetchSession = fetchSession
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
