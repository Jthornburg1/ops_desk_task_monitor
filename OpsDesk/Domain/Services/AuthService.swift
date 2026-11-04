enum SignOutOutcome {
    case signedOut
    case locallySignedOut
    case failed
}

enum SignInOutcome {
    case signedIn
    case cancelled
    case failed
}

protocol AuthService {
    func currentUserID() async -> String?
    func hasSession() async -> Bool
    func signOut() async -> SignOutOutcome
    func signIn() async -> SignInOutcome
}
