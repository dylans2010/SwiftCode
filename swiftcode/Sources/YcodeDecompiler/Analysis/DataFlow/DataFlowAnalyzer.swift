import Foundation

/// Data-flow placeholders are intentionally minimal: real data-flow analysis
/// requires backend SSA/value analysis which Ghidra provides via p-code.
/// This file defines the seam so a future backend can feed results in.
public struct DataFlowResult: Sendable {
    /// Def-use chains per function address (backend-provided).
    public var defUseChains: [UInt64: [[String]]]
    public var provenance: AnalysisSource

    public init(defUseChains: [UInt64: [[String]]] = [:], provenance: AnalysisSource) {
        self.defUseChains = defUseChains
        self.provenance = provenance
    }
}

public enum DataFlowAnalyzer {
    /// No local data-flow engine is bundled; callers should use the
    /// decompiler backend's p-code/SSA output instead.
    public static func isBackendProvidedOnly() -> Bool { true }
}
