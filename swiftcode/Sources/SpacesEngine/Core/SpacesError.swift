import Foundation



public enum SpacesError: Error, Equatable, Sendable {
    case notARepository(String)
    case alreadyARepository(String)
    case repositoryLocked(String)
    case objectNotFound(String)
    case objectCorrupt(String)
    case invalidObject(String)
    case invalidRef(String)
    case refNotFound(String)
    case ambiguousRevision(String)
    case nothingToCommit
    case nothingStaged
    case mergeInProgress
    case noMergeInProgress
    case rebaseInProgress
    case conflictsRemain([String])
    case dirtyWorkingTree([String])
    case pathOutsideRepository(String)
    case pathNotFound(String)
    case pathIsDirectory(String)
    case branchExists(String)
    case branchNotFound(String)
    case detachedHead
    case invalidArgument(String)
    case unsupportedOperation(String)
    case remoteNotFound(String)
    case remoteError(String)
    case protocolError(String)
    case authenticationRequired(String)
    case indexCorrupt(String)
    case configError(String)
    case ioError(String)
    case transactionConflict(String)
    case cancelled
    case hookFailed(String, Int32, String)
    case signatureInvalid(String)
    case migrationError(String)
    case lfsError(String)
    case internalInconsistency(String)

    public var errorDescription: String? {
        switch self {
        case .notARepository(let p): return "Not a Spaces repository: \(p)"
        case .alreadyARepository(let p): return "Already a Spaces repository: \(p)"
        case .repositoryLocked(let p): return "Repository is locked by another process: \(p)"
        case .objectNotFound(let id): return "Object not found: \(id)"
        case .objectCorrupt(let id): return "Object failed integrity check: \(id)"
        case .invalidObject(let m): return "Invalid object: \(m)"
        case .invalidRef(let r): return "Invalid reference: \(r)"
        case .refNotFound(let r): return "Reference not found: \(r)"
        case .ambiguousRevision(let r): return "Ambiguous revision: \(r)"
        case .nothingToCommit: return "Nothing to commit"
        case .nothingStaged: return "Nothing staged"
        case .mergeInProgress: return "A merge is already in progress"
        case .noMergeInProgress: return "No merge is in progress"
        case .rebaseInProgress: return "A rebase is already in progress"
        case .conflictsRemain(let paths): return "Unresolved conflicts in \(paths.count) file(s): \(paths.prefix(5).joined(separator: ", "))"
        case .dirtyWorkingTree(let paths): return "Working tree has uncommitted changes: \(paths.prefix(5).joined(separator: ", "))"
        case .pathOutsideRepository(let p): return "Path is outside the repository: \(p)"
        case .pathNotFound(let p): return "Path not found: \(p)"
        case .pathIsDirectory(let p): return "Path is a directory: \(p)"
        case .branchExists(let b): return "Branch already exists: \(b)"
        case .branchNotFound(let b): return "Branch not found: \(b)"
        case .detachedHead: return "HEAD is detached"
        case .invalidArgument(let m): return "Invalid argument: \(m)"
        case .unsupportedOperation(let m): return "Unsupported operation: \(m)"
        case .remoteNotFound(let r): return "Remote not found: \(r)"
        case .remoteError(let m): return "Remote error: \(m)"
        case .protocolError(let m): return "Protocol error: \(m)"
        case .authenticationRequired(let m): return "Authentication required: \(m)"
        case .indexCorrupt(let m): return "Index is corrupt: \(m)"
        case .configError(let m): return "Configuration error: \(m)"
        case .ioError(let m): return "I/O error: \(m)"
        case .transactionConflict(let m): return "Transaction conflict: \(m)"
        case .cancelled: return "Operation cancelled"
        case .hookFailed(let h, let c, let o): return "Hook '\(h)' failed (exit \(c)): \(o)"
        case .signatureInvalid(let m): return "Invalid signature: \(m)"
        case .migrationError(let m): return "Migration error: \(m)"
        case .lfsError(let m): return "LFS error: \(m)"
        case .internalInconsistency(let m): return "Internal inconsistency: \(m)"
        }
    }
}

extension SpacesError: LocalizedError {}
