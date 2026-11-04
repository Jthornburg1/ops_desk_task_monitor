nonisolated struct OperationalTask: Identifiable, Sendable, Equatable {
    let id: Int
    let title: String
    var completed: Bool
    let user: User?

    struct User: Sendable, Equatable {
        let id: Int
        let name: String
        let username: String
        let email: String
    }
}
