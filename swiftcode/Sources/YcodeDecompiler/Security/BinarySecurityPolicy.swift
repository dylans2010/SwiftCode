import Foundation

/// Security policy for untrusted binaries: import validation and resource limits.
public enum AnalysisSecurityPolicy {
    /// Maximum binary size we will ingest (4 GiB).
    public static let maxBinarySize: Int64 = 4 * 1024 * 1024 * 1024
    /// Maximum bytes returned by a single provider read.
    public static let maxReadLength: UInt64 = 64 * 1024 * 1024
    /// Maximum strings extracted per binary.
    public static let maxStrings = 2_000_000
    /// Maximum functions kept in memory.
    public static let maxFunctions = 5_000_000

    /// Validate that a file is importable: exists, is a file, readable, size-bounded.
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
        // Reject obviously dangerous locations? We never execute binaries —
        // analysis is static only. Path traversal is prevented by using the
        // URL directly rather than interpolated paths.
    }

    /// Wrap a byte provider with bounds checking.
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
