import Foundation



public struct EngineConfiguration: Codable, Sendable {
    
    public var ghidraHomePath: String?
    
    public var preferredDisassemblerID: String?
    
    public var preferredDecompilerID: String?
    
    
    public var engineTimeoutSeconds: Int = 600
    
    
    public var engineTempDirectory: String?
    
    public var ghidraEnabled: Bool = true
    
    public var ghidraExtraArguments: [String] = []

    public init() {}

    
    public var effectiveTimeoutSeconds: Int {
        min(max(engineTimeoutSeconds, 1), AnalysisSandbox.maxEngineRuntimeSeconds)
    }

    

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
