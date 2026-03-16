import Foundation

@MainActor
final class AgentToolsManager {
    static let shared = AgentToolsManager()
    private init() {}

    func loadAndRegisterTools() {
        // 1. Register Core Tools
        registerCoreTools()

        // 2. Load and Register Skills
        AgentSkillsManager.shared.loadSkills()

        // 3. Load and Register Connections
        AgentConnectionsManager.shared.loadConnections()
    }

    private func registerCoreTools() {
        for tool in AgentTool.builtIns {
            ToolRegistry.shared.register(tool, source: .core) { params in
                // Delegate to existing AgentToolService.executeCore to avoid recursion
                let result = await AgentToolService.shared.executeCore(
                    toolName: tool.id,
                    parameters: params,
                    projectManager: ProjectManager.shared
                )
                if result.isError {
                    throw NSError(domain: "AgentToolsManager", code: 3, userInfo: [NSLocalizedDescriptionKey: result.result])
                }
                return result.result
            }
        }
    }

    func registerPluginTools(tools: [AgentTool], pluginId: String) {
        for tool in tools {
            ToolRegistry.shared.register(tool, source: .plugin) { params in
                return "Plugin tool \(tool.id) from \(pluginId) executed."
            }
        }
    }
}
