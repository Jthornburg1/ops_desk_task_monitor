import SwiftUI

struct ContentView: View {
    let viewModel: AuthViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .checkingSession:
                ProgressView("Checking your session…")
            case .signedOut:
                ContentUnavailableView {
                    Label("Sign in required", systemImage: "person.crop.circle")
                } description: {
                    Text(viewModel.signInMessage ?? "Sign in to view your operational tasks.")
                } actions: {
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isSigningIn {
                            ProgressView("Signing in…")
                        } else {
                            Text("Sign in")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSigningIn)
                }
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
    func signIn() async -> SignInOutcome { .failed }

    func hasSession() async -> Bool { false }
}

#Preview {
    ContentView(viewModel: AuthViewModel(repository: PreviewAuthRepository()))
}
