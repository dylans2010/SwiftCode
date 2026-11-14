import Foundation

public struct DependencyGraphOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct DependencyEdge: Codable, Sendable, Hashable {
        public var from: String
        public var to: String
    }

    public struct DependencyGraph: Codable, Sendable {
        public var nodes: [String]
        public var edges: [DependencyEdge]
    }

    private struct DependencyCacheFile: Codable {
        var version: Int
        var files: [String: String]
        var graph: DependencyGraph
    }

    private var cacheURL: URL {
        get throws {
            try SpacesIntelligenceStore.intelligenceDirectory(repo: repo)
                .appendingPathComponent("dependencies.json")
        }
    }

    private func currentFileOIDs() throws -> [String: String] {
        var result: [String: String] = [:]
        for (path, entry) in try repo.index().entries where path.hasSuffix(".swift") {
            result[path] = entry.oid.hex
        }
        return result
    }

    @discardableResult
    public func refresh() throws -> DependencyGraph {
        try repo.withLock {
            let url = try cacheURL
            let stored: DependencyCacheFile? = try SpacesIntelligenceStore.readJSON(
                DependencyCacheFile.self, from: url)
            let oids = try currentFileOIDs()
            var edgesByFile: [String: [DependencyEdge]] = [:]
            if let stored {
                for edge in stored.graph.edges {
                    edgesByFile[edge.from, default: []].append(edge)
                }
            }
            var nodes = Set<String>()
            var edges: [DependencyEdge] = []
            for path in oids.keys.sorted() {
                nodes.insert(path)
                if stored?.files[path] == oids[path], let cached = edgesByFile[path] {
                    edges.append(contentsOf: cached)
                    for edge in cached { nodes.insert(edge.to) }
                    continue
                }
                guard let entry = try repo.index().entries[path],
                      let text = SpacesIntelligenceStore.blobText(repo: repo, oid: entry.oid) else {
                    continue
                }
                for module in SemanticSearchOps.imports(in: text) {
                    let edge = DependencyEdge(from: path, to: module)
                    edges.append(edge)
                    nodes.insert(module)
                }
            }
            edges.sort { ($0.from, $0.to) < ($1.from, $1.to) }
            let graph = DependencyGraph(nodes: nodes.sorted(), edges: edges)
            try SpacesIntelligenceStore.writeJSON(
                DependencyCacheFile(version: 1, files: oids, graph: graph), to: url)
            return graph
        }
    }

    public func graph() throws -> DependencyGraph {
        let stored: DependencyCacheFile? = try SpacesIntelligenceStore.readJSON(
            DependencyCacheFile.self, from: cacheURL)
        if let stored, stored.files == (try? currentFileOIDs()) {
            return stored.graph
        }
        return try refresh()
    }
}
