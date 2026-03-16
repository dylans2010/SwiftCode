import Foundation

@MainActor
final class PluginAgentBridge {
    static let shared = PluginAgentBridge()
    private init() {}

    func executeTask(_ request: PluginAgentRequest) async throws -> PluginAgentResponse {
        // 1. Build context
        let context = PluginContextBuilder.build(for: request.pluginIdentifier, projectPath: request.projectPath)

        // 2. Enforce safety rules
        try validateRequest(request, context: context)

        // 3. Delegate to AgentManager
        return try await AgentManager.shared.processTask(request)
    }

    private func validateRequest(_ request: PluginAgentRequest, context: PluginSecureContext) throws {
        // Enforce: Plugins must only access files within their allowed paths
        for file in request.contextFiles {
            let fileURL = URL(fileURLWithPath: file)
            let isAllowed = context.allowedPaths.contains { allowedPath in
                fileURL.path.hasPrefix(allowedPath.path)
            }

            if !isAllowed {
                throw NSError(domain: "PluginAgentBridge", code: 4, userInfo: [NSLocalizedDescriptionKey: "Access to unauthorized path: \(file)"])
            }

            // Explicitly block system prefixes regardless of context
            if file.hasPrefix("/etc") || file.hasPrefix("/var") || file.hasPrefix("/System") {
                throw NSError(domain: "PluginAgentBridge", code: 4, userInfo: [NSLocalizedDescriptionKey: "Access to system files is prohibited"])
            }
        }
    }
}

protocol PluginAgentToolProvider {
    func registerTools()
}
