import Foundation
import Combine

enum AgentStepStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}

struct AgentPlanStep: Identifiable, Codable {
    let id: UUID
    let description: String
    var status: AgentStepStatus
    var toolCalls: [String]

    init(description: String) {
        self.id = UUID()
        self.description = description
        self.status = .pending
        self.toolCalls = []
    }
}

@MainActor
final class AgentExecutionState: ObservableObject {
    @Published var taskDescription: String = ""
    @Published var status: AgentTaskItem.Status = .pending
    @Published var plan: [AgentPlanStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var logs: [String] = []
    @Published var error: String?

    func reset(task: String) {
        taskDescription = task
        status = .pending
        plan = []
        currentStepIndex = 0
        logs = []
        error = nil
    }

    func addLog(_ message: String) {
        logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
}
