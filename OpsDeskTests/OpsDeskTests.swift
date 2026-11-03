//
//  OpsDeskTests.swift
//  OpsDeskTests
//
//  Created by jonathan thornburg on 11/2/26.
//

import Testing
@testable import OpsDesk

private struct StubAuthRepository: AuthRepository {
    func hasSession() async -> Bool {
        false
    }
}

struct OpsDeskTests {
    
    @Test
    @MainActor
    func checkSessionWithoutSavedUserSignsOut() async {
        let repository = StubAuthRepository()
        let viewModel = AuthViewModel(repository: repository)
        
        await viewModel.checkSession()
        #expect(viewModel.state == .signedOut)
    }
}
