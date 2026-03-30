import SwiftUI

struct BackgroundTaskMonitorView: View {
    @State private var tasks: [AppTask] = [
        AppTask(name: "Indexing Project", status: .running, progress: 0.65),
        AppTask(name: "Pushing to GitHub", status: .waiting, progress: 0),
        AppTask(name: "Syncing Collaboration State", status: .running, progress: 0.12),
        AppTask(name: "Cleaning Cache", status: .completed, progress: 1.0)
    ]

    var body: some View {
        List {
            Section("Active Tasks") {
                ForEach(tasks) { task in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.name)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(task.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(statusColor(task.status))
                        }

                        if task.status == .running {
                            ProgressView(value: task.progress)
                                .tint(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("System State") {
                LabeledContent("Background Refresh", value: "Enabled")
                LabeledContent("Push Notifications", value: "Active")
            }
        }
        .navigationTitle("Background Tasks")
    }

    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .running: return .blue
        case .waiting: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

enum TaskStatus: String {
    case running, waiting, completed, failed
}

struct AppTask: Identifiable {
    let id = UUID()
    let name: String
    let status: TaskStatus
    let progress: Double
}
