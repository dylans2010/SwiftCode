import Foundation

/**
 VERIFICATION SUITE: Agent New System (Updated)

 This script defines the expected behavior and verification steps for the
 new Agent Serverless API and Tool Integration Layer.
 */

@MainActor
class AgentSystemVerification {

    static func runDiagnostics() async {
        print("--- Starting Agent System Diagnostics ---")

        // 1. Verify Initialization
        AgentSystemInitializer.shared.initialize()
        let registry = ToolRegistry.shared
        let tools = registry.registeredTools
        print("Checking Tool Registry... Found \(tools.count) tools.")

        // 2. Verify Tool Lookup Priority (Core > Skill > Connection > Plugin)
        // We'll mock register tools for each source with the same name to test priority
        let toolName = "test_priority_tool"

        registry.register(AgentTool(id: toolName, displayName: "Core", description: "", parameters: [], category: .utilities), source: .core) { _ in "Core" }
        registry.register(AgentTool(id: toolName, displayName: "Skill", description: "", parameters: [], category: .utilities), source: .skill) { _ in "Skill" }
        registry.register(AgentTool(id: toolName, displayName: "Connection", description: "", parameters: [], category: .utilities), source: .connection) { _ in "Connection" }
        registry.register(AgentTool(id: toolName, displayName: "Plugin", description: "", parameters: [], category: .utilities), source: .plugin) { _ in "Plugin" }

        if let resolved = registry.getTool(id: toolName) {
            print("Priority Check: Expected 'Core', got '\(resolved.source.rawValue)'")
            if resolved.source == .core {
                print("✓ Tool priority enforcement successful.")
            } else {
                print("✗ Tool priority enforcement FAILED.")
            }
        }

        // 3. Verify Serverless API & Agent Manager
        let request = PluginAgentRequest(
            task: "Verify system integration",
            projectPath: "/tmp/test_project",
            pluginIdentifier: "com.test.verifier",
            contextFiles: ["/tmp/test_project/main.swift"], // authorized
            allowedTools: ["read_file"]
        )

        do {
            let response = try await SwiftCodeUseAgentService.shared.executeTask(task: request.task, request: request)
            if response.success {
                print("✓ Serverless API: Task execution successful via AgentManager.")
                print("Agent Output: \(response.output)")
            } else {
                print("✗ Serverless API: Task execution reported failure.")
            }
        } catch {
            print("✗ Serverless API: Task execution threw error: \(error.localizedDescription)")
        }

        // 4. Verify Safety - Unauthorized path
        let badRequest = PluginAgentRequest(
            task: "Steal secrets",
            projectPath: "/tmp/test_project",
            pluginIdentifier: "com.test.malicious",
            contextFiles: ["/etc/passwd"],
            allowedTools: []
        )

        do {
            _ = try await SwiftCodeUseAgentService.shared.executeTask(task: badRequest.task, request: badRequest)
            print("✗ Safety Check: FAILED (Unauthorized path allowed)")
        } catch {
            print("✓ Safety Check: Blocked unauthorized path correctly: \(error.localizedDescription)")
        }

        // 5. Verify Logger
        let toolLogs = AgentLogger.shared.toolLogs
        print("Tool Logs: \(toolLogs.count) entries found.")

        print("--- Diagnostics Complete ---")
    }
}
