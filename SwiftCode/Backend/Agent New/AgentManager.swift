import Foundation

@MainActor
final class AgentManager {
    static let shared = AgentManager()
    private init() {}

    func processTask(_ request: PluginAgentRequest) async throws -> PluginAgentResponse {
        // Build the task item for tracking
        let taskItem = AgentTaskManager.shared.createTask(
            title: "Plugin Task: \(request.task)",
            detail: "Plugin: \(request.pluginIdentifier)",
            priority: .normal,
            projectName: request.projectPath
        )

        AgentTaskManager.shared.startTask(taskItem)

        let loop = AgentLoop(request: request)
        let (output, logs) = try await loop.run()

        AgentTaskManager.shared.completeTask(taskItem, result: output)

        return PluginAgentResponse(
            success: true,
            output: output,
            modifiedFiles: [], // In a real system, we'd track this
            logs: logs
        )
    }
}
