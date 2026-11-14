import Foundation

public struct FileEvolutionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum EvolutionChange: String, Sendable {
        case added, modified, deleted, renamed
    }

    public struct EvolutionStep: Sendable {
        public var commit: ObjectID
        public var timestamp: Int64
        public var summary: String
        public var change: EvolutionChange
        public var oldPath: String?
        public var path: String
    }

    public func evolutionOf(path: String, limit: Int = 100) throws -> [EvolutionStep] {
        guard !path.isEmpty else {
            throw SpacesError.invalidArgument("evolution path must not be empty")
        }
        let emptyTree = try TreeBuilder.emptyTree(objects: repo.objects)
        var currentPath = path
        var steps: [EvolutionStep] = []
        let commits = try HistoryOps(repo: repo).log(limit: 10_000)
        for commit in commits {
            if steps.count >= max(0, limit) { break }
            let payload = try repo.commitObject(commit.oid)
            let parentTree: ObjectID
            if let parent = payload.parents.first {
                parentTree = try repo.commitObject(parent).tree
            } else {
                parentTree = emptyTree
            }
            let diffs = try DiffOps(repo: repo).diffTrees(parentTree, payload.tree)
            guard let diff = diffs.first(where: {
                $0.newPath == currentPath || $0.oldPath == currentPath
            }) else { continue }
            let change: EvolutionChange
            switch diff.status {
            case .added: change = .added
            case .deleted: change = .deleted
            case .modified, .typechanged: change = .modified
            case .renamed: change = .renamed
            }
            let stepPath = diff.status == .deleted ? diff.oldPath : diff.newPath
            steps.append(EvolutionStep(
                commit: commit.oid, timestamp: commit.timestamp,
                summary: commit.summary, change: change,
                oldPath: diff.status == .renamed ? diff.oldPath : nil,
                path: stepPath))
            if diff.status == .renamed {
                currentPath = diff.oldPath
            }
        }
        return steps
    }
}
