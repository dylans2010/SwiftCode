import Foundation

@MainActor
final class AgentServiceRouter {
    static let shared = AgentServiceRouter()
    private init() {}

    func route(_ request: PluginAgentRequest) async throws -> PluginAgentResponse {
        if CodexModelRouter().useCodex() {
            let output = try await CodexManager.shared.sendPrompt(buildPrompt(from: request))
            return PluginAgentResponse(success: true, output: output, modifiedFiles: [], logs: ["Routed through Codex"])
        }
        return try await PluginAgentBridge.shared.executeTask(request)
    }

    private func buildPrompt(from request: PluginAgentRequest) -> String {
        var sections: [String] = [request.task]
        if !request.projectPath.isEmpty {
            sections.append("Project Path: \(request.projectPath)")
        }
        if !request.contextFiles.isEmpty {
            sections.append("Context Files: \(request.contextFiles.joined(separator: ", "))")
        }
        if !request.allowedTools.isEmpty {
            sections.append("Allowed Tools: \(request.allowedTools.joined(separator: ", "))")
        }
        sections.append("Plugin Identifier: \(request.pluginIdentifier)")
        return sections.joined(separator: "\n")
    }
}
