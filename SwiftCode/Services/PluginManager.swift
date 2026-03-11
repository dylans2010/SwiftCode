import Foundation

// MARK: - Plugin Manifest

struct PluginManifest: Identifiable, Codable {
    var id: String
    var name: String
    var version: String
    var description: String
    var author: String
    var entryPoint: String        // relative path to main Swift file in the plugin
    var capabilities: [Capability]
    var isEnabled: Bool = true

    enum Capability: String, Codable, CaseIterable {
        case codeCompletion   = "codeCompletion"
        case syntaxHighlight  = "syntaxHighlight"
        case buildTool        = "buildTool"
        case formatter        = "formatter"
        case linter           = "linter"
        case fileTemplate     = "fileTemplate"
        case command          = "command"
    }
}

// MARK: - Plugin Manager

@MainActor
final class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published var plugins: [PluginManifest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var pluginsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plugins")
    }

    private init() {
        ensurePluginsDirectory()
        Task { await scanPlugins() }
    }

    // MARK: - Directory

    private func ensurePluginsDirectory() {
        try? FileManager.default.createDirectory(
            at: pluginsDirectory, withIntermediateDirectories: true
        )
    }

    // MARK: - Scan

    func scanPlugins() async {
        isLoading = true
        defer { isLoading = false }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }

        var found: [PluginManifest] = []
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let manifestURL = url.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  var manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }

            // Preserve enabled/disabled state from stored preferences
            manifest.isEnabled = loadEnabledState(for: manifest.id)
            found.append(manifest)
        }

        plugins = found.sorted { $0.name < $1.name }
    }

    // MARK: - Enable / Disable

    func togglePlugin(_ plugin: PluginManifest) {
        guard let idx = plugins.firstIndex(where: { $0.id == plugin.id }) else { return }
        plugins[idx].isEnabled.toggle()
        saveEnabledState(for: plugins[idx].id, enabled: plugins[idx].isEnabled)
    }

    // MARK: - Install from Directory

    func installPlugin(from sourceURL: URL) throws {
        let destURL = pluginsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        Task { await scanPlugins() }
    }

    // MARK: - Uninstall

    func uninstallPlugin(_ plugin: PluginManifest) throws {
        let pluginURL = pluginsDirectory.appendingPathComponent(plugin.id)
        try FileManager.default.removeItem(at: pluginURL)
        plugins.removeAll { $0.id == plugin.id }
    }

    // MARK: - Capabilities

    func plugins(with capability: PluginManifest.Capability) -> [PluginManifest] {
        plugins.filter { $0.isEnabled && $0.capabilities.contains(capability) }
    }

    // MARK: - Create User Plugin

    func createPlugin(manifest: PluginManifest, mainCode: String) throws {
        let pluginURL = pluginsDirectory.appendingPathComponent(manifest.id)
        let fm = FileManager.default

        try fm.createDirectory(at: pluginURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: pluginURL.appendingPathComponent("plugin.json"))

        try mainCode.write(
            to: pluginURL.appendingPathComponent(manifest.entryPoint),
            atomically: true,
            encoding: .utf8
        )

        Task { await scanPlugins() }
    }

    // MARK: - OS Version Fallbacks

    func isPluginCompatible(_ manifest: PluginManifest) -> Bool {
        // In a real environment, plugins might require specific APIs
        // Check for minimum OS requirements if they were in the manifest

        if #available(iOS 17.0, *) {
            // iOS 17+ supports all current plugin capabilities
            return true
        } else if #available(iOS 16.0, *) {
            // iOS 16 fallback: Disable advanced AI capabilities if they rely on iOS 17+ ML APIs
            let isAIPlugin = manifest.capabilities.contains(.codeCompletion) || manifest.name.lowercased().contains("ai")
            return !isAIPlugin
        } else {
            // iOS 15 or older: Only allow basic formatting and syntax highlighting
            let basicCapabilities: Set<PluginManifest.Capability> = [.syntaxHighlight, .formatter]
            return manifest.capabilities.allSatisfy { basicCapabilities.contains($0) }
        }
    }

    // MARK: - Preferences Persistence

    private static let enabledKey = "com.swiftcode.plugins.enabled"

    private func saveEnabledState(for id: String, enabled: Bool) {
        var states = loadAllEnabledStates()
        states[id] = enabled
        UserDefaults.standard.set(states, forKey: Self.enabledKey)
    }

    private func loadEnabledState(for id: String) -> Bool {
        loadAllEnabledStates()[id] ?? true
    }

    private func loadAllEnabledStates() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: Self.enabledKey) as? [String: Bool] ?? [:]
    }
}
