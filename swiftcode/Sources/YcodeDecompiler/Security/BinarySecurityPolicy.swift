import Foundation


public enum AnalysisSecurityPolicy {
    
    public static let maxBinarySize: Int64 = 4 * 1024 * 1024 * 1024
    
    public static let maxReadLength: UInt64 = 64 * 1024 * 1024
    
    public static let maxStrings = 2_000_000
    
    public static let maxFunctions = 5_000_000

    
    public static func validateImport(url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isReadableKey])
        guard values.isRegularFile == true else {
            throw DecompilerError.invalidRequest("not a regular file: \(url.path)")
        }
        guard values.isReadable == true else {
            throw DecompilerError.permissionDenied("cannot read \(url.path)")
        }
        if let size = values.fileSize, size > maxBinarySize {
            throw DecompilerError.resourceLimitExceeded("binary exceeds \(maxBinarySize) bytes")
        }
        
        
        
    }

    
    public static func bounded(_ provider: @escaping @Sendable (UInt64, UInt64) throws -> Data)
        -> @Sendable (UInt64, UInt64) throws -> Data {
        { offset, length in
            guard length <= maxReadLength else {
                throw DecompilerError.resourceLimitExceeded("read of \(length) bytes exceeds limit")
            }
            return try provider(offset, length)
        }
    }
}
