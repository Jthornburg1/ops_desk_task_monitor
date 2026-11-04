struct TodoDTO: Decodable, Sendable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}
