import SwiftUI

struct TaskDashboardView: View {
    @State private var viewModel: TaskDashboardViewModel
    @State private var reloadID = 0

    init(service: any TaskService) {
        _viewModel = State(initialValue: TaskDashboardViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Task status", selection: $viewModel.selectedFilter) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                if viewModel.hasLoaded, let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                        Button("Retry") { reloadID += 1 }
                            .disabled(viewModel.isLoading)
                    }
                }

                ForEach(viewModel.filteredTasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.title)
                                .font(.headline)
                            Text(task.user?.name ?? "Unknown user")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Label(task.completed ? "Completed" : "Pending",
                                  systemImage: task.completed ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            // A new list identity resets scrolling when the filter changes.
            .id(viewModel.selectedFilter)
            .overlay {
                if !viewModel.hasLoaded {
                    if let message = viewModel.errorMessage {
                        ContentUnavailableView {
                            Label("Unable to load tasks", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Retry") { reloadID += 1 }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isLoading)
                        }
                    } else {
                        ProgressView("Loading tasks…")
                    }
                } else if viewModel.filteredTasks.isEmpty {
                    ContentUnavailableView {
                        Label(viewModel.selectedFilter == .all
                              ? "No tasks"
                              : "No \(viewModel.selectedFilter.rawValue.lowercased()) tasks",
                              systemImage: "checklist")
                    } description: {
                        Text(viewModel.tasks.isEmpty
                             ? "Pull down or tap Refresh to check again."
                             : "Choose another filter to see your other tasks.")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    reloadID += 1
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .accessibilityLabel("Refreshing tasks")
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        // SwiftUI cancels this request when the signed-in dashboard disappears.
        .task(id: reloadID) {
            if reloadID == 0 {
                await viewModel.loadIfNeeded()
            } else {
                await viewModel.refresh()
            }
        }
    }
}
