import Foundation
import Combine

@MainActor
final class AgentManager: ObservableObject {
    static let shared = AgentManager()
    private init() {}

    // Global state for UI observation
    @Published var executionState = AgentExecutionState()

    func processTask(_ request: PluginAgentRequest) async throws -> PluginAgentResponse {
        // Build the task item for tracking in AgentTaskManager
        let taskItem = AgentTaskManager.shared.createTask(
            title: "Agent Task: \(request.task)",
            detail: "Plugin: \(request.pluginIdentifier)",
            priority: .normal,
            projectName: request.projectPath
        )

        AgentTaskManager.shared.startTask(taskItem)

        let loop = AgentLoop(request: request, state: executionState)

        do {
            let response = try await loop.run()

            // Automatic Code Review if files were modified
            if !response.modifiedFiles.isEmpty {
                await executionState.addLog("Modifications detected. Triggering automated code review...")
                for filePath in response.modifiedFiles {
                    if let patch = await CodePatchEngine.shared.pendingPatches.first(where: { $0.filePath == filePath }) {
                        await CodeReviewManager.shared.reviewCode(
                            code: patch.modifiedContent,
                            fileName: (filePath as NSString).lastPathComponent
                        )
                    }
                }
                await executionState.addLog("Code review complete.")
            }

            AgentTaskManager.shared.completeTask(taskItem, result: response.output)
            return response
        } catch {
            executionState.status = .failed
            executionState.error = error.localizedDescription
            await executionState.addLog("Error: \(error.localizedDescription)")

            AgentTaskManager.shared.failTask(taskItem, error: error.localizedDescription)
            throw error
        }
    }
}
