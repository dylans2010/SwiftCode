import Foundation

/// Policy for temporary files created by analysis engines (notably the
/// Ghidra headless bridge, which stages project files on disk).
///
/// All temp artifacts live under a single well-known directory inside
/// `NSTemporaryDirectory()` so cleanup is centralized and predictable.
public enum TemporaryFilePolicy {
    /// Root directory for all decompiler temp files.
    public static var baseDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SwiftCodeDecompiler", isDirectory: true)
    }

    /// Ensure the base directory exists and return it.
    @discardableResult
    public static func ensureBaseDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: baseDirectory,
                                                withIntermediateDirectories: true)
        return baseDirectory
    }

    /// Return a fresh, unique file URL inside the temp directory.
    /// The file itself is NOT created — callers create it on demand.
    /// `prefix` should describe the artifact (e.g. "ghidra-project").
    public static func makeTempFileURL(prefix: String = "tmp") -> URL {
        let safePrefix = prefix.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : "-"
        }
        let name = "\(String(safePrefix))-\(UUID().uuidString)"
        return baseDirectory.appendingPathComponent(name)
    }

    /// Create and return a unique temporary *directory* for engine
    /// working files (e.g. a Ghidra project dir).
    public static func makeTempDirectory(prefix: String = "work") throws -> URL {
        let url = baseDirectory.appendingPathComponent(
            "\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Delete temp entries older than `interval` seconds. Returns the
    /// number of items removed. Entries whose age cannot be determined
    /// are kept (fail-safe: never delete what we cannot age).
    @discardableResult
    public static func cleanupOlderThan(_ interval: TimeInterval) -> Int {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]) else { return 0 }
        let cutoff = Date().addingTimeInterval(-interval)
        var removed = 0
        for url in items {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey,
                                                           .creationDateKey])
            let modified = values?.contentModificationDate ?? values?.creationDate
            guard let modified, modified < cutoff else { continue }
            if (try? fm.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }

    /// Remove the entire temp directory tree. Used on app shutdown or
    /// explicit cache resets.
    @discardableResult
    public static func removeAll() -> Bool {
        (try? FileManager.default.removeItem(at: baseDirectory)) != nil
    }
}
