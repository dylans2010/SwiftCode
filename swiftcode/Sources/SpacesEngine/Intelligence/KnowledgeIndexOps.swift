import Foundation

public struct KnowledgeIndexOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct KnowledgeEntry: Codable, Sendable {
        public var path: String
        public var symbols: [SemanticSearchOps.Symbol]
        public var imports: [String]
        public var commitCount: Int
        public var lastModifiedCommit: String?
        public var lastModifiedTimestamp: Int64?
    }

    private struct KnowledgeFile: Codable {
        var version: Int
        var head: String?
        var files: [String: String]
        var entries: [KnowledgeEntry]
    }

    private var indexURL: URL {
        get throws {
            try SpacesIntelligenceStore.intelligenceDirectory(repo: repo)
                .appendingPathComponent("knowledge.json")
        }
    }

    private func historyStats() throws -> [String: (count: Int, commit: ObjectID, timestamp: Int64)] {
        let emptyTree = try TreeBuilder.emptyTree(objects: repo.objects)
        var stats: [String: (count: Int, commit: ObjectID, timestamp: Int64)] = [:]
        let commits = try HistoryOps(repo: repo).log(limit: 10_000)
        for commit in commits {
            let payload = try repo.commitObject(commit.oid)
            let parentTree: ObjectID
            if let parent = payload.parents.first {
                parentTree = try repo.commitObject(parent).tree
            } else {
                parentTree = emptyTree
            }
            let diffs = try DiffOps(repo: repo).diffTrees(parentTree, payload.tree)
            var touched = Set<String>()
            for diff in diffs {
                switch diff.status {
                case .deleted:
                    touched.insert(diff.oldPath)
                case .renamed:
                    touched.insert(diff.oldPath)
                    touched.insert(diff.newPath)
                default:
                    touched.insert(diff.newPath)
                }
            }
            for path in touched {
                let previous = stats[path]
                if previous == nil {
                    stats[path] = (1, commit.oid, commit.timestamp)
                } else {
                    stats[path] = (previous!.count + 1, previous!.commit, previous!.timestamp)
                }
            }
        }
        return stats
    }

    @discardableResult
    public func refresh() throws -> [KnowledgeEntry] {
        try repo.withLock {
            let url = try indexURL
            let stored: KnowledgeFile? = try SpacesIntelligenceStore.readJSON(
                KnowledgeFile.self, from: url)
            let head = try repo.refs.headOID(objects: repo.objects)?.hex
            let tracked = try repo.index()
            let historyChanged = stored?.head != head
            let stats = historyChanged ? try historyStats() : [:]
            var previousByPath: [String: KnowledgeEntry] = [:]
            if let stored {
                for entry in stored.entries {
                    previousByPath[entry.path] = entry
                }
            }
            var files: [String: String] = [:]
            var entries: [KnowledgeEntry] = []
            for path in tracked.entries.keys.sorted() {
                guard let indexEntry = tracked.entries[path] else { continue }
                files[path] = indexEntry.oid.hex
                let unchanged = stored?.files[path] == indexEntry.oid.hex
                if unchanged, !historyChanged, let previous = previousByPath[path] {
                    entries.append(previous)
                    continue
                }
                var symbols: [SemanticSearchOps.Symbol] = []
                var imports: [String] = []
                if path.hasSuffix(".swift"),
                   let text = SpacesIntelligenceStore.blobText(repo: repo, oid: indexEntry.oid) {
                    symbols = SemanticSearchOps.declarations(in: text, file: path)
                    imports = SemanticSearchOps.imports(in: text)
                }
                let stat = historyChanged ? stats[path] : nil
                let previous = previousByPath[path]
                entries.append(KnowledgeEntry(
                    path: path, symbols: symbols, imports: imports,
                    commitCount: stat?.count ?? previous?.commitCount ?? 0,
                    lastModifiedCommit: stat?.commit.hex ?? previous?.lastModifiedCommit,
                    lastModifiedTimestamp: stat?.timestamp ?? previous?.lastModifiedTimestamp))
            }
            let ordered = entries.sorted { $0.path < $1.path }
            try SpacesIntelligenceStore.writeJSON(
                KnowledgeFile(version: 1, head: head, files: files, entries: ordered), to: url)
            return ordered
        }
    }

    public func entries() throws -> [KnowledgeEntry] {
        let stored: KnowledgeFile? = try SpacesIntelligenceStore.readJSON(
            KnowledgeFile.self, from: indexURL)
        if stored != nil {
            let head = try repo.refs.headOID(objects: repo.objects)?.hex
            if stored!.head == head {
                var dirty = false
                let tracked = try repo.index()
                for (path, entry) in tracked.entries where stored!.files[path] != entry.oid.hex {
                    dirty = true
                    break
                }
                if !dirty, stored!.files.count == tracked.entries.count {
                    return stored!.entries
                }
            }
        }
        return try refresh()
    }

    public func searchKnowledge(query: String, limit: Int = 100) throws -> [KnowledgeEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            throw SpacesError.invalidArgument("knowledge query must not be empty")
        }
        let all = try entries()
        let matches = all.filter { entry in
            entry.path.lowercased().contains(needle)
                || entry.symbols.contains { $0.name.lowercased().contains(needle) }
        }
        return Array(matches.prefix(max(0, limit)))
    }
}
