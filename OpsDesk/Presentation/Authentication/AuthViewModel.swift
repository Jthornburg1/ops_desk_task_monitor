//
//  AuthViewModel.swift
//  OpsDesk
//
//  Created by jonathan thornburg on 11/3/26.
//

import Observation

enum AuthState {
    case checkingSession
    case signedOut
    case signedIn
}

@MainActor
@Observable
final class AuthViewModel {
    @ObservationIgnored private let repository: any AuthRepository
    @ObservationIgnored private var isCheckingSession = false
    private(set) var state: AuthState = .checkingSession
    
    private(set) var isSigningIn = false
    private(set) var signInMessage: String?

    func signIn() async {
        // MainActor serializes entry; the guard remains set across the await.
        guard state == .signedOut, !isCheckingSession, !isSigningIn else { return }
        isSigningIn = true
        signInMessage = nil
        defer { isSigningIn = false }

        switch await repository.signIn() {
        case .signedIn:
            state = .signedIn
        case .cancelled:
            state = .signedOut
            signInMessage = "Sign-in cancelled. You can try again."
        case .failed:
            state = .signedOut
            signInMessage = "Unable to sign in. Please try again."
        }
    }

    init(repository: any AuthRepository) {
        self.repository = repository
    }
    
    func checkSession() async {
        guard !isCheckingSession, !isSigningIn else { return }
        isCheckingSession = true
        defer { isCheckingSession = false }

        let hasSession = await repository.hasSession()
        state = hasSession ? .signedIn : .signedOut
    }
}
