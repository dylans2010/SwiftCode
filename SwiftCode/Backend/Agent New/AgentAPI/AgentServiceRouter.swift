import Foundation

@MainActor
final class AgentServiceRouter {
    static let shared = AgentServiceRouter()
    private init() {}

    func route(_ request: PluginAgentRequest) async throws -> PluginAgentResponse {
        // Route to PluginAgentBridge which then communicates with Agent runtime
        return try await PluginAgentBridge.shared.executeTask(request)
    }
}
