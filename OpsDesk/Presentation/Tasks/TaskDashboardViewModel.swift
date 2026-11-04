import Observation

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case pending = "Pending"
}

@MainActor
@Observable
final class TaskDashboardViewModel {
    @ObservationIgnored private let completionService: any TaskCompletionService
    @ObservationIgnored private let service: any TaskService
    var selectedFilter: TaskFilter = .all
    var filteredTasks: [OperationalTask] {
        switch selectedFilter {
        case .all: tasks
        case .completed: tasks.filter { $0.completed }
        case .pending: tasks.filter { !$0.completed }
        }
    }

    private(set) var tasks: [OperationalTask] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    init(service: any TaskService, completionService: any TaskCompletionService) {
        self.service = service
        self.completionService = completionService
    }

    func setCompleted(_ completed: Bool, taskID: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        completionService.setCompleted(completed, for: taskID)
        tasks[index].completed = completed
    }


    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading, !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedTasks = try await service.fetchTasks()
            try Task.checkCancellation()
            // Read after the await so a toggle during refresh is retained.
            let overrides = completionService.overrides()
            tasks = fetchedTasks.map { task in
                var task = task
                task.completed = overrides[task.id] ?? task.completed
                return task
            }
            hasLoaded = true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = hasLoaded
                ? "Unable to refresh tasks. Your previous tasks are still displayed. Please try again."
                : "Unable to load tasks. Check your connection and try again."
        }
    }
}
