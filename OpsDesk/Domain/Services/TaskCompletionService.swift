protocol TaskCompletionService {
    func overrides() -> [Int: Bool]
    func setCompleted(_ completed: Bool, for taskID: Int)
}
