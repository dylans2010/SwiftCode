import Foundation

public struct SnapshotIntegrityOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct SnapshotVerification: Sendable, Codable {
        public var oid: ObjectID
        public var valid: Bool
        public var checkedObjects: Int
        public var issues: [String]
    }

    public func verifySnapshot(rev: String) throws -> SnapshotVerification {
        let oid = try repo.resolveRevision(rev)
        _ = try SnapshotOps(repo: repo).inspect(rev)
        var checked = 0
        var issues: [String] = []
        var visited = Set<ObjectID>()

        func check(_ id: ObjectID) {
            guard visited.insert(id).inserted else { return }
            let stored: StoredObject
            do {
                stored = try repo.objects.read(id)
            } catch {
                issues.append("object \(id.hex): \(error.localizedDescription)")
                return
            }
            checked += 1
            switch stored.type {
            case .blob:
                break
            case .tree:
                guard let tree = try? JSONDecoder().decode(TreePayload.self, from: stored.payload) else {
                    issues.append("object \(id.hex): undecodable tree payload")
                    return
                }
                for entry in tree.entries { check(entry.oid) }
            case .commit:
                guard let commit = try? JSONDecoder().decode(CommitPayload.self, from: stored.payload) else {
                    issues.append("object \(id.hex): undecodable commit payload")
                    return
                }
                check(commit.tree)
                for parent in commit.parents { check(parent) }
            case .tag:
                guard let tag = try? JSONDecoder().decode(TagPayload.self, from: stored.payload) else {
                    issues.append("object \(id.hex): undecodable tag payload")
                    return
                }
                check(tag.object)
            case .snapshot:
                guard let snapshot = try? JSONDecoder().decode(SnapshotPayload.self, from: stored.payload) else {
                    issues.append("object \(id.hex): undecodable snapshot payload")
                    return
                }
                check(snapshot.tree)
                if let indexTree = snapshot.indexTree { check(indexTree) }
                for parent in snapshot.parents { check(parent) }
            }
        }

        check(oid)
        return SnapshotVerification(oid: oid, valid: issues.isEmpty,
                                    checkedObjects: checked, issues: issues)
    }

    public func verifyAllSnapshots() throws -> [SnapshotVerification] {
        var results: [SnapshotVerification] = []
        for snapshot in try SnapshotOps(repo: repo).list() {
            results.append(try verifySnapshot(snapshot.oid.hex))
        }
        return results
    }
}
