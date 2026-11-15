import Foundation

public struct DependencyGraphOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct DependencyEdge: Codable, Sendable, Hashable {
        public var from: String
        public var to: String
        public var resolvedPath: String? = nil

        public init(from: String, to: String, resolvedPath: String? = nil) {
            self.from = from
            self.to = to
            self.resolvedPath = resolvedPath
        }
    }

    public struct DependencyGraph: Codable, Sendable {
        public var nodes: [String]
        public var edges: [DependencyEdge]
        public var moduleMap: [String: String] = [:]

        public init(nodes: [String], edges: [DependencyEdge], moduleMap: [String: String] = [:]) {
            self.nodes = nodes
            self.edges = edges
            self.moduleMap = moduleMap
        }
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

    private func moduleFileMap() throws -> [String: String] {
        let index = try repo.index()
        let swiftFiles = index.entries.keys.filter { $0.hasSuffix(".swift") }.sorted()
        var targetNames: [String] = []
        let targetPattern = #"(?:target|executableTarget|testTarget|macro)\s*\(\s*name:\s*"([^"]+)""#
        for path in index.entries.keys.sorted() where path.hasSuffix("Package.swift") {
            guard let entry = index.entries[path],
                  let text = SpacesIntelligenceStore.blobText(repo: repo, oid: entry.oid),
                  let regex = try? NSRegularExpression(pattern: targetPattern) else { continue }
            for line in text.components(separatedBy: "\n") {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range),
                   let nameRange = Range(match.range(at: 1), in: line) {
                    targetNames.append(String(line[nameRange]))
                }
            }
        }
        var map: [String: String] = [:]
        for name in targetNames {
            let directory = "Sources/" + name
            if swiftFiles.contains(where: { $0.hasPrefix(directory + "/") }) {
                map[name] = directory
                continue
            }
            if let file = swiftFiles.first(where: { $0 == name + ".swift" }) {
                map[name] = file
                continue
            }
            if let file = swiftFiles.first(where: { $0.hasSuffix("/" + name + ".swift") }) {
                map[name] = file
            }
        }
        return map
    }

    @discardableResult
    public func refresh() throws -> DependencyGraph {
        try repo.withLock {
            let url = try cacheURL
            let stored: DependencyCacheFile? = try SpacesIntelligenceStore.readJSON(
                DependencyCacheFile.self, from: url)
            let oids = try currentFileOIDs()
            let moduleMap = try moduleFileMap()
            var edgesByFile: [String: [DependencyEdge]] = [:]
            if let stored, stored.version == 2 {
                for edge in stored.graph.edges {
                    edgesByFile[edge.from, default: []].append(edge)
                }
            }
            var nodes = Set<String>()
            var edges: [DependencyEdge] = []
            for path in oids.keys.sorted() {
                nodes.insert(path)
                if stored?.version == 2, stored?.files[path] == oids[path],
                   let cached = edgesByFile[path] {
                    edges.append(contentsOf: cached)
                    for edge in cached { nodes.insert(edge.to) }
                    continue
                }
                guard let entry = try repo.index().entries[path],
                      let text = SpacesIntelligenceStore.blobText(repo: repo, oid: entry.oid) else {
                    continue
                }
                for module in SemanticSearchOps.imports(in: text) {
                    let edge = DependencyEdge(from: path, to: module,
                                              resolvedPath: moduleMap[module])
                    edges.append(edge)
                    nodes.insert(module)
                }
            }
            edges.sort { ($0.from, $0.to) < ($1.from, $1.to) }
            let graph = DependencyGraph(nodes: nodes.sorted(), edges: edges, moduleMap: moduleMap)
            try SpacesIntelligenceStore.writeJSON(
                DependencyCacheFile(version: 2, files: oids, graph: graph), to: url)
            return graph
        }
    }

    public func graph() throws -> DependencyGraph {
        let stored: DependencyCacheFile? = try SpacesIntelligenceStore.readJSON(
            DependencyCacheFile.self, from: cacheURL)
        if let stored, stored.version == 2, stored.files == (try? currentFileOIDs()) {
            return stored.graph
        }
        return try refresh()
    }
}
