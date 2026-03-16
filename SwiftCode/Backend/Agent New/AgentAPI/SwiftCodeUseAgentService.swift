import Foundation

@MainActor
final class SwiftCodeUseAgentService {
    static let shared = SwiftCodeUseAgentService()
    private init() {}

    /// Public interface for plugins to execute agent tasks.
    func executeTask(task: String, request: PluginAgentRequest) async throws -> PluginAgentResponse {
        return try await AgentServiceRouter.shared.route(request)
    }
}
