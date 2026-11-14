import Foundation

/// On-disk Spaces repository layout. The metadata directory is `.spaces/`.
///
/// ```
/// <worktree>/
///   .spaces/
///     config.json        repository configuration (versioned)
///     HEAD               current ref or detached object id
///     index              staged-state index (JSON, versioned)
///     objects/xx/yyyy    content-addressed object store
///     refs/heads/*       branch refs
///     refs/tags/*        tag refs
///     refs/remotes/*     remote-tracking refs
///     refs/snapshots/*   snapshot refs (timeline)
///     logs/HEAD          reflog
///     logs/refs/...      per-ref reflogs
///     MERGE_HEAD         in-progress merge state
///     CHERRY_PICK_HEAD   in-progress cherry-pick/revert state
///     REBASE_HEAD        in-progress rebase state
///     journal            transaction journal for crash recovery
///     lock               repository mutation lock
///     hooks/             user-installed hook executables
///     lfs/               local LFS object cache (content-addressed)
///   .spacesignore        ignore patterns (Spaces-native)
///   .gitignore           also honored for interoperability
///   .spaceslfs           LFS tracking patterns
/// ```
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

    /// Walks upward from `start` looking for `.spaces/`. Returns the worktree
    /// root URL or nil.
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
