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

enum SessionStatus {
    case valid
    case signedOut
    case expired
    case unavailable
}

protocol AuthService {
    func currentUserEmail() async -> String?
    func currentUserID() async -> String?
    func sessionStatus() async -> SessionStatus
    func signOut() async -> SignOutOutcome
    func signIn() async -> SignInOutcome
}
