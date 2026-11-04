import SwiftUI

struct ContentView: View {
    let viewModel: AuthViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .checkingSession:
                ProgressView("Checking your session…")
            case .signedOut:
                ContentUnavailableView(
                    "Sign in required",
                    systemImage: "person.crop.circle",
                    description: Text("Sign in to view your operational tasks.")
                )
            case .signedIn:
                // Replaced by the task dashboard in a later increment.
                ContentUnavailableView(
                    "Tasks",
                    systemImage: "checklist",
                    description: Text("Your operational tasks will appear here.")
                )
            }
        }
        .task {
            await viewModel.checkSession()
        }
    }
}

private struct PreviewAuthRepository: AuthRepository {
    func hasSession() async -> Bool { false }
}

#Preview {
    ContentView(viewModel: AuthViewModel(repository: PreviewAuthRepository()))
}
