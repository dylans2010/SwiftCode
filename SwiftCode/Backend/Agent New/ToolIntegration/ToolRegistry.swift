import Foundation

enum ToolSource: String, Codable {
    case core = "Core"
    case skill = "Skill"
    case connection = "Connection"
    case plugin = "Plugin"
}

struct RegisteredTool {
    let tool: AgentTool
    let source: ToolSource
    let executionHandler: ([String: Any]) async throws -> String
}

@MainActor
final class ToolRegistry {
    static let shared = ToolRegistry()
    private init() {}

    private var tools: [ToolSource: [String: RegisteredTool]] = [
        .core: [:],
        .skill: [:],
        .connection: [:],
        .plugin: [:]
    ]

    func register(_ tool: AgentTool, source: ToolSource, handler: @escaping ([String: Any]) async throws -> String) {
        tools[source]?[tool.id] = RegisteredTool(tool: tool, source: source, executionHandler: handler)
    }

    func getTool(id: String) -> RegisteredTool? {
        // Enforce priority: Core > Skill > Connection > Plugin
        let priorityOrder: [ToolSource] = [.core, .skill, .connection, .plugin]
        for source in priorityOrder {
            if let tool = tools[source]?[id] {
                return tool
            }
        }
        return nil
    }

    var allTools: [AgentTool] {
        return tools.values.flatMap { $0.values.map { $0.tool } }
    }

    var registeredTools: [RegisteredTool] {
        return tools.values.flatMap { Array($0.values) }
    }
}
