import Foundation






public enum TemporaryFilePolicy {
    
    public static var baseDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SwiftCodeDecompiler", isDirectory: true)
    }

    
    @discardableResult
    public static func ensureBaseDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: baseDirectory,
                                                withIntermediateDirectories: true)
        return baseDirectory
    }

    
    
    
    public static func makeTempFileURL(prefix: String = "tmp") -> URL {
        let safePrefix = prefix.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : "-"
        }
        let name = "\(String(safePrefix))-\(UUID().uuidString)"
        return baseDirectory.appendingPathComponent(name)
    }

    
    
    public static func makeTempDirectory(prefix: String = "work") throws -> URL {
        let url = baseDirectory.appendingPathComponent(
            "\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    
    
    
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

    
    
    @discardableResult
    public static func removeAll() -> Bool {
        (try? FileManager.default.removeItem(at: baseDirectory)) != nil
    }
}
