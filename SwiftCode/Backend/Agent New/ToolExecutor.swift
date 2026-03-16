import Foundation

@MainActor
final class ToolExecutor {
    static let shared = ToolExecutor()
    private init() {}

    func execute(toolName: String, parameters: [String: Any]) async throws -> String {
        // Resolve tool from registry
        guard let registeredTool = ToolRegistry.shared.getTool(id: toolName) else {
            throw NSError(domain: "ToolExecutor", code: 404, userInfo: [NSLocalizedDescriptionKey: "Tool \(toolName) not found"])
        }

        let startTime = Date()

        do {
            let result = try await registeredTool.executionHandler(parameters)
            let duration = Date().timeIntervalSince(startTime)

            // Log execution
            AgentLogger.shared.logToolCall(
                name: toolName,
                source: registeredTool.source,
                arguments: parameters,
                duration: duration
            )

            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            AgentLogger.shared.logToolCall(
                name: toolName,
                source: registeredTool.source,
                arguments: parameters,
                duration: duration,
                error: error.localizedDescription
            )
            throw error
        }
    }
}
