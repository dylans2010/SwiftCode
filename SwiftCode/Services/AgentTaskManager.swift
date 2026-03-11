import Foundation
import Combine

// MARK: - Agent Task Item

struct AgentTaskItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var detail: String = ""
    var priority: Priority = .normal
    var status: Status = .pending
    var projectName: String = ""
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?
    var result: String?
    var toolsUsed: [String] = []

    enum Priority: Int, Codable, CaseIterable {
        case low = 0, normal = 1, high = 2, critical = 3
        var label: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }

    enum Status: String, Codable {
        case pending, running, completed, failed, cancelled
        var icon: String {
            switch self {
            case .pending:   return "circle"
            case .running:   return "arrow.clockwise.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .failed:    return "xmark.circle.fill"
            case .cancelled: return "minus.circle.fill"
            }
        }
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }
}

// MARK: - Agent Task Manager

@MainActor
final class AgentTaskManager: ObservableObject {
    static let shared = AgentTaskManager()

    @Published var tasks: [AgentTaskItem] = []
    @Published var activeTasks: [AgentTaskItem] = []

    private static let storageKey = "com.swiftcode.agentTasks"

    private init() { load() }

    // MARK: - Create

    @discardableResult
    func createTask(
        title: String,
        detail: String = "",
        priority: AgentTaskItem.Priority = .normal,
        projectName: String = ""
    ) -> AgentTaskItem {
        let task = AgentTaskItem(
            title: title,
            detail: detail,
            priority: priority,
            projectName: projectName
        )
        tasks.insert(task, at: 0)
        save()
        return task
    }

    // MARK: - Status Updates

    func startTask(_ task: AgentTaskItem) {
        update(task.id) {
            $0.status = .running
            $0.startedAt = Date()
        }
    }

    func completeTask(_ task: AgentTaskItem, result: String? = nil) {
        update(task.id) {
            $0.status = .completed
            $0.completedAt = Date()
            $0.result = result
        }
    }

    func failTask(_ task: AgentTaskItem, error: String? = nil) {
        update(task.id) {
            $0.status = .failed
            $0.completedAt = Date()
            $0.result = error
        }
    }

    func cancelTask(_ task: AgentTaskItem) {
        update(task.id) {
            $0.status = .cancelled
            $0.completedAt = Date()
        }
    }

    func addToolUsed(_ toolName: String, to taskId: UUID) {
        update(taskId) {
            if !$0.toolsUsed.contains(toolName) {
                $0.toolsUsed.append(toolName)
            }
        }
    }

    // MARK: - Queries

    func tasks(forProject projectName: String) -> [AgentTaskItem] {
        tasks.filter { $0.projectName == projectName }
    }

    func tasksWithStatus(_ status: AgentTaskItem.Status) -> [AgentTaskItem] {
        tasks.filter { $0.status == status }
    }

    // MARK: - Delete

    func deleteTask(_ task: AgentTaskItem) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func clearCompleted() {
        tasks.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
        save()
    }

    // MARK: - Helpers

    private func update(_ id: UUID, transform: (inout AgentTaskItem) -> Void) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        transform(&tasks[idx])
        save()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([AgentTaskItem].self, from: data) else { return }
        tasks = decoded
    }
}
