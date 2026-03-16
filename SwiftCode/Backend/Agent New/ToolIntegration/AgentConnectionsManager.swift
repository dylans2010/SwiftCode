import Foundation

@MainActor
final class AgentConnectionsManager {
    static let shared = AgentConnectionsManager()
    private init() {}

    func loadConnections() {
        let connections = CustomToolRegistry.shared.connections
        for connection in connections {
            let tool = connection.toAgentTool()
            ToolRegistry.shared.register(tool, source: .connection) { params in
                return try await ToolConnectionExecutor.shared.execute(connection, parameters: params)
            }
        }
    }
}
