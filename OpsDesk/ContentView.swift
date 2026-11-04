import SwiftUI

struct ContentView: View {
    let viewModel: AuthViewModel
    let taskService: any TaskService

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
                if let userID = viewModel.userID {
                    NavigationStack {
                        VStack {
                            TaskDashboardView(service: taskService, userID: userID, userEmail: viewModel.userEmail)
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
                    .id(userID)
                } else {
                    ContentUnavailableView("Account unavailable", systemImage: "person.crop.circle.badge.exclamationmark",
                                           description: Text("Relaunch OpsDesk and sign in again."))
                }
            }
        }
        .task {
            await viewModel.checkSession()
        }
    }
}

private struct PreviewAuthService: AuthService {
    func currentUserEmail() async -> String? { nil }
    func currentUserID() async -> String? { nil }
    func signOut() async -> SignOutOutcome { .failed }

    func signIn() async -> SignInOutcome { .failed }

    func hasSession() async -> Bool { false }
}

private struct PreviewTaskService: TaskService {
    nonisolated func fetchTasks() async throws -> [OperationalTask] { [] }
}

#Preview {
    ContentView(viewModel: AuthViewModel(service: PreviewAuthService()), taskService: PreviewTaskService())
}
