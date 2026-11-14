import Foundation

public struct SymbolHistoryOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct SymbolHistoryEntry: Codable, Sendable, Equatable {
        public var commit: ObjectID
        public var message: String
        public var author: String
        public var timestamp: Int64
        public var path: String
        public var declaration: SwiftDeclarationParser.SwiftDeclaration

        public init(commit: ObjectID, message: String, author: String, timestamp: Int64, path: String, declaration: SwiftDeclarationParser.SwiftDeclaration) {
            self.commit = commit
            self.message = message
            self.author = author
            self.timestamp = timestamp
            self.path = path
            self.declaration = declaration
        }
    }

    public func symbolHistory(symbol: String, path: String) throws -> [SymbolHistoryEntry] {
        guard !symbol.isEmpty else { throw SpacesError.invalidArgument("symbol must not be empty") }
        guard !path.isEmpty else { throw SpacesError.invalidArgument("path must not be empty") }
        var entries: [SymbolHistoryEntry] = []
        for commit in try HistoryOps(repo: repo).log(limit: 10000) {
            guard let text = try ToolingStorage.blobText(repo: repo, rev: commit.oid.hex, path: path) else { continue }
            let declarations = SwiftDeclarationParser.parse(text)
            guard let declaration = declarations.first(where: { $0.name == symbol }) else { continue }
            entries.append(SymbolHistoryEntry(commit: commit.oid, message: commit.message, author: commit.author.name, timestamp: commit.timestamp, path: path, declaration: declaration))
        }
        return entries
    }
}
