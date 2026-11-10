import Foundation

/// Codable snapshot of the sandbox limits. Used by
/// `DecompilerConfiguration` so limits can be persisted, inspected and
/// (where policy allows) tuned per installation.
public struct ResourceLimits: Codable, Sendable, Hashable {
    /// Maximum functions accepted by a single bulk decompilation request.
    public var maxFunctionsPerBulkOperation: Int
    /// Maximum pseudocode bytes accepted for a single function result.
    public var maxPseudocodeBytesPerFunction: Int
    /// Maximum engine runtime per request, in seconds.
    public var maxEngineRuntimeSeconds: Int

    public init(maxFunctionsPerBulkOperation: Int = 100_000,
                maxPseudocodeBytesPerFunction: Int = 8 * 1024 * 1024,
                maxEngineRuntimeSeconds: Int = 600) {
        self.maxFunctionsPerBulkOperation = maxFunctionsPerBulkOperation
        self.maxPseudocodeBytesPerFunction = maxPseudocodeBytesPerFunction
        self.maxEngineRuntimeSeconds = maxEngineRuntimeSeconds
    }

    /// The built-in defaults (identical to `AnalysisSandbox`).
    public static let `default` = ResourceLimits()

    /// Whether every limit is within sane bounds (positive, non-zero).
    public var isSane: Bool {
        maxFunctionsPerBulkOperation > 0
            && maxPseudocodeBytesPerFunction > 0
            && maxEngineRuntimeSeconds > 0
    }
}
