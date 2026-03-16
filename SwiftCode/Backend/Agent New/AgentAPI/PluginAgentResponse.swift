import Foundation

/// Encapsulates the response from the Agent runtime back to a plugin.
struct PluginAgentResponse: Codable {
    let success: Bool
    let output: String
    let modifiedFiles: [String]
    let logs: [String]
}
