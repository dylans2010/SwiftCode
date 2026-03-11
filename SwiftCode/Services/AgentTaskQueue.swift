import Foundation

// MARK: - Agent Task Queue
// Manages a serial queue of agent tasks with priority ordering.

@MainActor
final class AgentTaskQueue: ObservableObject {
    static let shared = AgentTaskQueue()

    @Published var queue: [AgentTaskItem] = []
    @Published var isProcessing = false
    @Published var currentTask: AgentTaskItem?

    private var processingTask: Task<Void, Never>?

    private init() {}

    // MARK: - Enqueue

    func enqueue(_ task: AgentTaskItem) {
        let insertionIndex = queue.firstIndex { $0.priority.rawValue < task.priority.rawValue } ?? queue.endIndex
        queue.insert(task, at: insertionIndex)
        startProcessingIfNeeded()
    }

    func enqueue(title: String, detail: String = "", priority: AgentTaskItem.Priority = .normal, projectName: String = "") {
        let task = AgentTaskManager.shared.createTask(
            title: title, detail: detail, priority: priority, projectName: projectName
        )
        enqueue(task)
    }

    // MARK: - Dequeue

    func dequeue() -> AgentTaskItem? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }

    // MARK: - Cancel

    func cancelAll() {
        for task in queue {
            AgentTaskManager.shared.cancelTask(task)
        }
        queue.removeAll()
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
        currentTask = nil
    }

    func cancel(_ task: AgentTaskItem) {
        queue.removeAll { $0.id == task.id }
        AgentTaskManager.shared.cancelTask(task)
        if currentTask?.id == task.id {
            processingTask?.cancel()
            currentTask = nil
            isProcessing = false
            startProcessingIfNeeded()
        }
    }

    // MARK: - Processing

    private func startProcessingIfNeeded() {
        guard !isProcessing, !queue.isEmpty else { return }
        process()
    }

    private func process() {
        guard let next = dequeue() else {
            isProcessing = false
            currentTask = nil
            return
        }

        isProcessing = true
        currentTask = next
        AgentTaskManager.shared.startTask(next)

        processingTask = Task {
            // Simulate processing delay; real agents inject their own logic via completion handlers
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            AgentTaskManager.shared.completeTask(next, result: "Queued task processed.")
            currentTask = nil
            process()
        }
    }

    // MARK: - Stats

    var pendingCount: Int { queue.filter { $0.status == .pending }.count }
    var totalCount: Int { queue.count }
}
