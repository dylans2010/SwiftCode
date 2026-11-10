import Foundation

/// Runtime guardrails for analysis operations. These bounds protect the
/// host from pathological binaries and runaway engine output. They
/// complement `AnalysisSecurityPolicy` (import-time file checks) by
/// covering per-operation result sizes.
public enum AnalysisSandbox {
    /// Maximum functions accepted by a single bulk decompilation request.
    public static let maxFunctionsPerBulkOperation = 100_000
    /// Maximum pseudocode bytes accepted for a single function result.
    public static let maxPseudocodeBytesPerFunction = 8 * 1024 * 1024 // 8 MiB
    /// Maximum engine runtime per request, in seconds (matches the
    /// `AnalysisConfiguration.engineTimeoutSeconds` default).
    public static let maxEngineRuntimeSeconds = 600

    /// The canonical limits as a value type (see `ResourceLimits`).
    public static var resourceLimits: ResourceLimits {
        ResourceLimits(maxFunctionsPerBulkOperation: maxFunctionsPerBulkOperation,
                       maxPseudocodeBytesPerFunction: maxPseudocodeBytesPerFunction,
                       maxEngineRuntimeSeconds: maxEngineRuntimeSeconds)
    }

    /// Enforce the per-function pseudocode size cap on a result payload.
    /// Throws `resourceLimitExceeded` when `data` exceeds
    /// `maxPseudocodeBytesPerFunction`.
    public static func validateResultSize(_ data: Data) throws {
        guard data.count <= maxPseudocodeBytesPerFunction else {
            throw DecompilerError.resourceLimitExceeded(
                "result of \(data.count) bytes exceeds per-function limit of \(maxPseudocodeBytesPerFunction) bytes")
        }
    }

    /// Enforce the pseudocode size cap on raw text.
    public static func validateResultSize(_ text: String) throws {
        try validateResultSize(Data(text.utf8))
    }

    /// Enforce the bulk-operation function-count cap.
    public static func validateBulkFunctionCount(_ count: Int) throws {
        guard count <= maxFunctionsPerBulkOperation else {
            throw DecompilerError.resourceLimitExceeded(
                "bulk request of \(count) functions exceeds limit of \(maxFunctionsPerBulkOperation)")
        }
    }

    /// Enforce the per-request engine runtime cap. Callers pass the
    /// configured timeout; values above the sandbox maximum are rejected
    /// rather than silently clamped, so misconfiguration is visible.
    public static func validateEngineTimeout(_ seconds: Int) throws {
        guard seconds > 0, seconds <= maxEngineRuntimeSeconds else {
            throw DecompilerError.invalidRequest(
                "engine timeout \(seconds)s outside allowed range 1...\(maxEngineRuntimeSeconds)")
        }
    }
}
