enum SignInOutcome {
    case signedIn
    case cancelled
    case failed
}

protocol AuthRepository {
    func hasSession() async -> Bool
    func signIn() async -> SignInOutcome
}
