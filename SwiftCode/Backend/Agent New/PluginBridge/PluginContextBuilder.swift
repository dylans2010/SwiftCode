import Foundation

struct PluginSecureContext {
    let projectRoot: URL
    let allowedPaths: [URL]
    let pluginMetadata: [String: Any]
}

final class PluginContextBuilder {
    static func build(for pluginId: String, projectPath: String) -> PluginSecureContext {
        let projectURL = URL(fileURLWithPath: projectPath)
        // In a real app, this would involve complex logic to determine allowed paths
        return PluginSecureContext(
            projectRoot: projectURL,
            allowedPaths: [projectURL],
            pluginMetadata: ["pluginId": pluginId]
        )
    }
}
