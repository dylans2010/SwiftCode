import Foundation



























public enum RepositoryFormat {
    public static let metadataDirectoryName = ".spaces"
    public static let ignoreFileName = ".spacesignore"
    public static let gitignoreFileName = ".gitignore"
    public static let lfsAttributesName = ".spaceslfs"
    public static let formatVersion = 1
    public static let indexVersion = 1
    public static let protocolVersion = 1

    public static func metadataURL(for worktree: URL) -> URL {
        worktree.appendingPathComponent(metadataDirectoryName)
    }

    public static func isMetadata(_ url: URL) -> Bool {
        url.lastPathComponent == metadataDirectoryName
    }

    
    
    public static func discover(from start: URL) -> URL? {
        var current = start.standardizedFileURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: current.path, isDirectory: &isDir), !isDir.boolValue {
            current = current.deletingLastPathComponent()
        }
        while true {
            let candidate = current.appendingPathComponent(metadataDirectoryName)
            var dir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &dir), dir.boolValue {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent == current { return nil }
            current = parent
        }
    }
}
