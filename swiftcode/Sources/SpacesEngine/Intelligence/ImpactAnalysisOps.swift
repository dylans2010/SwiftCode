import Foundation

public struct ImpactAnalysisOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct ChangeImpact: Sendable {
        public var commit: ObjectID
        public var changedFiles: [String]
        public var declaredSymbols: [SemanticSearchOps.Symbol]
        public var reverseDependents: [String]
        public var directories: [String]
    }

    public func impactOf(rev: String) throws -> ChangeImpact {
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        let diffs: [DiffOps.FileDiff]
        if let parent = commit.parents.first {
            let parentTree = try repo.commitObject(parent).tree
            diffs = try DiffOps(repo: repo).diffTrees(parentTree, commit.tree)
        } else {
            let empty = try TreeBuilder.emptyTree(objects: repo.objects)
            diffs = try DiffOps(repo: repo).diffTrees(empty, commit.tree)
        }
        var changed = Set<String>()
        for diff in diffs {
            switch diff.status {
            case .deleted:
                changed.insert(diff.oldPath)
            default:
                changed.insert(diff.newPath)
            }
        }
        let changedFiles = changed.sorted()
        let allSymbols = try SemanticSearchOps(repo: repo).symbols()
        let declared = allSymbols
            .filter { changedFiles.contains($0.file) }
            .sorted { ($0.file, $0.line) < ($1.file, $1.line) }
        var dependents = Set<String>()
        if !declared.isEmpty || !changedFiles.isEmpty {
            let tracked = try repo.index()
            for path in tracked.entries.keys.sorted() where path.hasSuffix(".swift") {
                guard !changedFiles.contains(path),
                      let entry = tracked.entries[path],
                      let text = SpacesIntelligenceStore.blobText(repo: repo, oid: entry.oid) else {
                    continue
                }
                let mentionsSymbol = declared.contains { symbol in
                    guard symbol.file != path else { return false }
                    let pattern = "\\b\(NSRegularExpression.escapedPattern(for: symbol.name))\\b"
                    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
                    let range = NSRange(text.startIndex..., in: text)
                    return regex.firstMatch(in: text, options: [], range: range) != nil
                }
                let importsChangedModule = changedFiles
                    .filter { $0.hasSuffix(".swift") }
                    .map { ($0 as NSString).deletingPathExtension }
                    .map { ($0 as NSString).lastPathComponent }
                    .contains { module in
                        SemanticSearchOps.imports(in: text).contains(module)
                    }
                if mentionsSymbol || importsChangedModule {
                    dependents.insert(path)
                }
            }
        }
        var directories = Set<String>()
        for path in changedFiles {
            let parent = (path as NSString).deletingLastPathComponent
            directories.insert(parent.isEmpty ? "." : parent)
        }
        return ChangeImpact(
            commit: oid, changedFiles: changedFiles, declaredSymbols: declared,
            reverseDependents: dependents.sorted(), directories: directories.sorted())
    }
}
