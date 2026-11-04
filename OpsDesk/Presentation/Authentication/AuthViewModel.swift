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
    @ObservationIgnored private let service: any AuthService
    @ObservationIgnored private var isCheckingSession = false
    private(set) var userEmail: String?
    private(set) var userID: String?
    private(set) var state: AuthState = .checkingSession
    
    private(set) var isSigningIn = false
    private(set) var signInMessage: String?

    private(set) var isSigningOut = false
    private(set) var signOutMessage: String?

    func signOut() async {
        guard state == .signedIn, !isCheckingSession, !isSigningIn, !isSigningOut else { return }
        isSigningOut = true
        signOutMessage = nil
        defer { isSigningOut = false }

        switch await service.signOut() {
        case .signedOut:
            userEmail = nil
            userID = nil
            signInMessage = nil
            state = .signedOut
        case .locallySignedOut:
            userEmail = nil
            userID = nil
            signInMessage = "Signed out on this device. Provider sign-out was incomplete; signing in may reuse your browser session."
            state = .signedOut
        case .failed:
            signOutMessage = "Unable to sign out. Please try again."
        }
    }

    func signIn() async {
        // MainActor serializes entry; the guard remains set across the await.
        guard state == .signedOut, !isCheckingSession, !isSigningIn, !isSigningOut else { return }
        isSigningIn = true
        signInMessage = nil
        defer { isSigningIn = false }

        switch await service.signIn() {
        case .signedIn:
            await identifySignedInUser()
        case .cancelled:
            state = .signedOut
            signInMessage = "Sign-in cancelled. You can try again."
        case .failed:
            state = .signedOut
            signInMessage = "Unable to sign in. Please try again."
        }
    }

    init(service: any AuthService) {
        self.service = service
    }
    
    func checkSession() async {
        guard !isCheckingSession, !isSigningIn, !isSigningOut else { return }
        isCheckingSession = true
        defer { isCheckingSession = false }

        if await service.hasSession() {
            await identifySignedInUser()
        } else {
            userEmail = nil
            userID = nil
            state = .signedOut
        }
    }

    private func identifySignedInUser() async {
        guard let id = await service.currentUserID(), !id.isEmpty else {
            userEmail = nil
            userID = nil
            state = .signedOut
            signInMessage = "Unable to identify your account. Please sign in again."
            return
        }
        userEmail = await service.currentUserEmail()
        userID = id
        signInMessage = nil
        state = .signedIn
    }
}
