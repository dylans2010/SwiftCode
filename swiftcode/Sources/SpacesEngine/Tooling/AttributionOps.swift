import Foundation

public struct AttributionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct LineOrigin: Codable, Sendable, Equatable {
        public var path: String
        public var line: Int
        public var commit: ObjectID
        public var author: String
        public var timestamp: Int64
        public var text: String
        public var renamedFrom: String?

        public init(path: String, line: Int, commit: ObjectID, author: String, timestamp: Int64, text: String, renamedFrom: String? = nil) {
            self.path = path
            self.line = line
            self.commit = commit
            self.author = author
            self.timestamp = timestamp
            self.text = text
            self.renamedFrom = renamedFrom
        }
    }

    public struct SymbolOriginEntry: Codable, Sendable, Equatable {
        public var commit: ObjectID
        public var path: String
        public var line: Int
        public var signature: String
        public var timestamp: Int64

        public init(commit: ObjectID, path: String, line: Int, signature: String, timestamp: Int64) {
            self.commit = commit
            self.path = path
            self.line = line
            self.signature = signature
            self.timestamp = timestamp
        }
    }

    public struct SymbolOrigin: Codable, Sendable, Equatable {
        public var symbol: String
        public var entries: [SymbolOriginEntry]
        public var firstSeenCommit: ObjectID?
        public var firstSeenPath: String?

        public init(symbol: String, entries: [SymbolOriginEntry], firstSeenCommit: ObjectID? = nil, firstSeenPath: String? = nil) {
            self.symbol = symbol
            self.entries = entries
            self.firstSeenCommit = firstSeenCommit
            self.firstSeenPath = firstSeenPath
        }
    }

    public func traceLineOrigin(path: String, line: Int, rev: String = "HEAD") throws -> LineOrigin {
        guard line >= 1 else { throw SpacesError.invalidArgument("line must be at least 1") }
        guard !path.isEmpty else { throw SpacesError.invalidArgument("path must not be empty") }
        let startOID = try repo.resolveRevision(rev)
        var currentPath = path
        var renamedFrom: String? = nil
        let walked = try HistoryOps(repo: repo).walk(start: startOID, firstParentOnly: true, limit: 10000)
        for commit in walked {
            guard let parent = commit.parents.first else { continue }
            let parentCommit = try repo.commitObject(parent)
            let actualDiffs = try DiffOps(repo: repo).diffTrees(parentCommit.tree, try repo.commitObject(commit.oid).tree)
            if let renamed = actualDiffs.first(where: { $0.status == .renamed && $0.newPath == currentPath }) {
                renamedFrom = renamed.oldPath
                currentPath = renamed.oldPath
            }
        }
        let blame = try HistoryOps(repo: repo).blame(currentPath, rev: rev)
        guard line <= blame.count else { throw SpacesError.invalidArgument("line \(line) is beyond the end of \(currentPath)") }
        let origin = blame[line - 1]
        return LineOrigin(path: currentPath, line: line, commit: origin.commit, author: origin.author, timestamp: origin.timestamp, text: origin.line, renamedFrom: renamedFrom)
    }

    public func traceSymbolOrigin(symbol: String) throws -> SymbolOrigin {
        guard !symbol.isEmpty else { throw SpacesError.invalidArgument("symbol must not be empty") }
        var entries: [SymbolOriginEntry] = []
        for commit in try HistoryOps(repo: repo).log(limit: 10000) {
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: try repo.commitObject(commit.oid).tree)
            for path in flat.keys.filter({ $0.hasSuffix(".swift") }).sorted() {
                guard let text = try? repo.blobData(flat[path]!.oid), let source = String(data: text, encoding: .utf8) else { continue }
                guard let declaration = SwiftDeclarationParser.parse(source).first(where: { $0.name == symbol }) else { continue }
                entries.append(SymbolOriginEntry(commit: commit.oid, path: path, line: declaration.line, signature: declaration.signature, timestamp: commit.timestamp))
                break
            }
        }
        let oldest = entries.last
        return SymbolOrigin(symbol: symbol, entries: entries, firstSeenCommit: oldest?.commit, firstSeenPath: oldest?.path)
    }
}
