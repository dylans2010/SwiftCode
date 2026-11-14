import Foundation

public struct RiskAnalysisOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct RiskFactor: Sendable {
        public var name: String
        public var measuredValue: Double
        public var valueText: String
        public var explanation: String
    }

    public struct ChangeRisk: Sendable {
        public var commit: ObjectID
        public var score: Int
        public var scoreKind: String
        public var factors: [RiskFactor]
    }

    public static let scoreNote = "The risk score is a heuristic computed from measured characteristics of the change. It is not a prediction of defects or failure."

    public func riskOf(rev: String) throws -> ChangeRisk {
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
        let filesChanged = diffs.count
        let added = diffs.reduce(0) { $0 + $1.added }
        let removed = diffs.reduce(0) { $0 + $1.removed }
        let binaries = diffs.filter { $0.isBinary }.count
        let isMerge = commit.parents.count > 1
        let unmerged = (try? WorktreeScanner(repo: repo).status())?.unmerged ?? []
        var changedPaths = Set<String>()
        for diff in diffs {
            changedPaths.insert(diff.newPath)
            changedPaths.insert(diff.oldPath)
        }
        let priorConflicts = unmerged.filter { changedPaths.contains($0) }.count
        var factors: [RiskFactor] = []
        factors.append(RiskFactor(
            name: "filesChanged", measuredValue: Double(filesChanged),
            valueText: "\(filesChanged)",
            explanation: "Number of files changed in this commit, measured from the commit diff."))
        factors.append(RiskFactor(
            name: "linesAdded", measuredValue: Double(added),
            valueText: "\(added)",
            explanation: "Lines added in this commit, measured from the commit diff."))
        factors.append(RiskFactor(
            name: "linesRemoved", measuredValue: Double(removed),
            valueText: "\(removed)",
            explanation: "Lines removed in this commit, measured from the commit diff."))
        factors.append(RiskFactor(
            name: "binariesTouched", measuredValue: Double(binaries),
            valueText: "\(binaries)",
            explanation: "Binary files changed in this commit, which cannot be reviewed line by line."))
        factors.append(RiskFactor(
            name: "mergeCommit", measuredValue: isMerge ? 1 : 0,
            valueText: isMerge ? "yes" : "no",
            explanation: "Whether this commit has more than one parent."))
        factors.append(RiskFactor(
            name: "filesWithPriorConflicts", measuredValue: Double(priorConflicts),
            valueText: "\(priorConflicts)",
            explanation: "Files in this change that are currently listed as unmerged in the worktree status."))
        let score = min(100, filesChanged * 2 + (added + removed) / 10
                        + binaries * 15 + (isMerge ? 20 : 0) + priorConflicts * 15)
        return ChangeRisk(commit: oid, score: score, scoreKind: "heuristic", factors: factors)
    }
}
