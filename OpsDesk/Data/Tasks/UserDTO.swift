nonisolated struct UserDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let username: String
    let email: String
}
