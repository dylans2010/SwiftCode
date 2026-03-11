import Foundation

// MARK: - Extension Manifest

/// Represents the metadata and configuration for a SwiftCode Extension.
struct ExtensionManifest: Identifiable, Codable, Equatable {
    var id: String                      // Unique identifier (folder name)
    var name: String
    var version: String
    var description: String
    var author: String
    var category: ExtensionCategory
    var capabilities: [ExtensionCapability]
    var entryPoint: String              // Relative path to the main Swift file
    var assetPaths: [String]            // Relative paths to asset files
    var isInstalled: Bool
    var isEnabled: Bool
    var isUserCreated: Bool

    enum ExtensionCategory: String, Codable, CaseIterable, Identifiable {
        case editor        = "Editor"
        case tools         = "Tools"
        case themes        = "Themes"
        case languages     = "Languages"
        case ai            = "AI"
        case build         = "Build"
        case testing       = "Testing"
        case other         = "Other"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .editor:    return "pencil.and.outline"
            case .tools:     return "wrench.and.screwdriver"
            case .themes:    return "paintpalette"
            case .languages: return "chevron.left.forwardslash.chevron.right"
            case .ai:        return "cpu"
            case .build:     return "hammer"
            case .testing:   return "checkmark.shield"
            case .other:     return "puzzlepiece.extension"
            }
        }
    }

    enum ExtensionCapability: String, Codable, CaseIterable {
        case codeCompletion   = "Code Completion"
        case syntaxHighlight  = "Syntax Highlight"
        case formatter        = "Formatter"
        case linter           = "Linter"
        case fileTemplate     = "File Template"
        case command          = "Command"
        case buildTool        = "Build Tool"
        case aiAssistant      = "AI Assistant"
        case themeProvider    = "Theme Provider"
        case languageSupport  = "Language Support"
    }
}

// MARK: - Extension Manager

/// Manages all Extensions in SwiftCode: scanning, installing, enabling, disabling,
/// creating, and deleting. Extensions are stored in the app's Documents/Extensions
/// folder and load dynamically into the IDE when installed.
@MainActor
final class ExtensionManager: ObservableObject {
    static let shared = ExtensionManager()

    @Published var extensions: [ExtensionManifest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Root directory for all user-created and installed extensions.
    var extensionsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Extensions")
    }

    private init() {
        ensureExtensionsDirectory()
        Task { await scanExtensions() }
    }

    // MARK: - Directory

    private func ensureExtensionsDirectory() {
        try? FileManager.default.createDirectory(
            at: extensionsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Scan

    /// Scans the Extensions directory for installed extension manifests.
    func scanExtensions() async {
        isLoading = true
        defer { isLoading = false }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: extensionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }

        var found: [ExtensionManifest] = []
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let manifestURL = url.appendingPathComponent("extension.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  var manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data) else { continue }
            manifest.isInstalled = true
            manifest.isEnabled = loadEnabledState(for: manifest.id)
            found.append(manifest)
        }

        extensions = found.sorted { $0.name < $1.name }
    }

    // MARK: - Enable / Disable

    func toggleExtension(_ ext: ExtensionManifest) {
        guard let idx = extensions.firstIndex(where: { $0.id == ext.id }) else { return }
        extensions[idx].isEnabled.toggle()
        saveEnabledState(for: extensions[idx].id, enabled: extensions[idx].isEnabled)
        // PLACEHOLDER: Notify the IDE to load or unload this extension's entry point.
        // IDEExtensionLoader.shared.reload(extensions[idx])
    }

    // MARK: - Install

    /// Installs an extension from a source directory.
    func installExtension(from sourceURL: URL) throws {
        let destURL = extensionsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        Task { await scanExtensions() }
    }

    // MARK: - Uninstall / Delete

    /// Safely removes an extension folder and removes it from the IDE.
    func uninstallExtension(_ ext: ExtensionManifest) throws {
        let extURL = extensionsDirectory.appendingPathComponent(ext.id)
        if FileManager.default.fileExists(atPath: extURL.path) {
            try FileManager.default.removeItem(at: extURL)
        }
        extensions.removeAll { $0.id == ext.id }
        // PLACEHOLDER: Notify the IDE to unload this extension.
        // IDEExtensionLoader.shared.unload(ext)
    }

    // MARK: - Create User Extension

    /// Creates a new user-created extension under the Extensions directory.
    /// Returns the folder URL of the created extension.
    @discardableResult
    func createExtension(manifest: ExtensionManifest, swiftFiles: [(name: String, content: String)], assetFiles: [(name: String, data: Data)]) throws -> URL {
        let folderURL = extensionsDirectory.appendingPathComponent(manifest.id)
        let fm = FileManager.default

        // Create the extension folder
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)

        // Save the manifest
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: folderURL.appendingPathComponent("extension.json"))

        // Save Swift source files
        for file in swiftFiles {
            let fileURL = folderURL.appendingPathComponent(file.name)
            try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Save asset files
        let assetsFolder = folderURL.appendingPathComponent("Assets")
        if !assetFiles.isEmpty {
            try fm.createDirectory(at: assetsFolder, withIntermediateDirectories: true)
            for asset in assetFiles {
                try asset.data.write(to: assetsFolder.appendingPathComponent(asset.name))
            }
        }

        Task { await scanExtensions() }
        return folderURL
    }

    // MARK: - Update Extension

    /// Updates an existing extension's manifest and optionally its files.
    func updateExtension(manifest: ExtensionManifest) throws {
        guard let idx = extensions.firstIndex(where: { $0.id == manifest.id }) else { return }
        extensions[idx] = manifest
        let folderURL = extensionsDirectory.appendingPathComponent(manifest.id)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: folderURL.appendingPathComponent("extension.json"))
    }

    // MARK: - Filter Helpers

    func extensions(with capability: ExtensionManifest.ExtensionCapability) -> [ExtensionManifest] {
        extensions.filter { $0.isEnabled && $0.capabilities.contains(capability) }
    }

    func extensions(inCategory category: ExtensionManifest.ExtensionCategory) -> [ExtensionManifest] {
        extensions.filter { $0.category == category }
    }

    // MARK: - Preferences Persistence

    private static let enabledKey = "com.swiftcode.extensions.enabled"

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
