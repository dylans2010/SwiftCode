import Foundation




public struct ResourceLimits: Codable, Sendable, Hashable {
    
    public var maxFunctionsPerBulkOperation: Int
    
    public var maxPseudocodeBytesPerFunction: Int
    
    public var maxEngineRuntimeSeconds: Int

    public init(maxFunctionsPerBulkOperation: Int = 100_000,
                maxPseudocodeBytesPerFunction: Int = 8 * 1024 * 1024,
                maxEngineRuntimeSeconds: Int = 600) {
        self.maxFunctionsPerBulkOperation = maxFunctionsPerBulkOperation
        self.maxPseudocodeBytesPerFunction = maxPseudocodeBytesPerFunction
        self.maxEngineRuntimeSeconds = maxEngineRuntimeSeconds
    }

    
    public static let `default` = ResourceLimits()

    
    public var isSane: Bool {
        maxFunctionsPerBulkOperation > 0
            && maxPseudocodeBytesPerFunction > 0
            && maxEngineRuntimeSeconds > 0
    }
}
