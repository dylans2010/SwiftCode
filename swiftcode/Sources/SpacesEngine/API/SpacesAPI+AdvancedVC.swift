import Foundation

extension SpacesAPI {
    private struct TwoPhaseRepoState: Codable {
        var path: String
        var branch: String?
        var preRef: String?
        var committed: String?
        var error: String?
        var skipped: Bool
    }

    private struct TwoPhaseRecord: Codable {
        var tx: String
        var message: String
        var status: String
        var repos: [TwoPhaseRepoState]
        var created: Int64
    }

    private func twoPhaseJournalURL(tx: String) -> URL {
        repo.metaURL.appendingPathComponent("multirepo2pc").appendingPathComponent("\(tx).json")
    }

    private func writeTwoPhaseRecord(_ record: TwoPhaseRecord) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let url = twoPhaseJournalURL(tx: record.tx)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try repo.refs.atomicWrite(url, contents: encoder.encode(record))
    }

    private func readTwoPhaseRecord(tx: String) throws -> TwoPhaseRecord {
        let url = twoPhaseJournalURL(tx: tx)
        guard let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(TwoPhaseRecord.self, from: data) else {
            throw SpacesError.invalidArgument("no multi-repo transaction \(tx)")
        }
        return record
    }

    private func rollbackTwoPhaseRepo(_ state: TwoPhaseRepoState) throws {
        let target = try Repository.open(at: URL(fileURLWithPath: state.path))
        if let branch = state.branch {
            if let pre = state.preRef, let oid = try? ObjectID(validating: pre) {
                let old = try target.refs.updateRef("refs/heads/" + branch, to: oid)
                try target.appendReflog(refName: "refs/heads/" + branch, old: old, new: oid,
                                        message: "multirepo rollback")
            } else {
                try target.refs.deleteRef("refs/heads/" + branch)
            }
        } else if let pre = state.preRef, let oid = try? ObjectID(validating: pre) {
            try target.refs.setHEAD(oid: oid)
        }
    }

    private func currentTwoPhaseTip(_ state: TwoPhaseRepoState) throws -> String? {
        let target = try Repository.open(at: URL(fileURLWithPath: state.path))
        if let branch = state.branch {
            return try target.refs.readRef("refs/heads/" + branch)?.hex
        }
        return try target.refs.headOID(objects: target.objects)?.hex
    }

    @discardableResult
    public func multiRepoCommit(repos: [URL], message: String, allowEmpty: Bool = false) throws -> MultiRepoCommitOps.MultiRepoCommitResult {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpacesError.invalidArgument("commit message must not be empty")
        }
        guard !repos.isEmpty else {
            throw SpacesError.invalidArgument("at least one repository is required")
        }
        let tx = UUID().uuidString
        var states: [TwoPhaseRepoState] = []
        for url in repos {
            let path = url.standardizedFileURL.path
            do {
                let target = try Repository.open(at: url)
                let api = SpacesAPI(repo: target)
                let branch = try target.refs.currentBranch()
                let preRef: String?
                if let branch {
                    preRef = try target.refs.readRef("refs/heads/" + branch)?.hex
                } else {
                    preRef = try target.refs.headOID(objects: target.objects)?.hex
                }
                let staged = try api.status().staged
                if staged.isEmpty && !allowEmpty {
                    states.append(TwoPhaseRepoState(path: path, branch: branch, preRef: preRef,
                                                    committed: nil, error: "nothing staged",
                                                    skipped: true))
                } else {
                    states.append(TwoPhaseRepoState(path: path, branch: branch, preRef: preRef,
                                                    committed: nil, error: nil, skipped: false))
                }
            } catch {
                states.append(TwoPhaseRepoState(path: path, branch: nil, preRef: nil,
                                                committed: nil, error: "\(error)", skipped: false))
            }
        }
        if states.contains(where: { $0.error != nil }) {
            let record = TwoPhaseRecord(tx: tx, message: message, status: "aborted",
                                        repos: states,
                                        created: Int64(Date().timeIntervalSince1970))
            try? writeTwoPhaseRecord(record)
            let outcomes = states.map {
                MultiRepoCommitOps.RepoOutcome(repoPath: $0.path, committed: nil,
                                               skipped: $0.skipped, error: $0.error)
            }
            return MultiRepoCommitOps.MultiRepoCommitResult(tx: tx, bestEffort: false,
                                                            message: message, results: outcomes)
        }
        var record = TwoPhaseRecord(tx: tx, message: message, status: "prepared",
                                    repos: states,
                                    created: Int64(Date().timeIntervalSince1970))
        try writeTwoPhaseRecord(record)
        var failurePath: String? = nil
        var failureMessage: String? = nil
        for index in states.indices {
            let path = states[index].path
            do {
                let target = try Repository.open(at: URL(fileURLWithPath: path))
                let result = try SpacesAPI(repo: target).commit(message: message)
                states[index].committed = result.oid.hex
            } catch {
                failurePath = path
                failureMessage = "\(error)"
                states[index].error = "\(error)"
                break
            }
            record.repos = states
            record.status = "partial"
            try? writeTwoPhaseRecord(record)
        }
        if let failureMessage, let failurePath {
            for state in states where state.committed != nil {
                try? rollbackTwoPhaseRepo(state)
            }
            for index in states.indices where states[index].committed != nil {
                states[index].committed = nil
                states[index].error = "rolled back after failure in \(failurePath): \(failureMessage)"
            }
            record.repos = states
            record.status = "rolled-back"
            try? writeTwoPhaseRecord(record)
            let outcomes = states.map {
                MultiRepoCommitOps.RepoOutcome(repoPath: $0.path, committed: nil,
                                               skipped: $0.skipped, error: $0.error)
            }
            return MultiRepoCommitOps.MultiRepoCommitResult(tx: tx, bestEffort: false,
                                                            message: message, results: outcomes)
        }
        record.repos = states
        record.status = "committed"
        try? writeTwoPhaseRecord(record)
        let outcomes = states.map {
            MultiRepoCommitOps.RepoOutcome(
                repoPath: $0.path,
                committed: $0.committed.flatMap { try? ObjectID(validating: $0) },
                skipped: false, error: nil)
        }
        return MultiRepoCommitOps.MultiRepoCommitResult(tx: tx, bestEffort: false,
                                                        message: message, results: outcomes)
    }

    public func multiRepoRecover(tx: String) throws -> MultiRepoCommitOps.MultiRepoRecoveryReport {
        var record = try readTwoPhaseRecord(tx: tx)
        let needsRollback = record.status == "prepared" || record.status == "partial"
        var entries: [MultiRepoCommitOps.RecoveryEntry] = []
        for state in record.repos {
            if state.skipped {
                entries.append(MultiRepoCommitOps.RecoveryEntry(
                    repoPath: state.path, committed: nil, state: "not-committed",
                    error: state.error))
                continue
            }
            guard let committedHex = state.committed,
                  let committedOID = try? ObjectID(validating: committedHex) else {
                entries.append(MultiRepoCommitOps.RecoveryEntry(
                    repoPath: state.path, committed: nil, state: "not-committed",
                    error: state.error))
                continue
            }
            do {
                let current = try currentTwoPhaseTip(state)
                if needsRollback && current == committedHex {
                    try rollbackTwoPhaseRepo(state)
                    entries.append(MultiRepoCommitOps.RecoveryEntry(
                        repoPath: state.path, committed: committedOID,
                        state: "rolled-back", error: nil))
                } else if current == committedHex {
                    entries.append(MultiRepoCommitOps.RecoveryEntry(
                        repoPath: state.path, committed: committedOID,
                        state: "committed", error: nil))
                } else if record.status == "rolled-back" {
                    entries.append(MultiRepoCommitOps.RecoveryEntry(
                        repoPath: state.path, committed: committedOID,
                        state: "rolled-back", error: nil))
                } else {
                    entries.append(MultiRepoCommitOps.RecoveryEntry(
                        repoPath: state.path, committed: committedOID,
                        state: "unknown", error: nil))
                }
            } catch {
                entries.append(MultiRepoCommitOps.RecoveryEntry(
                    repoPath: state.path, committed: committedOID,
                    state: "unknown", error: "\(error)"))
            }
        }
        if needsRollback {
            record.status = "rolled-back"
            try? writeTwoPhaseRecord(record)
        }
        let status: String
        if entries.allSatisfy({ $0.state == "committed" }) {
            status = "committed"
        } else if entries.allSatisfy({ $0.state == "not-committed" }) {
            status = "not-committed"
        } else if entries.allSatisfy({ $0.state == "rolled-back" }) {
            status = "rolled-back"
        } else {
            status = "partial"
        }
        return MultiRepoCommitOps.MultiRepoRecoveryReport(tx: tx, status: status, entries: entries)
    }

    @discardableResult
    public func createBranchCheckpoint(branch: String, name: String) throws -> ObjectID {
        try BranchCheckpointOps(repo: repo).create(branch: branch, name: name)
    }

    public func branchCheckpoints(branch: String) throws -> [BranchCheckpointOps.CheckpointInfo] {
        try BranchCheckpointOps(repo: repo).list(branch: branch)
    }

    public func restoreBranchCheckpoint(branch: String, name: String) throws {
        try BranchCheckpointOps(repo: repo).restore(branch: branch, name: name)
    }

    public func branchStates(branch: String, limit: Int = 50) throws -> [BranchTimeTravelOps.BranchState] {
        try BranchTimeTravelOps(repo: repo).states(branch: branch, limit: limit)
    }

    @discardableResult
    public func timeTravelBranch(branch: String, to: String, force: Bool = false) throws -> ObjectID {
        try BranchTimeTravelOps(repo: repo).timeTravel(branch: branch, to: to, force: force)
    }

    @discardableResult
    public func createBranchStack(name: String, branches: [String], base: String) throws -> BranchStackOps.StackRecord {
        try BranchStackOps(repo: repo).createStack(name: name, branches: branches, base: base)
    }

    public func branchStacks() throws -> [BranchStackOps.StackRecord] {
        try BranchStackOps(repo: repo).stacks()
    }

    public func branchStackStatus(name: String) throws -> BranchStackOps.StackStatus {
        try BranchStackOps(repo: repo).stackStatus(name: name)
    }

    @discardableResult
    public func updateBranchStack(name: String, branches: [String]) throws -> BranchStackOps.StackRecord {
        try BranchStackOps(repo: repo).updateStack(name: name, branches: branches)
    }

    public struct StackRebaseStep: Sendable, Codable {
        public var branch: String
        public var parent: String
        public var action: String
        public var detail: String

        public init(branch: String, parent: String, action: String, detail: String) {
            self.branch = branch
            self.parent = parent
            self.action = action
            self.detail = detail
        }
    }

    public struct StackRebaseReport: Sendable, Codable {
        public var name: String
        public var steps: [StackRebaseStep]

        public init(name: String, steps: [StackRebaseStep]) {
            self.name = name
            self.steps = steps
        }
    }

    @discardableResult
    public func restackBranchStack(name: String) throws -> StackRebaseReport {
        let record = try BranchStackOps(repo: repo).stack(name)
        var steps: [StackRebaseStep] = []
        for (index, branch) in record.branches.enumerated() {
            let parent = index == 0 ? record.base : record.branches[index - 1]
            try switchTo(branch)
            if let state = try rebase(onto: parent) {
                throw SpacesError.invalidArgument(
                    "restack stopped at \(branch): rebase onto \(parent) is incomplete (\(state.conflicts.joined(separator: ", ")))")
            }
            steps.append(StackRebaseStep(branch: branch, parent: parent, action: "rebase",
                                         detail: "rebased onto \(parent)"))
        }
        return StackRebaseReport(name: name, steps: steps)
    }

    @discardableResult
    public func rebaseAllBranchStack(name: String, onto: String) throws -> StackRebaseReport {
        let record = try BranchStackOps(repo: repo).stack(name)
        var steps: [StackRebaseStep] = []
        var parent = onto
        for branch in record.branches {
            try switchTo(branch)
            if let state = try rebase(onto: parent) {
                throw SpacesError.invalidArgument(
                    "rebase-all stopped at \(branch): rebase onto \(parent) is incomplete (\(state.conflicts.joined(separator: ", ")))")
            }
            steps.append(StackRebaseStep(branch: branch, parent: parent, action: "rebase",
                                         detail: "rebased onto \(parent)"))
            parent = branch
        }
        return StackRebaseReport(name: name, steps: steps)
    }

    @discardableResult
    public func syncBranchStack(name: String) throws -> StackRebaseReport {
        let record = try BranchStackOps(repo: repo).stack(name)
        let scanner = WorktreeScanner(repo: repo)
        var steps: [StackRebaseStep] = []
        for (index, branch) in record.branches.enumerated() {
            let parent = index == 0 ? record.base : record.branches[index - 1]
            guard let tip = try repo.refs.readRef("refs/heads/" + branch) else {
                throw SpacesError.branchNotFound(branch)
            }
            guard let parentOID = try repo.refs.readRef("refs/heads/" + parent) else {
                throw SpacesError.branchNotFound(parent)
            }
            let counts = try scanner.countAheadBehind(head: tip, upstream: parentOID)
            if counts.ahead == 0 && counts.behind > 0 {
                let old = try repo.refs.updateRef("refs/heads/" + branch, to: parentOID)
                try repo.appendReflog(refName: "refs/heads/" + branch, old: old, new: parentOID,
                                      message: "stack sync: fast-forward to \(parent)")
                steps.append(StackRebaseStep(branch: branch, parent: parent,
                                             action: "fast-forward",
                                             detail: "advanced \(counts.behind) commit(s) to \(parent)"))
            } else if counts.ahead == 0 && counts.behind == 0 {
                steps.append(StackRebaseStep(branch: branch, parent: parent, action: "up-to-date",
                                             detail: "already at \(parent)"))
            } else {
                steps.append(StackRebaseStep(branch: branch, parent: parent, action: "left-diverged",
                                             detail: "ahead \(counts.ahead), behind \(counts.behind); not fast-forwardable"))
            }
        }
        return StackRebaseReport(name: name, steps: steps)
    }

    @discardableResult
    public func createChangeSet(name: String, description: String) throws -> ChangeSetOps.ChangeSetRecord {
        try ChangeSetOps(repo: repo).createChangeSet(name: name, description: description)
    }

    public func changeSets() throws -> [ChangeSetOps.ChangeSetRecord] {
        try ChangeSetOps(repo: repo).changeSets()
    }

    public func changeSetPaths(id: String) throws -> [String] {
        try ChangeSetOps(repo: repo).changeSetPaths(id: id)
    }

    @discardableResult
    public func addToChangeSet(id: String, path: String) throws -> ChangeSetOps.ChangeSetRecord {
        try ChangeSetOps(repo: repo).addToChangeSet(id: id, path: path)
    }

    @discardableResult
    public func stageChangeSet(id: String) throws -> [String] {
        try ChangeSetOps(repo: repo).stageChangeSet(id: id)
    }

    @discardableResult
    public func partialRestore(rev: String, paths: [String]) throws -> [String] {
        try PartialRestoreOps(repo: repo).restoreFrom(rev: rev, paths: paths)
    }

    public func derivedCommitDependencies(of rev: String) throws -> [CommitGraphOps.Dependency] {
        let oid = try repo.resolveRevision(rev)
        return try derivedCommitEdges().filter { $0.from == oid }
    }

    private func derivedCommitEdges() throws -> [CommitGraphOps.Dependency] {
        let history = try HistoryOps(repo: repo).walk(limit: 10000)
        var bySummary: [String: ObjectID] = [:]
        for commit in history { bySummary[commit.summary] = commit.oid }
        var edges: [CommitGraphOps.Dependency] = []
        for commit in history {
            let payload = try repo.commitObject(commit.oid)
            for (key, value) in payload.metadata.trailers where key.lowercased() == "cherry-picked-from" {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let picked = try? repo.resolveRevision(trimmed) {
                    edges.append(CommitGraphOps.Dependency(from: commit.oid, to: picked,
                                                           kind: .dependsOn,
                                                           created: payload.committer.timestamp))
                }
            }
            if payload.message.hasPrefix("Revert ") {
                let firstLine = payload.message.components(separatedBy: "\n").first ?? ""
                let quoted = firstLine.components(separatedBy: "\"")
                if quoted.count >= 3, let reverted = bySummary[quoted[1]] {
                    edges.append(CommitGraphOps.Dependency(from: commit.oid, to: reverted,
                                                           kind: .dependsOn,
                                                           created: payload.committer.timestamp))
                }
                for line in payload.message.components(separatedBy: "\n")
                where line.contains("This reverts commit ") {
                    let hex = line.components(separatedBy: "This reverts commit ").last?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                        .split(separator: " ").first.map(String.init) ?? ""
                    if let reverted = try? repo.resolveRevision(hex) {
                        edges.append(CommitGraphOps.Dependency(from: commit.oid, to: reverted,
                                                               kind: .dependsOn,
                                                               created: payload.committer.timestamp))
                    }
                }
            }
            for parent in payload.parents.dropFirst() {
                edges.append(CommitGraphOps.Dependency(from: commit.oid, to: parent,
                                                       kind: .dependsOn,
                                                       created: payload.committer.timestamp))
            }
        }
        return edges
    }

    private func mergedDependencies(_ manual: [CommitGraphOps.Dependency],
                                    _ derived: [CommitGraphOps.Dependency]) -> [CommitGraphOps.Dependency] {
        var seen = Set<String>()
        var result: [CommitGraphOps.Dependency] = []
        for dep in manual + derived {
            let key = "\(dep.from.hex)|\(dep.to.hex)|\(dep.kind.rawValue)"
            if seen.insert(key).inserted { result.append(dep) }
        }
        return result.sorted { $0.created < $1.created }
    }

    @discardableResult
    public func addCommitDependency(from: String, to: String, kind: CommitGraphOps.DependencyKind) throws -> CommitGraphOps.Dependency {
        try CommitGraphOps(repo: repo).addDependency(from: from, to: to, kind: kind)
    }

    public func commitDependencies(of rev: String) throws -> [CommitGraphOps.Dependency] {
        let manual = try CommitGraphOps(repo: repo).dependencies(of: rev)
        let derived = try derivedCommitDependencies(of: rev)
        return mergedDependencies(manual, derived)
    }

    public func commitDependents(of rev: String) throws -> [CommitGraphOps.Dependency] {
        let manual = try CommitGraphOps(repo: repo).dependents(of: rev)
        let oid = try repo.resolveRevision(rev)
        let derived = try derivedCommitEdges().filter { $0.to == oid }
        return mergedDependencies(manual, derived)
    }

    public func commitPolicies() throws -> [ValidationPolicyOps.PolicyRule] {
        try ValidationPolicyOps(repo: repo).commitPolicies()
    }

    public func setCommitPolicies(_ rules: [ValidationPolicyOps.PolicyRule]) throws {
        try ValidationPolicyOps(repo: repo).setCommitPolicies(rules)
    }

    public func validateCommit(message: String) throws -> [ValidationPolicyOps.PolicyViolation] {
        let staged = try status().staged.map { $0.path }
        return try ValidationPolicyOps(repo: repo).validateCommit(message: message, stagedPaths: staged)
    }

    @discardableResult
    public func commitValidated(message: String) throws -> StagingOps.CommitResult {
        let violations = try validateCommit(message: message)
        guard violations.isEmpty else {
            throw SpacesError.invalidArgument("commit blocked by policy: \(violations.map { $0.message }.joined(separator: "; "))")
        }
        return try commit(message: message)
    }

    @discardableResult
    public func prepareCommit(message: String, paths: [String]) throws -> String {
        try MultiStageCommitOps(repo: repo).prepare(message: message, paths: paths)
    }

    @discardableResult
    public func validateStagedCommit(tx: String) throws -> [ValidationPolicyOps.PolicyViolation] {
        try MultiStageCommitOps(repo: repo).validate(tx: tx)
    }

    @discardableResult
    public func previewStagedCommit(tx: String) throws -> MultiStageCommitOps.StagePreview {
        try MultiStageCommitOps(repo: repo).preview(tx: tx)
    }

    @discardableResult
    public func finalizeStagedCommit(tx: String) throws -> ObjectID {
        try MultiStageCommitOps(repo: repo).finalize(tx: tx)
    }

    public func abortStagedCommit(tx: String) throws {
        try MultiStageCommitOps(repo: repo).abort(tx: tx)
    }

    public func undoableOperations() throws -> [OperationUndoOps.UndoRecord] {
        try OperationUndoOps(repo: repo).undoableOperations()
    }

    private struct RemoteUndoDetail: Codable {
        var url: String
        var pushURL: String?
    }

    private var undoLogURL: URL {
        repo.metaURL.appendingPathComponent("undo").appendingPathComponent("log.jsonl")
    }

    private func readUndoLog() -> [OperationUndoOps.UndoRecord] {
        guard let text = try? String(contentsOf: undoLogURL, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }.compactMap {
            try? JSONDecoder().decode(OperationUndoOps.UndoRecord.self, from: Data($0.utf8))
        }
    }

    private func writeUndoLog(_ records: [OperationUndoOps.UndoRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let text = records.map { record in
            String(decoding: (try? encoder.encode(record)) ?? Data(), as: UTF8.self)
        }.joined(separator: "\n") + (records.isEmpty ? "" : "\n")
        try FileManager.default.createDirectory(at: undoLogURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try repo.refs.atomicWrite(undoLogURL, contents: Data(text.utf8))
    }

    private func popUndoRecord() throws {
        try repo.withLock {
            var records = readUndoLog()
            if !records.isEmpty { records.removeLast() }
            try writeUndoLog(records)
        }
    }

    private func appendUndoRecord(operation: String, target: String, oid: String?,
                                  detail: String?) throws -> OperationUndoOps.UndoRecord {
        let record = OperationUndoOps.UndoRecord(id: UUID().uuidString, operation: operation,
                                                 target: target, oid: oid, detail: detail,
                                                 timestamp: Int64(Date().timeIntervalSince1970))
        return try repo.withLock {
            var records = readUndoLog()
            records.append(record)
            try writeUndoLog(records)
            return record
        }
    }

    private func restoreStashEntry(_ entry: StashOps.StashEntry) throws {
        let url = repo.metaURL.appendingPathComponent("stash.json")
        var entries: [StashOps.StashEntry] = []
        if let data = try? Data(contentsOf: url) {
            entries = (try? JSONDecoder().decode([StashOps.StashEntry].self, from: data)) ?? []
        }
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.insert(entry, at: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try repo.refs.atomicWrite(url, contents: encoder.encode(entries))
    }

    @discardableResult
    public func undoLast() throws -> OperationUndoOps.UndoRecord {
        let records = readUndoLog()
        guard let last = records.last else {
            throw SpacesError.invalidArgument("nothing to undo")
        }
        switch last.operation {
        case "stash-pop":
            guard let detail = last.detail, let data = detail.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(StashOps.StashEntry.self, from: data) else {
                throw SpacesError.internalInconsistency(
                    "popped stash \(last.target) has no recorded entry")
            }
            try restoreStashEntry(entry)
            try popUndoRecord()
            return last
        case "remote-add":
            try RemoteOps(repo: repo).remove(last.target)
            try popUndoRecord()
            return last
        case "remote-remove":
            guard let detail = last.detail, let data = detail.data(using: .utf8),
                  let saved = try? JSONDecoder().decode(RemoteUndoDetail.self, from: data) else {
                throw SpacesError.internalInconsistency(
                    "removed remote \(last.target) has no recorded url")
            }
            try RemoteOps(repo: repo).add(last.target, url: saved.url, pushURL: saved.pushURL)
            try popUndoRecord()
            return last
        case "config-change":
            guard let previous = last.detail else {
                throw SpacesError.internalInconsistency(
                    "config change \(last.target) has no recorded previous value")
            }
            if last.target == "core.defaultBranch" {
                var updated = repo.config
                updated.core.defaultBranch = previous
                try repo.saveConfig(updated)
            } else {
                throw SpacesError.unsupportedOperation("cannot undo config change \(last.target)")
            }
            try popUndoRecord()
            return last
        default:
            return try OperationUndoOps(repo: repo).undoLast()
        }
    }

    @discardableResult
    public func stashPopUndoable(_ id: String) throws -> OperationUndoOps.UndoRecord {
        let entry = try StashOps(repo: repo).show(id)
        let detailData = try JSONEncoder().encode(entry)
        let detail = String(decoding: detailData, as: UTF8.self)
        let record = try appendUndoRecord(operation: "stash-pop", target: entry.id,
                                          oid: entry.oid.hex, detail: detail)
        try stashApply(id, pop: true)
        return record
    }

    @discardableResult
    public func addRemoteUndoable(_ name: String, url: String) throws -> OperationUndoOps.UndoRecord {
        try RemoteOps(repo: repo).add(name, url: url)
        return try appendUndoRecord(operation: "remote-add", target: name, oid: nil, detail: url)
    }

    @discardableResult
    public func removeRemoteUndoable(_ name: String) throws -> OperationUndoOps.UndoRecord {
        guard let info = RemoteOps(repo: repo).list().first(where: { $0.name == name }) else {
            throw SpacesError.invalidArgument("no remote named \(name)")
        }
        try RemoteOps(repo: repo).remove(name)
        let detailData = try JSONEncoder().encode(
            RemoteUndoDetail(url: info.url, pushURL: info.pushURL))
        let detail = String(decoding: detailData, as: UTF8.self)
        return try appendUndoRecord(operation: "remote-remove", target: name, oid: nil,
                                    detail: detail)
    }

    @discardableResult
    public func setDefaultBranchUndoable(_ branch: String) throws -> OperationUndoOps.UndoRecord {
        let trimmed = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("default branch must not be empty")
        }
        let previous = repo.config.core.defaultBranch
        var updated = repo.config
        updated.core.defaultBranch = trimmed
        try repo.saveConfig(updated)
        return try appendUndoRecord(operation: "config-change", target: "core.defaultBranch",
                                    oid: nil, detail: previous)
    }

    @discardableResult
    public func createBranchUndoable(name: String, at rev: String = "HEAD") throws -> ObjectID {
        try OperationUndoOps(repo: repo).createBranchUndoable(name: name, at: rev)
    }

    public func deleteBranchUndoable(name: String, force: Bool = false) throws {
        try OperationUndoOps(repo: repo).deleteBranchUndoable(name: name, force: force)
    }

    @discardableResult
    public func createTagUndoable(name: String, at rev: String = "HEAD", annotated: Bool = false, message: String = "") throws -> ObjectID {
        try OperationUndoOps(repo: repo).createTagUndoable(name: name, at: rev, annotated: annotated, message: message)
    }

    public func deleteTagUndoable(name: String) throws {
        try OperationUndoOps(repo: repo).deleteTagUndoable(name: name)
    }

    @discardableResult
    public func createSnapshotUndoable(message: String) throws -> ObjectID {
        try OperationUndoOps(repo: repo).createSnapshotUndoable(message: message)
    }

    @discardableResult
    public func createStashUndoable(message: String? = nil) throws -> StashOps.StashEntry {
        try OperationUndoOps(repo: repo).createStashUndoable(message: message)
    }
}
