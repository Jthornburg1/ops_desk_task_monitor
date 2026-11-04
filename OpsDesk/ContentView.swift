import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    let viewModel: AuthViewModel
    let taskService: any TaskService

    var body: some View {
        Group {
            switch viewModel.state {
            case .checkingSession:
                ProgressView("Checking your session…")
            case .signedOut:
                ContentUnavailableView {
                    Label(viewModel.sessionMessage == nil ? "Sign in required" : "Session unavailable",
                          systemImage: "person.crop.circle")
                } description: {
                    Text(viewModel.sessionMessage ?? viewModel.signInMessage ?? "Sign in to view your operational tasks.")
                } actions: {
                    if viewModel.sessionMessage != nil {
                        Button("Retry session check") {
                            Task { await viewModel.checkSession() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isCheckingSession)
                    } else {
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
                }
            case .signedIn:
                if let userID = viewModel.userID {
                    NavigationStack {
                        VStack {
                            if let message = viewModel.sessionMessage {
                                VStack {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button("Retry session check") {
                                        Task { await viewModel.checkSession() }
                                    }
                                    .disabled(viewModel.isCheckingSession)
                                }
                                .padding(.horizontal)
                            }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.checkSession() }
            }
        }
    }
}

private struct PreviewAuthService: AuthService {
    func currentUserEmail() async -> String? { nil }
    func currentUserID() async -> String? { nil }
    func signOut() async -> SignOutOutcome { .failed }

    func signIn() async -> SignInOutcome { .failed }

    func sessionStatus() async -> SessionStatus { .signedOut }
}

private struct PreviewTaskService: TaskService {
    nonisolated func fetchTasks() async throws -> [OperationalTask] { [] }
}

#Preview {
    ContentView(viewModel: AuthViewModel(service: PreviewAuthService()), taskService: PreviewTaskService())
}
