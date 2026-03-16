import Foundation

/// Encapsulates requests coming from plugins to the Agent system.
struct PluginAgentRequest: Codable {
    let task: String
    let projectPath: String
    let pluginIdentifier: String
    let contextFiles: [String]
    let allowedTools: [String]
}
