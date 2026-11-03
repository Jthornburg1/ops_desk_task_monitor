//
//  AuthViewModel.swift
//  OpsDesk
//
//  Created by jonathan thornburg on 11/3/26.
//

enum AuthState {
    case checkingSession
    case signedOut
    case signedIn
}

@MainActor
final class AuthViewModel {
    private let repository: any AuthRepository
    private var isCheckingSession = false
    private(set) var state: AuthState = .checkingSession
    
    init(repository: any AuthRepository) {
        self.repository = repository
    }
    
    func checkSession() async {
        guard !isCheckingSession else { return }
        isCheckingSession = true
        defer { isCheckingSession = false }

        let hasSession = await repository.hasSession()
        state = hasSession ? .signedIn : .signedOut
    }
}
