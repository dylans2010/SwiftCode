import Foundation

@MainActor
final class ToolExecutor {
    static let shared = ToolExecutor()
    private init() {}

    func execute(toolName: String, parameters: [String: Any]) async throws -> String {
        guard let registeredTool = ToolRegistry.shared.getTool(id: toolName) else {
            throw NSError(domain: "ToolExecutor", code: 404, userInfo: [NSLocalizedDescriptionKey: "Tool \(toolName) not found"])
        }

        let scope = permissionScope(for: toolName)
        let targetPath = parameters["path"] as? String
        _ = try AgentPermissionAuthority.shared.authorize(scope: scope, path: targetPath, actor: "ToolExecutor")

        let startTime = Date()
        do {
            let result = try await registeredTool.executionHandler(parameters)
            let duration = Date().timeIntervalSince(startTime)
            AgentLogger.shared.logToolCall(name: toolName, source: registeredTool.source, arguments: parameters, duration: duration)
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            AgentLogger.shared.logToolCall(name: toolName, source: registeredTool.source, arguments: parameters, duration: duration, error: error.localizedDescription)
            throw error
        }
    }

    private func permissionScope(for toolName: String) -> TransferPermission.Scope {
        switch toolName {
        case "list_files", "read_file": return .viewFiles
        case "write_file": return .allowAgentFileModification
        case "create_file": return .createFiles
        case "delete_file": return .deleteFiles
        case "transfer_project": return .allowAgentToInitiateTransfers
        default: return .allowAgentAccess
        }
    }
}
