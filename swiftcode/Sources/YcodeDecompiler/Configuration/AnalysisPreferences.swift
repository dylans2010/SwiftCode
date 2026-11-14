import Foundation



public struct AnalysisPreferences: Codable, Sendable {
    
    
    public var bulkDecompileLimit: Int = 0
    
    public var extractStrings: Bool = true
    
    public var buildReferences: Bool = true
    
    public var autoAnalyze: Bool = true
    
    public var showStringsView: Bool = true
    
    public var showTypesView: Bool = true
    
    public var exportRawBackendOutput: Bool = false
    
    public var groupFunctionsBySection: Bool = false

    public init() {}

    
    public func apply(to config: inout AnalysisConfiguration) {
        config.maxBulkDecompileFunctions = bulkDecompileLimit
        config.extractStrings = extractStrings
        config.buildReferences = buildReferences
        config.autoAnalyze = autoAnalyze
    }

    

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
