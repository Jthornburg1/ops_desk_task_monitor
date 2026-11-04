import Observation

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case pending = "Pending"
}

@MainActor
@Observable
final class TaskDashboardViewModel {
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

    init(service: any TaskService) {
        self.service = service
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
            tasks = fetchedTasks
            hasLoaded = true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = hasLoaded
                ? "Unable to refresh tasks. Your previous tasks are still displayed. Please try again."
                : "Unable to load tasks. Check your connection and try again."
        }
    }
}
