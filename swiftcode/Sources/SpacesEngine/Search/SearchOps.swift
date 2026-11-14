import Foundation



public struct SearchOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum ResultKind: String, Sendable, Encodable {
        case file, commit, branch, tag, object, content
    }

    public struct Result: Sendable, Encodable {
        public var kind: ResultKind
        public var title: String
        public var detail: String
        public var path: String?
        public var oid: ObjectID?
        public var line: Int?
        public var timestamp: Int64?
    }

    public struct Query: Sendable {
        public var text: String
        public var kinds: Set<ResultKind>
        public var pathPrefix: String?
        public var caseSensitive: Bool
        public var limit: Int

        public init(text: String, kinds: Set<ResultKind> = [.file, .commit, .content],
                    pathPrefix: String? = nil, caseSensitive: Bool = false, limit: Int = 100) {
            self.text = text
            self.kinds = kinds
            self.pathPrefix = pathPrefix
            self.caseSensitive = caseSensitive
            self.limit = limit
        }
    }

    
    public func search(_ query: Query) throws -> [Result] {
        var results: [Result] = []
        let needle = query.caseSensitive ? query.text : query.text.lowercased()

        func matches(_ haystack: String) -> Bool {
            query.caseSensitive ? haystack.contains(needle) : haystack.lowercased().contains(needle)
        }

        
        if query.kinds.contains(.file) {
            let scanner = WorktreeScanner(repo: repo)
            if let files = try? scanner.scan() {
                for f in files where matches(f.relativePath) {
                    results.append(Result(kind: .file, title: f.relativePath,
                                          detail: "\(f.size) bytes", path: f.relativePath))
                    if results.count >= query.limit { return results }
                }
            }
        }

        
        if query.kinds.contains(.content) {
            let index = try repo.index()
            for (path, entry) in index.entries.sorted(by: { $0.key < $1.key }) {
                if let prefix = query.pathPrefix, !path.hasPrefix(prefix) { continue }
                guard let data = try? repo.blobData(entry.oid),
                      !DiffEngine.isBinary(data),
                      let text = String(data: data, encoding: .utf8) else { continue }
                for (i, line) in text.components(separatedBy: "\n").enumerated()
                where matches(line) {
                    results.append(Result(kind: .content,
                                          title: "\(path):\(i + 1)",
                                          detail: line.trimmingCharacters(in: .whitespaces),
                                          path: path, line: i + 1))
                    if results.count >= query.limit { return results }
                }
            }
        }

        
        if query.kinds.contains(.commit) {
            for c in try HistoryOps(repo: repo).log(limit: 5000) {
                if matches(c.message) || matches(c.author.name) || matches(c.author.email)
                    || c.oid.hex.hasPrefix(query.text.lowercased()) {
                    results.append(Result(kind: .commit, title: c.summary,
                                          detail: "\(c.author.name) · \(c.oid.hex.prefix(7))",
                                          oid: c.oid, timestamp: c.timestamp))
                    if results.count >= query.limit { return results }
                }
            }
        }

        
        if query.kinds.contains(.branch) {
            for ref in try repo.refs.allRefs() where matches(ref.shortName) {
                results.append(Result(kind: ref.kind == .tag ? .tag : .branch,
                                      title: ref.shortName, detail: String(ref.oid.hex.prefix(12)),
                                      oid: ref.oid))
                if results.count >= query.limit { return results }
            }
        }

        
        if query.kinds.contains(.object), query.text.count >= 4 {
            if let oid = try? ObjectID.resolve(query.text, in: repo.objects) {
                let stored = try? repo.objects.read(oid)
                results.append(Result(kind: .object, title: oid.hex,
                                      detail: stored.map { $0.type.rawValue } ?? "missing",
                                      oid: oid))
            }
        }

        return results
    }

    
    public func findFiles(pattern: String) throws -> [String] {
        let index = try repo.index()
        let regex = try? NSRegularExpression(
            pattern: "^" + NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\*", with: ".*")
                .replacingOccurrences(of: "\\?", with: ".") + "$")
        return index.entries.keys.filter { path in
            if let r = regex {
                return r.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
            }
            return path.contains(pattern)
        }.sorted()
    }

    
    public func historyOf(path: String, limit: Int = 100) throws -> [HistoryOps.CommitInfo] {
        var result: [HistoryOps.CommitInfo] = []
        for c in try HistoryOps(repo: repo).log(limit: 10_000) {
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: cInfoTree(c))
            _ = flat
            
            guard let parent = c.parents.first else {
                
                let tree = try repo.commitObject(c.oid).tree
                let f = try TreeBuilder.flattenTree(repo: repo, treeOID: tree)
                if f[path] != nil { result.append(try HistoryOps(repo: repo).commitInfo(c.oid)) }
                continue
            }
            let parentTree = try repo.commitObject(parent).tree
            let oldFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: parentTree)
            let newFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: try repo.commitObject(c.oid).tree)
            if oldFlat[path]?.oid != newFlat[path]?.oid {
                result.append(try HistoryOps(repo: repo).commitInfo(c.oid))
            }
            if result.count >= limit { break }
        }
        return result
    }

    private func cInfoTree(_ c: HistoryOps.CommitInfo) -> ObjectID {
        
        c.oid
    }
}
