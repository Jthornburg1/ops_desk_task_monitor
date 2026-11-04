import Foundation

@MainActor
final class UserDefaultsTaskCompletionService: TaskCompletionService {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, userID: String) {
        precondition(!userID.isEmpty)
        self.defaults = defaults
        self.key = "taskCompletion.v1." + userID
    }

    func overrides() -> [Int: Bool] {
        let saved = defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return saved.reduce(into: [:]) { result, entry in
            if let id = Int(entry.key) { result[id] = entry.value }
        }
    }

    func setCompleted(_ completed: Bool, for taskID: Int) {
        var saved = defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
        saved[String(taskID)] = completed
        defaults.set(saved, forKey: key)
    }
}
