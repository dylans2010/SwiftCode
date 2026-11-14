import Foundation




public struct DataFlowResult: Sendable {
    
    public var defUseChains: [UInt64: [[String]]]
    public var provenance: AnalysisSource

    public init(defUseChains: [UInt64: [[String]]] = [:], provenance: AnalysisSource) {
        self.defUseChains = defUseChains
        self.provenance = provenance
    }
}

public enum DataFlowAnalyzer {
    
    
    public static func isBackendProvidedOnly() -> Bool { true }
}
