import Foundation

public struct DependencyAuditOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let maxCommitsScanned = 200

    public struct DependencyChange: Codable, Sendable {
        public var commit: String
        public var summary: String
        public var manifests: [String]
        public var lockfiles: [String]
        public var manifestsChangedWithLockfile: Bool

        public init(commit: String, summary: String, manifests: [String], lockfiles: [String],
                    manifestsChangedWithLockfile: Bool) {
            self.commit = commit
            self.summary = summary
            self.manifests = manifests
            self.lockfiles = lockfiles
            self.manifestsChangedWithLockfile = manifestsChangedWithLockfile
        }
    }

    static let manifestNames: Set<String> = ["Package.swift", "Podfile", "package.json"]
    static let lockfileNames: Set<String> = ["Package.resolved", "Podfile.lock", "package-lock.json"]

    static func isManifest(path: String) -> Bool {
        let base = path.split(separator: "/").last.map(String.init) ?? path
        return manifestNames.contains(base)
    }

    static func isLockfile(path: String) -> Bool {
        let base = path.split(separator: "/").last.map(String.init) ?? path
        return lockfileNames.contains(base) || base.hasSuffix(".lock")
    }

    public func dependencyChangeAudit(limit: Int = 100) throws -> [DependencyChange] {
        let bound = max(0, min(limit, Self.maxCommitsScanned))
        guard bound > 0 else { return [] }
        let commits = try HistoryOps(repo: repo).log(limit: bound)
        var results: [DependencyChange] = []
        for info in commits {
            let commit = try repo.commitObject(info.oid)
            let oldTree: ObjectID
            if let parent = commit.parents.first {
                oldTree = try repo.commitObject(parent).tree
            } else {
                oldTree = try TreeBuilder.writeTree(entries: [:], objects: repo.objects)
            }
            let diffs = try DiffOps(repo: repo).diffTrees(oldTree, commit.tree)
            var manifests = Set<String>()
            var lockfiles = Set<String>()
            for diff in diffs {
                for path in [diff.oldPath, diff.newPath] {
                    if Self.isManifest(path: path) { manifests.insert(path) }
                    if Self.isLockfile(path: path) { lockfiles.insert(path) }
                }
            }
            guard !manifests.isEmpty || !lockfiles.isEmpty else { continue }
            results.append(DependencyChange(
                commit: info.oid.hex,
                summary: info.summary,
                manifests: manifests.sorted(),
                lockfiles: lockfiles.sorted(),
                manifestsChangedWithLockfile: !manifests.isEmpty && !lockfiles.isEmpty))
        }
        return results
    }
}
