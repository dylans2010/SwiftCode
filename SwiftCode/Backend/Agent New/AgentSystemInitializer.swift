import Foundation

@MainActor
final class AgentSystemInitializer {
    static let shared = AgentSystemInitializer()
    private init() {}

    func initialize() {
        // Load and register all tools from different sources
        AgentToolsManager.shared.loadAndRegisterTools()

        print("[AgentSystem] Agent runtime initialized with tools from Core, Skills, and Connections.")
    }
}
