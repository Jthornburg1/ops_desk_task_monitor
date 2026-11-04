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
    private(set) var isCheckingSession = false
    @ObservationIgnored private var requiresSessionReset = false
    private(set) var sessionMessage: String?
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
            sessionMessage = nil
            requiresSessionReset = false
            userEmail = nil
            userID = nil
            signInMessage = nil
            state = .signedOut
        case .locallySignedOut:
            sessionMessage = nil
            requiresSessionReset = false
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
        guard state == .signedOut, sessionMessage == nil, !isCheckingSession, !isSigningIn, !isSigningOut else { return }
        isSigningIn = true
        signInMessage = nil
        defer { isSigningIn = false }

        if requiresSessionReset {
            // The SDK can retain signed-in state after expiry; reset before hosted sign-in.
            switch await service.signOut() {
            case .signedOut, .locallySignedOut:
                requiresSessionReset = false
            case .failed:
                signInMessage = "Unable to reset your session. Please try again."
                return
            }
        }

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

        switch await service.sessionStatus() {
        case .valid:
            sessionMessage = nil
            requiresSessionReset = false
            await identifySignedInUser()
        case .signedOut:
            sessionMessage = nil
            requiresSessionReset = false
            if state == .signedIn {
                signInMessage = "Your session has ended. Please sign in again."
            }
            userEmail = nil
            userID = nil
            state = .signedOut
        case .expired:
            sessionMessage = nil
            requiresSessionReset = true
            userEmail = nil
            userID = nil
            signOutMessage = nil
            signInMessage = "Your session has expired. Please sign in again."
            state = .signedOut
        case .unavailable:
            sessionMessage = "Unable to verify your session. Check your connection and try again."
            // A temporary failure is not proof of expiry. Preserve an existing dashboard.
            if state != .signedIn {
                userEmail = nil
                userID = nil
                state = .signedOut
            }
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
        sessionMessage = nil
        signOutMessage = nil
        userEmail = await service.currentUserEmail()
        userID = id
        signInMessage = nil
        state = .signedIn
    }
}
