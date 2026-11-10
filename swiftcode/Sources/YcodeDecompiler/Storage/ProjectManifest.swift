import Foundation

/// Manifest stored as Project.json inside a `.scdecomp` bundle.
public struct ProjectManifest: Codable, Sendable {
    public var projectUUID: String
    public var name: String
    public var schemaVersion: Int
    public var createdAt: Date
    public var modifiedAt: Date
    /// Identity of each binary in the project (content-hash keyed).
    public var binaries: [BinaryIdentity]
    /// Selected slice index per binary stable id.
    public var selectedSlices: [String: Int]
    /// Active binary stable id.
    public var activeBinaryID: String?
    public var analysisConfiguration: AnalysisConfiguration
    public var engineVersions: [String: String]
    public var selectedMode: String
    public var workspacePreferences: WorkspacePreferences

    public struct WorkspacePreferences: Codable, Sendable {
        public var friendlySidebarSelection: String = "overview"
        public var masterLayout: String = "default"
        public var showInspector: Bool = true
        public var showConsole: Bool = false
        public var assistantPanelVisible: Bool = true

        public init() {}
    }

    public init(projectUUID: String = UUID().uuidString, name: String,
                binaries: [BinaryIdentity] = [], selectedSlices: [String: Int] = [:],
                activeBinaryID: String? = nil,
                analysisConfiguration: AnalysisConfiguration = AnalysisConfiguration(),
                engineVersions: [String: String] = [:],
                selectedMode: String = "friendly",
                workspacePreferences: WorkspacePreferences = WorkspacePreferences()) {
        self.projectUUID = projectUUID
        self.name = name
        self.schemaVersion = DecompilerCapabilities.projectSchemaVersion
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.binaries = binaries
        self.selectedSlices = selectedSlices
        self.activeBinaryID = activeBinaryID
        self.analysisConfiguration = analysisConfiguration
        self.engineVersions = engineVersions
        self.selectedMode = selectedMode
        self.workspacePreferences = workspacePreferences
    }
}

/// A `.scdecomp` project: a bundle directory with manifest + analysis store.
public struct DecompilerProject: Sendable {
    /// The bundle directory URL (path has `.scdecomp` extension).
    public var bundleURL: URL
    public var manifest: ProjectManifest

    public init(bundleURL: URL, manifest: ProjectManifest) {
        self.bundleURL = bundleURL
        self.manifest = manifest
    }

    public var manifestURL: URL { bundleURL.appendingPathComponent("Project.json") }
    public var databaseURL: URL { bundleURL.appendingPathComponent("Analysis.sqlite") }
    public var jsonStoreURL: URL { bundleURL.appendingPathComponent("Analysis.json") }
    public var binariesDir: URL { bundleURL.appendingPathComponent("Binaries", isDirectory: true) }
    public var cacheDir: URL { bundleURL.appendingPathComponent("Cache", isDirectory: true) }
    public var exportsDir: URL { bundleURL.appendingPathComponent("Exports", isDirectory: true) }

    /// The binary file inside the bundle, if we copied it in.
    public var bundledBinaryURL: URL? {
        guard let id = manifest.activeBinaryID else { return nil }
        let name = id + ".bin"
        let url = binariesDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Best available binary URL: bundled copy, else original location.
    public var binaryURL: URL? {
        if let bundled = bundledBinaryURL { return bundled }
        guard let identity = manifest.binaries.first(where: { $0.stableID == manifest.activeBinaryID }) else { return nil }
        let url = URL(fileURLWithPath: identity.originalLocation)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public var selectedSliceIndex: Int {
        manifest.selectedSlices[manifest.activeBinaryID ?? ""] ?? 0
    }
}
