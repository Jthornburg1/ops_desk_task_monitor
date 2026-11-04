import Testing
@testable import OpsDesk

private actor DashboardTaskService: TaskService {
    enum Failure: Error { case offline }
    var values: [OperationalTask] = []
    var fails = false
    var count = 0
    var suspend = false
    var continuation: CheckedContinuation<[OperationalTask], any Error>?

    func configure(values: [OperationalTask] = [], fails: Bool = false, suspend: Bool = false) {
        self.values = values
        self.fails = fails
        self.suspend = suspend
    }

    func fetchTasks() async throws -> [OperationalTask] {
        count += 1
        if suspend {
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        if fails { throw Failure.offline }
        return values
    }

    func finish(cancelled: Bool = false) {
        if cancelled { continuation?.resume(throwing: CancellationError()) }
        else { continuation?.resume(returning: values) }
        continuation = nil
    }
}

@MainActor
private final class MemoryCompletionService: TaskCompletionService {
    private var values: [Int: Bool] = [:]
    func overrides() -> [Int: Bool] { values }
    func setCompleted(_ completed: Bool, for taskID: Int) { values[taskID] = completed }
}

@MainActor
struct TaskDashboardViewModelTests {
    private var example: OperationalTask {
        OperationalTask(id: 1, title: "Inspect cooling", completed: false, user: nil)
    }

    @Test
    func loadsTasksOnlyOnceUntilExplicitRefresh() async {
        let service = DashboardTaskService()
        await service.configure(values: [example])
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        #expect(!model.hasLoaded)
        await model.loadIfNeeded()
        #expect(model.tasks == [example])
        #expect(model.hasLoaded)
        #expect(!model.isLoading)
        #expect(model.errorMessage == nil)
        await model.loadIfNeeded()
        #expect(await service.count == 1)
        await service.configure()
        await model.refresh()
        #expect(await service.count == 2)
        #expect(model.tasks.isEmpty)
        #expect(model.hasLoaded)
    }

    @Test
    func initialFailureAllowsRetry() async {
        let service = DashboardTaskService()
        await service.configure(fails: true)
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        await model.loadIfNeeded()
        #expect(model.errorMessage != nil)
        #expect(!model.hasLoaded)
        #expect(!model.isLoading)
        await service.configure(values: [example])
        await model.refresh()
        #expect(model.tasks == [example])
        #expect(model.errorMessage == nil)
        #expect(model.hasLoaded)
    }

    @Test
    func refreshFailurePreservesDisplayedTasks() async {
        let service = DashboardTaskService()
        await service.configure(values: [example])
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        await model.loadIfNeeded()
        await service.configure(fails: true)
        await model.refresh()
        #expect(model.tasks == [example])
        #expect(model.errorMessage != nil)
        #expect(model.hasLoaded)
        #expect(!model.isLoading)
    }

    @Test
    func pendingLoadBlocksDuplicateAndShowsProgress() async {
        let service = DashboardTaskService()
        await service.configure(values: [example], suspend: true)
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        let first = Task { await model.loadIfNeeded() }
        // Bounded waiting also permits a no-op implementation to fail without hanging.
        for _ in 0..<1000 {
            if await service.count > 0 { break }
            await Task.yield()
        }
        #expect(model.isLoading)
        await model.refresh()
        await model.loadIfNeeded()
        #expect(await service.count == 1)
        await service.finish()
        await first.value
        #expect(model.tasks == [example])
        #expect(!model.isLoading)
    }

    @Test
    func cancelledRequestCannotPublishLateResults() async {
        let service = DashboardTaskService()
        await service.configure(values: [example], suspend: true)
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        let first = Task { await model.loadIfNeeded() }
        for _ in 0..<1000 {
            if await service.count > 0 { break }
            await Task.yield()
        }
        first.cancel()
        await service.finish()
        await first.value
        #expect(model.tasks.isEmpty)
        #expect(!model.hasLoaded)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test
    func cancelledLoadDoesNotShowAnErrorAndCanRetry() async {
        let service = DashboardTaskService()
        await service.configure(suspend: true)
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        let first = Task { await model.loadIfNeeded() }
        for _ in 0..<1000 {
            if await service.count > 0 { break }
            await Task.yield()
        }
        await service.finish(cancelled: true)
        await first.value
        #expect(model.errorMessage == nil)
        #expect(!model.hasLoaded)
        #expect(!model.isLoading)
        await service.configure(values: [example])
        await model.loadIfNeeded()
        #expect(model.tasks == [example])
    }
    @Test
    func filtersTasksLocallyAndDefaultsToAll() async {
        let service = DashboardTaskService()
        let pending = example
        let completed = OperationalTask(id: 2, title: "Review report", completed: true, user: nil)
        await service.configure(values: [pending, completed])
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        await model.loadIfNeeded()
        #expect(model.selectedFilter == .all)
        #expect(model.filteredTasks == [pending, completed])
        model.selectedFilter = .completed
        #expect(model.filteredTasks == [completed])
        model.selectedFilter = .pending
        #expect(model.filteredTasks == [pending])
        model.selectedFilter = .all
        #expect(model.filteredTasks == [pending, completed])
        #expect(await service.count == 1)
        #expect(model.tasks == [pending, completed])
    }

    @Test
    func selectedFilterSurvivesRefreshAndCanHaveNoMatches() async {
        let service = DashboardTaskService()
        await service.configure(values: [example])
        let model = TaskDashboardViewModel(service: service, completionService: MemoryCompletionService())
        model.selectedFilter = .completed
        await model.loadIfNeeded()
        #expect(model.filteredTasks.isEmpty)
        let completed = OperationalTask(id: 2, title: "Review report", completed: true, user: nil)
        await service.configure(values: [completed])
        await model.refresh()
        #expect(model.selectedFilter == .completed)
        #expect(model.filteredTasks == [completed])
    }

}
