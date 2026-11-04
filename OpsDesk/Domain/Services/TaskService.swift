protocol TaskService: Sendable {
    nonisolated func fetchTasks() async throws -> [OperationalTask]
}
