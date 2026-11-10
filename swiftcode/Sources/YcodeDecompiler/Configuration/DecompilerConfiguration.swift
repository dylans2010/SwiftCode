import Foundation

/// Shared UserDefaults access for the decompiler subsystem.
/// Internal — configuration types expose typed accessors publicly.
enum DecompilerDefaults {
    static let suiteName = "com.swiftcode.decompiler"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// Load a Codable value stored as JSON under `key`.
    static func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder.decompiler.decode(T.self, from: data)) ?? fallback
    }

    /// Persist a Codable value as JSON under `key`.
    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder.decompiler.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Top-level decompiler configuration: mirrors `AnalysisConfiguration`
/// and adds UI-level preferences. Persisted to UserDefaults.
public struct DecompilerConfiguration: Codable, Sendable {
    // Analysis pipeline (mirrors AnalysisConfiguration fields).
    public var autoAnalyze: Bool = true
    public var maxBulkDecompileFunctions: Int = 0
    public var extractStrings: Bool = true
    public var buildReferences: Bool = true
    public var preferredDecompilerID: String?
    public var preferredDisassemblerID: String?
    public var engineTimeoutSeconds: Int = 600
    public var engineTempDirectory: String?
    /// Sandbox limits applied to engine requests and results.
    public var resourceLimits: ResourceLimits = .default

    // UI preferences.
    /// Default workspace mode for new sessions.
    public var defaultMode: DecompilerSession.Mode = .friendly
    /// Whether the Decompile Assist panel is visible.
    public var assistantPanelVisible: Bool = true

    public init() {}

    /// Bridge into the `AnalysisConfiguration` the pipeline consumes.
    public var analysisConfiguration: AnalysisConfiguration {
        var config = AnalysisConfiguration()
        config.autoAnalyze = autoAnalyze
        config.maxBulkDecompileFunctions = maxBulkDecompileFunctions
        config.extractStrings = extractStrings
        config.buildReferences = buildReferences
        config.preferredDecompilerID = preferredDecompilerID
        config.preferredDisassemblerID = preferredDisassemblerID
        config.engineTimeoutSeconds = engineTimeoutSeconds
        config.engineTempDirectory = engineTempDirectory
        return config
    }

    // MARK: - Persistence (UserDefaults suite "com.swiftcode.decompiler")

    private static let storageKey = "DecompilerConfiguration.v1"

    /// The shared configuration, loaded lazily from UserDefaults.
    public static var shared: DecompilerConfiguration {
        get { DecompilerDefaults.load(DecompilerConfiguration.self,
                                      key: storageKey, fallback: DecompilerConfiguration()) }
        set { DecompilerDefaults.save(newValue, key: storageKey) }
    }

    /// Explicit load (same as reading `shared`).
    public static func load() -> DecompilerConfiguration { shared }

    /// Persist the current value.
    public func save() {
        DecompilerConfiguration.shared = self
    }
}
