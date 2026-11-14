import Foundation





public enum AnalysisSandbox {
    
    public static let maxFunctionsPerBulkOperation = 100_000
    
    public static let maxPseudocodeBytesPerFunction = 8 * 1024 * 1024 
    
    
    public static let maxEngineRuntimeSeconds = 600

    
    public static var resourceLimits: ResourceLimits {
        ResourceLimits(maxFunctionsPerBulkOperation: maxFunctionsPerBulkOperation,
                       maxPseudocodeBytesPerFunction: maxPseudocodeBytesPerFunction,
                       maxEngineRuntimeSeconds: maxEngineRuntimeSeconds)
    }

    
    
    
    public static func validateResultSize(_ data: Data) throws {
        guard data.count <= maxPseudocodeBytesPerFunction else {
            throw DecompilerError.resourceLimitExceeded(
                "result of \(data.count) bytes exceeds per-function limit of \(maxPseudocodeBytesPerFunction) bytes")
        }
    }

    
    public static func validateResultSize(_ text: String) throws {
        try validateResultSize(Data(text.utf8))
    }

    
    public static func validateBulkFunctionCount(_ count: Int) throws {
        guard count <= maxFunctionsPerBulkOperation else {
            throw DecompilerError.resourceLimitExceeded(
                "bulk request of \(count) functions exceeds limit of \(maxFunctionsPerBulkOperation)")
        }
    }

    
    
    
    public static func validateEngineTimeout(_ seconds: Int) throws {
        guard seconds > 0, seconds <= maxEngineRuntimeSeconds else {
            throw DecompilerError.invalidRequest(
                "engine timeout \(seconds)s outside allowed range 1...\(maxEngineRuntimeSeconds)")
        }
    }
}
