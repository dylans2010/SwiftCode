import Foundation

/// Object payload models. All payloads are JSON documents so the format stays
/// inspectable and version-tolerant; unknown keys are ignored on decode.
public struct TreeEntry: Codable, Hashable, Sendable {
    public var name: String
    public var mode: FileMode
    public var oid: ObjectID

    public init(name: String, mode: FileMode, oid: ObjectID) {
        self.name = name
        self.mode = mode
        self.oid = oid
    }
}

public enum FileMode: String, Codable, Sendable {
    case regular = "100644"
    case executable = "100755"
    case symlink = "120000"
    case directory = "040000"

    public var isDirectory: Bool { self == .directory }
    public var isSymlink: Bool { self == .symlink }
}

/// A tree object payload: sorted entries by name (directories sort as "name/").
public struct TreePayload: Codable, Sendable {
    public var entries: [TreeEntry]

    public init(entries: [TreeEntry]) { self.entries = entries }
}

/// Identity attached to commits and tags.
public struct Signature: Codable, Hashable, Sendable {
    public var name: String
    public var email: String
    public var timestamp: Int64 // seconds since 1970

    public init(name: String, email: String, timestamp: Int64 = Int64(Date().timeIntervalSince1970)) {
        self.name = name
        self.email = email
        self.timestamp = timestamp
    }

    /// Parses `"Name <email> timestamp"` used in commit messages' trailers.
    public static func parse(_ line: String) -> Signature? {
        // Not used for header fields; kept for trailer parsing helpers.
        nil
    }
}

/// Structured key/value metadata attached to commits (trailers, categories).
public struct CommitMetadata: Codable, Hashable, Sendable {
    public var trailers: [String: String]
    public var category: String?
    public var annotations: [String]
    public var signature: String? // detached signature payload, base64, if signed

    public init(trailers: [String: String] = [:], category: String? = nil,
                annotations: [String] = [], signature: String? = nil) {
        self.trailers = trailers
        self.category = category
        self.annotations = annotations
        self.signature = signature
    }
}

public struct CommitPayload: Codable, Sendable {
    public var tree: ObjectID
    public var parents: [ObjectID]
    public var author: Signature
    public var committer: Signature
    public var message: String
    public var metadata: CommitMetadata

    public init(tree: ObjectID, parents: [ObjectID], author: Signature,
                committer: Signature, message: String,
                metadata: CommitMetadata = CommitMetadata()) {
        self.tree = tree
        self.parents = parents
        self.author = author
        self.committer = committer
        self.message = message
        self.metadata = metadata
    }

    /// First line of the message — the summary used by logs.
    public var summary: String {
        message.split(separator: "\n", omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
    }
}

public struct TagPayload: Codable, Sendable {
    public var object: ObjectID
    public var objectType: ObjectType
    public var name: String
    public var tagger: Signature?
    public var message: String
    public var signature: String?

    public init(object: ObjectID, objectType: ObjectType, name: String,
                tagger: Signature? = nil, message: String = "",
                signature: String? = nil) {
        self.object = object
        self.objectType = objectType
        self.name = name
        self.tagger = tagger
        self.message = message
        self.signature = signature
    }
}

/// Snapshot payload: a recovery/checkpoint object. Snapshots are commits of
/// the working tree that additionally record the index state and the reason
/// the snapshot was taken, so they can be browsed on the repository timeline
/// independently of commit history.
public struct SnapshotPayload: Codable, Sendable {
    public var tree: ObjectID        // working-tree contents
    public var indexTree: ObjectID?  // staged state at snapshot time
    public var parents: [ObjectID]
    public var author: Signature
    public var timestamp: Int64
    public var message: String
    public var kind: String          // manual | automatic | pre-operation | scheduled | workspace
    public var operation: String?    // e.g. "merge", "rebase", "reset" for checkpoints
    public var metadata: [String: String]

    public init(tree: ObjectID, indexTree: ObjectID? = nil, parents: [ObjectID] = [],
                author: Signature, timestamp: Int64 = Int64(Date().timeIntervalSince1970),
                message: String, kind: String, operation: String? = nil,
                metadata: [String: String] = [:]) {
        self.tree = tree
        self.indexTree = indexTree
        self.parents = parents
        self.author = author
        self.timestamp = timestamp
        self.message = message
        self.kind = kind
        self.operation = operation
        self.metadata = metadata
    }
}
