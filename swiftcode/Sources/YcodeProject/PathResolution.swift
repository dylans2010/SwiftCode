import Foundation

extension PBXProj {
    public func parentMap() -> [String: String] {
        var parents: [String: String] = [:]
        for obj in objects.values {
            for child in obj.references("children") { parents[child] = obj.id }
        }
        return parents
    }

    public func projectDirectory(xcodeprojURL: URL) -> URL {
        let dir = xcodeprojURL.deletingLastPathComponent()
        guard let p = project?.string("projectDirPath"), !p.isEmpty else { return dir }
        return p.hasPrefix("/") ? URL(fileURLWithPath: p) : dir.appendingPathComponent(p).standardizedFileURL
    }

    public func resolvedPath(of id: String, projectDirectory: URL, parents: [String: String]? = nil) -> String? {
        let parents = parents ?? parentMap()
        var visited: Set<String> = []
        func resolve(_ id: String) -> String? {
            guard let obj = objects[id], visited.insert(id).inserted else { return nil }
            let path = obj.string("path") ?? ""
            switch obj.string("sourceTree") ?? "<group>" {
            case "<absolute>":
                return path
            case "SOURCE_ROOT":
                return join(projectDirectory.path, path)
            case "<group>":
                let base = parents[id].flatMap(resolve) ?? projectDirectory.path
                return join(base, path)
            case let tree:
                return path.isEmpty ? "$(\(tree))" : "$(\(tree))/\(path)"
            }
        }
        return resolve(id)
    }

    /// Returns a resolver that memoizes every intermediate object ID, so
    /// resolving many file references in one project does not re-walk shared
    /// parent chains (or re-stat the filesystem) for every lookup.
    public func resolvedPathResolver(projectDirectory: URL, parents: [String: String]? = nil) -> (String) -> String? {
        let parents = parents ?? parentMap()
        var memo: [String: String?] = [:]
        var active: Set<String> = []
        func resolve(_ id: String) -> String? {
            if let hit = memo[id] { return hit }
            guard let obj = objects[id] else { memo[id] = nil; return nil }
            guard active.insert(id).inserted else { return nil }
            defer { active.remove(id) }
            let path = obj.string("path") ?? ""
            let result: String?
            switch obj.string("sourceTree") ?? "<group>" {
            case "<absolute>":
                result = path
            case "SOURCE_ROOT":
                result = join(projectDirectory.path, path)
            case "<group>":
                let base = parents[id].flatMap(resolve) ?? projectDirectory.path
                result = join(base, path)
            case let tree:
                result = path.isEmpty ? "$(\(tree))" : "$(\(tree))/\(path)"
            }
            memo[id] = result
            return result
        }
        return resolve
    }

    private func join(_ base: String, _ rel: String) -> String {
        if rel.isEmpty { return base }
        if rel.hasPrefix("/") { return rel }
        return URL(fileURLWithPath: base).appendingPathComponent(rel).standardizedFileURL.path
    }
}
