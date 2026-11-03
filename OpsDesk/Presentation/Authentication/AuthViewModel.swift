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

protocol AuthRepository {
    func hasSession() async -> Bool
}

@MainActor
final class AuthViewModel {
    private let repository: any AuthRepository
    private(set) var state: AuthState = .checkingSession
    
    init(repository: any AuthRepository) {
        self.repository = repository
    }
    
    func checkSession() async {
        let hasSession = await repository.hasSession()
        state = hasSession ? .signedIn : .signedOut
    }
}
