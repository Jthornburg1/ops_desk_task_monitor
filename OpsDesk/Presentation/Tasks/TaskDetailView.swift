import SwiftUI

struct TaskDetailView: View {
    @Binding var task: OperationalTask

    var body: some View {
        Form {
            Section {
                Text(task.title)
                    .font(.headline)
                    .textSelection(.enabled)
                LabeledContent("Task ID", value: String(task.id))
                Toggle("Completed", isOn: $task.completed)
            } header: {
                Text("Task")
            } footer: {
                Text("Changes are saved on this device for your signed-in account and retained after refresh and relaunch.")
            }

            Section("Assigned user") {
                if let user = task.user {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Username", value: user.username)
                    LabeledContent("Email", value: user.email)
                        .textSelection(.enabled)
                } else {
                    Text("User information is unavailable for this task.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Task details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Pending task") {
    NavigationStack {
        TaskDetailView(task: .constant(OperationalTask(
            id: 1, title: "Inspect cooling system", completed: false,
            user: .init(id: 1, name: "Alex Morgan", username: "amorgan",
                        email: "alex@example.com"))))
    }
}

#Preview("Completed task without user") {
    NavigationStack {
        TaskDetailView(task: .constant(OperationalTask(
            id: 2, title: "Review maintenance report", completed: true, user: nil)))
    }
}
