import Foundation



enum DecompilerDefaults {
    static let suiteName = "com.swiftcode.decompiler"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    
    static func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder.decompiler.decode(T.self, from: data)) ?? fallback
    }

    
    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder.decompiler.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}



public struct DecompilerConfiguration: Codable, Sendable {
    
    public var autoAnalyze: Bool = true
    public var maxBulkDecompileFunctions: Int = 0
    public var extractStrings: Bool = true
    public var buildReferences: Bool = true
    public var preferredDecompilerID: String?
    public var preferredDisassemblerID: String?
    public var engineTimeoutSeconds: Int = 600
    public var engineTempDirectory: String?
    
    public var resourceLimits: ResourceLimits = .default

    
    
    public var defaultMode: DecompilerSession.Mode = .friendly
    
    public var assistantPanelVisible: Bool = true

    public init() {}

    
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

    

    private static let storageKey = "DecompilerConfiguration.v1"

    
    public static var shared: DecompilerConfiguration {
        get { DecompilerDefaults.load(DecompilerConfiguration.self,
                                      key: storageKey, fallback: DecompilerConfiguration()) }
        set { DecompilerDefaults.save(newValue, key: storageKey) }
    }

    
    public static func load() -> DecompilerConfiguration { shared }

    
    public func save() {
        DecompilerConfiguration.shared = self
    }
}
