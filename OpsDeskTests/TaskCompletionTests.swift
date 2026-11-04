import Foundation
import Testing
@testable import OpsDesk

@MainActor
private final class IdentityAuthService: AuthService {
    var id: String? = "user-a"
    var session = true
    var logout: SignOutOutcome = .signedOut
    var email: String? = "first@example.com"
    func currentUserEmail() async -> String? { email }
    func currentUserID() async -> String? { id }
    func sessionStatus() async -> SessionStatus { session ? .valid : .signedOut }
    func signIn() async -> SignInOutcome { session = true; return .signedIn }
    func signOut() async -> SignOutOutcome { logout }
}

private actor CompletionTaskService: TaskService {
    var completed = false
    func configure(completed: Bool) { self.completed = completed }
    func fetchTasks() async throws -> [OperationalTask] {
        [OperationalTask(id: 1, title: "Inspect cooling", completed: completed, user: nil)]
    }
}

@MainActor
struct TaskCompletionTests {
    @Test
    func persistsBothStatusesAndSeparatesAccounts() throws {
        let suite = "OpsDeskTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = UserDefaultsTaskCompletionService(defaults: defaults, userID: "user-a")
        first.setCompleted(true, for: 1)
        first.setCompleted(false, for: 2)
        let relaunched = UserDefaultsTaskCompletionService(defaults: defaults, userID: "user-a")
        #expect(relaunched.overrides() == [1: true, 2: false])
        let second = UserDefaultsTaskCompletionService(defaults: defaults, userID: "user-b")
        #expect(second.overrides().isEmpty)
        second.setCompleted(false, for: 1)
        #expect(first.overrides()[1] == true)
        #expect(second.overrides()[1] == false)
    }

    @Test
    func togglesUpdateFiltersAndSurviveRefreshAndNewModel() async throws {
        let suite = "OpsDeskTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = UserDefaultsTaskCompletionService(defaults: defaults, userID: "user-a")
        let service = CompletionTaskService()
        let model = TaskDashboardViewModel(service: service, completionService: storage)
        await model.loadIfNeeded()
        model.selectedFilter = .pending
        model.setCompleted(true, taskID: 1)
        #expect(model.tasks.first?.completed == true)
        #expect(model.filteredTasks.isEmpty)
        await model.refresh()
        #expect(model.tasks.first?.completed == true)
        let restored = TaskDashboardViewModel(service: service, completionService:
            UserDefaultsTaskCompletionService(defaults: defaults, userID: "user-a"))
        await restored.loadIfNeeded()
        #expect(restored.tasks.first?.completed == true)
        restored.setCompleted(false, taskID: 1)
        await service.configure(completed: true)
        await restored.refresh()
        #expect(restored.tasks.first?.completed == false)
        let otherAccount = TaskDashboardViewModel(service: service, completionService:
            UserDefaultsTaskCompletionService(defaults: defaults, userID: "user-b"))
        await otherAccount.loadIfNeeded()
        #expect(otherAccount.tasks.first?.completed == true)
        restored.setCompleted(true, taskID: 999)
        #expect(storage.overrides()[999] == nil)
    }

    @Test
    func identityIsRequiredAndClearedOnLogoutBeforeAnotherAccount() async {
        let service = IdentityAuthService()
        let model = AuthViewModel(service: service)
        await model.checkSession()
        #expect(model.userID == "user-a")
        #expect(model.userEmail == "first@example.com")
        service.logout = .failed
        await model.signOut()
        #expect(model.userID == "user-a")
        #expect(model.userEmail == "first@example.com")
        service.logout = .signedOut
        await model.signOut()
        #expect(model.userID == nil)
        #expect(model.userEmail == nil)
        service.id = "user-b"
        service.email = "second@example.com"
        await model.signIn()
        #expect(model.userID == "user-b")
        #expect(model.userEmail == "second@example.com")
        await model.signOut()
        service.id = nil
        await model.signIn()
        #expect(model.state == .signedOut)
        #expect(model.userID == nil)
        #expect(model.userEmail == nil)
        #expect(model.signInMessage != nil)
        service.id = ""
        await model.checkSession()
        #expect(model.state == .signedOut)
        #expect(model.userID == nil)
        #expect(model.userEmail == nil)
    }

    @Test
    func missingEmailDoesNotPreventSignIn() async {
        let service = IdentityAuthService()
        service.email = nil
        let model = AuthViewModel(service: service)
        await model.checkSession()
        #expect(model.state == .signedIn)
        #expect(model.userEmail == nil)
    }

    @Test
    func adapterUsesStableSDKIdentityAndHandlesFailure() async {
        let service = CognitoAuthService(fetchUserID: { "stable-subject" })
        #expect(await service.currentUserID() == "stable-subject")
        enum Failure: Error { case unavailable }
        let failing = CognitoAuthService(fetchUserID: { throw Failure.unavailable })
        #expect(await failing.currentUserID() == nil)
    }
}
