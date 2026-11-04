import Foundation

nonisolated enum TaskNetworkError: Error, Equatable {
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int)
}

nonisolated struct RESTTaskService: TaskService {
    typealias Transport = @Sendable (URL) async throws -> (Data, URLResponse)

    private let transport: Transport

    init(transport: @escaping Transport = { url in
        try await URLSession.shared.data(from: url)
    }) {
        self.transport = transport
    }

    func fetchTasks() async throws -> [OperationalTask] {
        guard let todosURL = URL(string: Constants.todosEndpoint),
              let usersURL = URL(string: Constants.usersEndpoint) else {
            throw TaskNetworkError.invalidEndpoint
        }
        async let todos: [TodoDTO] = fetch(from: todosURL)
        async let users: [UserDTO] = fetch(from: usersURL)
        let (todoValues, userValues) = try await (todos, users)
        try Task.checkCancellation()

        // Keep the first entry if the server ever returns duplicate user IDs.
        let usersByID = Dictionary(userValues.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return todoValues.map { todo in
            let user = usersByID[todo.userId].map {
                OperationalTask.User(id: $0.id, name: $0.name, username: $0.username, email: $0.email)
            }
            return OperationalTask(id: todo.id, title: todo.title, completed: todo.completed, user: user)
        }
    }

    private func fetch<Value: Decodable & Sendable>(from url: URL) async throws -> Value {
        let (data, response) = try await transport(url)
        guard let response = response as? HTTPURLResponse else {
            throw TaskNetworkError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw TaskNetworkError.httpStatus(response.statusCode)
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }
}
