//
//  OpsDeskTests.swift
//  OpsDeskTests
//
//  Created by jonathan thornburg on 11/2/26.
//

import Observation
import Testing
@testable import OpsDesk

@MainActor
private final class SuspendedAuthService: AuthService {
    func currentUserID() async -> String? { "test-user" }
    private(set) var callCount = 0
    private var sessionContinuation: CheckedContinuation<Bool, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?

    func signOut() async -> SignOutOutcome { .failed }

    func signIn() async -> SignInOutcome { .failed }

    func hasSession() async -> Bool {
        callCount += 1
        guard callCount == 1 else { return false }

        return await withCheckedContinuation { continuation in
            sessionContinuation = continuation
            startedContinuation?.resume()
            startedContinuation = nil
        }
    }

    func waitUntilStarted() async {
        guard callCount == 0 else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func completeFirstCheck(sessionExists: Bool) {
        sessionContinuation?.resume(returning: sessionExists)
        sessionContinuation = nil
    }
}

private struct StubAuthService: AuthService {
    func currentUserID() async -> String? { "test-user" }
    var sessionExists = false
    
    func signOut() async -> SignOutOutcome { .failed }

    func signIn() async -> SignInOutcome { .failed }

    func hasSession() async -> Bool {
        sessionExists
    }
}

struct OpsDeskTests {
    @Test @MainActor
    func sessionStateChangesNotifyObservers() async {
        let viewModel = AuthViewModel(service: StubAuthService())

        await confirmation("Session state change notifies the UI") { changed in
            withObservationTracking {
                _ = viewModel.state
            } onChange: {
                changed()
            }

            await viewModel.checkSession()
            #expect(viewModel.state == .signedOut)
        }
    }

    @Test @MainActor
    func overlappingSessionChecksDoNotDuplicateWork() async {
        let service = SuspendedAuthService()
        let viewModel = AuthViewModel(service: service)
        let firstCheck = Task { await viewModel.checkSession() }
        await service.waitUntilStarted()

        await viewModel.checkSession()

        #expect(service.callCount == 1)
        #expect(viewModel.state == .checkingSession)

        service.completeFirstCheck(sessionExists: true)
        await firstCheck.value
        #expect(viewModel.state == .signedIn)

        // A completed check must not prevent a later lifecycle check.
        await viewModel.checkSession()
        #expect(service.callCount == 2)
        #expect(viewModel.state == .signedOut)
    }
    
    @Test @MainActor
    func checkSessionWithoutSavedUserSignsOut() async {
        let service = StubAuthService()
        let viewModel = AuthViewModel(service: service)
        
        await viewModel.checkSession()
        #expect(viewModel.state == .signedOut)
    }
    
    @Test @MainActor
    func checkSessionWithSavedUserSignsIn() async {
        let service = StubAuthService(sessionExists: true)
        let viewModel = AuthViewModel(service: service)
        
        await viewModel.checkSession()
        
        #expect(viewModel.state == .signedIn)
    }
}
