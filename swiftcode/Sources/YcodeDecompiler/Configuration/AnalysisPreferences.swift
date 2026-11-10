import Foundation

/// User-tunable analysis preferences: bulk operation limits, optional
/// analysis passes and display toggles. Persisted to UserDefaults.
public struct AnalysisPreferences: Codable, Sendable {
    /// Maximum functions decompiled in one bulk operation
    /// (0 = unlimited, still bounded by `AnalysisSandbox`).
    public var bulkDecompileLimit: Int = 0
    /// Extract printable strings during analysis.
    public var extractStrings: Bool = true
    /// Build cross-references during analysis.
    public var buildReferences: Bool = true
    /// Run analysis automatically after importing a binary.
    public var autoAnalyze: Bool = true
    /// Show the strings view in the navigator.
    public var showStringsView: Bool = true
    /// Show the types view in the navigator.
    public var showTypesView: Bool = true
    /// Include raw backend output in exported pseudocode.
    public var exportRawBackendOutput: Bool = false
    /// Group functions by section in list views.
    public var groupFunctionsBySection: Bool = false

    public init() {}

    /// Merge these preferences into an `AnalysisConfiguration`.
    public func apply(to config: inout AnalysisConfiguration) {
        config.maxBulkDecompileFunctions = bulkDecompileLimit
        config.extractStrings = extractStrings
        config.buildReferences = buildReferences
        config.autoAnalyze = autoAnalyze
    }

    // MARK: - Persistence (UserDefaults suite "com.swiftcode.decompiler")

    private static let storageKey = "AnalysisPreferences.v1"

    public static var shared: AnalysisPreferences {
        get { DecompilerDefaults.load(AnalysisPreferences.self,
                                      key: storageKey, fallback: AnalysisPreferences()) }
        set { DecompilerDefaults.save(newValue, key: storageKey) }
    }

    public static func load() -> AnalysisPreferences { shared }

    public func save() {
        AnalysisPreferences.shared = self
    }
}
