import Foundation

public struct HistoricalSearchOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct HistoricalMatch: Sendable {
        public var commit: ObjectID
        public var path: String
        public var line: Int
        public var text: String
        public var summary: String
        public var timestamp: Int64
    }

    public static let maxCommitsScanned = 500
    public static let maxBlobBytes = 1_048_576

    public func search(query: String, limit: Int = 100,
                       useRegex: Bool = false) throws -> [HistoricalMatch] {
        guard !query.isEmpty else {
            throw SpacesError.invalidArgument("history query must not be empty")
        }
        let regex: NSRegularExpression?
        if useRegex {
            do {
                regex = try NSRegularExpression(pattern: query)
            } catch {
                throw SpacesError.invalidArgument("invalid regular expression: \(query)")
            }
        } else {
            regex = nil
        }
        let lowered = query.lowercased()
        var matches: [HistoricalMatch] = []
        let commits = try HistoryOps(repo: repo).log(limit: Self.maxCommitsScanned)
        for commit in commits {
            let payload = try repo.commitObject(commit.oid)
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: payload.tree)
            for path in flat.keys.sorted() {
                let entry = flat[path]!
                guard let data = try? repo.blobData(entry.oid),
                      data.count <= Self.maxBlobBytes,
                      !DiffEngine.isBinary(data),
                      String(data: data, encoding: .utf8) != nil else { continue }
                for (index, line) in DiffEngine.splitLines(data).enumerated() {
                    let hit: Bool
                    if let regex {
                        let range = NSRange(line.startIndex..., in: line)
                        hit = regex.firstMatch(in: line, options: [], range: range) != nil
                    } else {
                        hit = line.lowercased().contains(lowered)
                    }
                    if hit {
                        matches.append(HistoricalMatch(
                            commit: commit.oid, path: path, line: index + 1,
                            text: line, summary: commit.summary,
                            timestamp: commit.timestamp))
                        if matches.count >= max(0, limit) { return matches }
                    }
                }
            }
        }
        return matches
    }
}
