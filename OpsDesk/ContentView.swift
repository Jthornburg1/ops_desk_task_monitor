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
                NavigationStack {
                    VStack {
                        ContentUnavailableView(
                            "Tasks",
                            systemImage: "checklist",
                            description: Text("Your operational tasks will appear here.")
                        )
                        if let message = viewModel.signOutMessage {
                            Text(message)
                                .foregroundStyle(.red)
                                .padding()
                                .accessibilityIdentifier("signOutError")
                        }
                    }
                    .navigationTitle("Tasks")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task { await viewModel.signOut() }
                            } label: {
                                if viewModel.isSigningOut {
                                    ProgressView("Signing out…")
                                } else {
                                    Text("Log out")
                                }
                            }
                            .disabled(viewModel.isSigningOut)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.checkSession()
        }
    }
}

private struct PreviewAuthService: AuthService {
    func signOut() async -> SignOutOutcome { .failed }

    func signIn() async -> SignInOutcome { .failed }

    func hasSession() async -> Bool { false }
}

#Preview {
    ContentView(viewModel: AuthViewModel(service: PreviewAuthService()))
}
