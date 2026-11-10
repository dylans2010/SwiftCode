import Foundation

/// Engine/backend preferences: Ghidra installation override, disassembler
/// preference and per-request timeouts. Persisted to UserDefaults.
public struct EngineConfiguration: Codable, Sendable {
    /// Override path to a Ghidra installation root. nil = auto-detect.
    public var ghidraHomePath: String?
    /// Preferred disassembler backend id; nil = automatic resolution.
    public var preferredDisassemblerID: String?
    /// Preferred decompiler backend id; nil = automatic resolution.
    public var preferredDecompilerID: String?
    /// Per-request engine timeout, seconds. Clamped to
    /// `AnalysisSandbox.maxEngineRuntimeSeconds` when applied.
    public var engineTimeoutSeconds: Int = 600
    /// Working directory override for engine temp files; nil =
    /// `TemporaryFilePolicy` default.
    public var engineTempDirectory: String?
    /// Whether the Ghidra backend is enabled at all.
    public var ghidraEnabled: Bool = true
    /// Extra arguments passed to the Ghidra headless analyzer.
    public var ghidraExtraArguments: [String] = []

    public init() {}

    /// Effective timeout, bounded by the sandbox maximum.
    public var effectiveTimeoutSeconds: Int {
        min(max(engineTimeoutSeconds, 1), AnalysisSandbox.maxEngineRuntimeSeconds)
    }

    // MARK: - Persistence (UserDefaults suite "com.swiftcode.decompiler")

    private static let storageKey = "EngineConfiguration.v1"

    public static var shared: EngineConfiguration {
        get { DecompilerDefaults.load(EngineConfiguration.self,
                                      key: storageKey, fallback: EngineConfiguration()) }
        set { DecompilerDefaults.save(newValue, key: storageKey) }
    }

    public static func load() -> EngineConfiguration { shared }

    public func save() {
        EngineConfiguration.shared = self
    }
}
