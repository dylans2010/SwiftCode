import Foundation




public struct RebaseOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    
    public struct RebaseState: Codable {
        public var onto: String
        public var ontoOID: ObjectID
        public var origHead: ObjectID
        public var origBranch: String?
        public var todo: [TodoItem]
        public var done: Int
        public var step: String?
        public var squashMessage: String?
        public var conflicts: [String]
    }

    public struct TodoItem: Codable {
        public var action: String   
        public var oid: ObjectID
        public var message: String
        public var done: Bool = false
    }

    private var stateDir: URL { repo.metaURL.appendingPathComponent("rebase-merge") }
    private var stateURL: URL { stateDir.appendingPathComponent("state.json") }
    private var todoURL: URL { stateDir.appendingPathComponent("todo.json") }
    private var origHeadURL: URL { stateDir.appendingPathComponent("orig-head") }

    public func inProgress() -> Bool {
        FileManager.default.fileExists(atPath: stateDir.path)
    }

    private func loadState() throws -> RebaseState {
        guard let data = try? Data(contentsOf: stateURL),
              let s = try? JSONDecoder().decode(RebaseState.self, from: data) else {
            throw SpacesError.invalidArgument("no rebase in progress")
        }
        return s
    }

    private func saveState(_ s: RebaseState) throws {
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(s).write(to: stateURL)
        try encoder.encode(s.todo).write(to: todoURL)
        try Data(s.origHead.hex.utf8).write(to: origHeadURL)
    }

    
    
    @discardableResult
    public func start(onto: String, branch: String? = nil,
                      todo: [String]? = nil) throws -> RebaseState? {
        try repo.performTransaction(steps: ["rebase-start:\(onto)"]) {
            if repo.inMerge() || repo.inCherryPick() || inProgress() {
                throw SpacesError.invalidArgument("another operation is in progress")
            }
            
            let ontoOID = try repo.resolveRevision(onto)
            guard let origHead = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD")
            }
            
            
            let history = try HistoryOps(repo: repo).walk(start: origHead, limit: 100_000)
            let ontoAncestors = try ancestorSet(ontoOID)
            var commits = history.filter { !ontoAncestors.contains($0.oid) }
            commits.reverse() 

            var items: [TodoItem] = commits.map {
                TodoItem(action: "pick", oid: $0.oid, message: $0.summary)
            }
            if let todoSpec = todo {
                items = try applyTodoSpec(items, spec: todoSpec)
            }
            guard !items.isEmpty else {
                
                return nil
            }

            
            let ontoCommit = try repo.commitObject(ontoOID)
            try MergeEngine(repo: repo).checkoutTree(ontoCommit.tree, overlay: [:])
            try repo.refs.setHEAD(oid: ontoOID)
            try repo.writeState("REBASE_HEAD", contents: ontoOID.hex + "\n")

            var state = RebaseState(onto: onto, ontoOID: ontoOID, origHead: origHead,
                                    origBranch: try repo.refs.currentBranch(),
                                    todo: items, done: 0, step: nil,
                                    squashMessage: nil, conflicts: [])
            try saveState(state)
            
            return try advance(&state)
        }
    }

    
    
    private func applyTodoSpec(_ items: [TodoItem], spec: [String]) throws -> [TodoItem] {
        
        var result: [TodoItem] = []
        var remaining = items
        for line in spec {
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count >= 2 else { continue }
            let action = parts[0]
            let ref = parts[1]
            
            var idx: Int? = Int(ref).map { $0 - 1 }
            if idx == nil {
                idx = remaining.firstIndex { $0.oid.hex.hasPrefix(ref) }
            }
            guard let i = idx, i >= 0, i < remaining.count else {
                throw SpacesError.invalidArgument("rebase todo: cannot resolve '\(ref)'")
            }
            var item = remaining.remove(at: i)
            item.action = action
            if action == "reword", parts.count > 2 {
                item.message = parts.dropFirst(2).joined(separator: " ")
            }
            result.append(item)
        }
        
        return result
    }

    
    @discardableResult
    public func continueRebase() throws -> RebaseState? {
        try repo.performTransaction(steps: ["rebase-continue"]) {
            var state = try loadState()
            
            let unresolved = try WorktreeScanner(repo: repo).conflictedPaths()
            guard unresolved.isEmpty else { throw SpacesError.conflictsRemain(unresolved) }
            if state.step == "conflict" {
                try commitStep(&state)
            }
            return try advance(&state)
        }
    }

    
    private func advance(_ state: inout RebaseState) throws -> RebaseState? {
        
        while state.done < state.todo.count && state.todo[state.done].done {
            state.done += 1
        }
        guard state.done < state.todo.count else {
            try finish(state)
            return nil
        }
        var item = state.todo[state.done]
        switch item.action {
        case "drop":
            item.done = true
            state.todo[state.done] = item
            state.done += 1
            try saveState(state)
            return try advance(&state)
        case "edit":
            
            state.step = "edit"
            state.todo[state.done] = item
            try saveState(state)
            return state
        default:
            
            do {
                try applyPick(item, state: &state)
                state.todo[state.done].done = true
                state.done += 1
                state.step = nil
                try saveState(state)
                return try advance(&state)
            } catch let e as SpacesError {
                if case .conflictsRemain = e {
                    state.step = "conflict"
                    state.conflicts = try WorktreeScanner(repo: repo).conflictedPaths()
                    try saveState(state)
                    return state
                }
                throw e
            }
        }
    }

    
    private func applyPick(_ item: TodoItem, state: inout RebaseState) throws {
        let commit = try repo.commitObject(item.oid)
        guard let parent = commit.parents.first else {
            
            try pickRoot(item, state: &state)
            return
        }
        guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        let merged = try MergeEngine(repo: repo).mergeTrees(
            oursHead: headOID, theirsOID: item.oid, baseOID: parent)
        if !merged.conflicts.isEmpty {
            try MergeEngine(repo: repo).checkoutTree(merged.tree, overlay: merged.resolved)
            let records = merged.conflicts.map {
                WorktreeScanner.ConflictRecord(path: $0.path, resolved: false,
                                               ours: nil, theirs: nil, base: nil)
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(records).write(
                to: repo.metaURL.appendingPathComponent("conflicts.json"))
            try repo.writeState("CHERRY_PICK_HEAD", contents: item.oid.hex + "\n")
            throw SpacesError.conflictsRemain(merged.conflicts.map(\.path))
        }
        
        let ident = repo.identity()
        var message = item.message
        let isSquash = item.action == "squash" || item.action == "fixup"
        if isSquash {
            
            
            if let prevMsg = state.squashMessage {
                message = item.action == "squash" ? prevMsg + "\n\n" + item.message : prevMsg
            } else {
                message = item.message
            }
            state.squashMessage = message
        } else {
            state.squashMessage = nil
        }
        if item.action == "reword" {   }

        let headCommit = try repo.commitObject(headOID)
        let parents = isSquash ? headCommit.parents : [headOID]
        let payload = CommitPayload(tree: merged.tree, parents: parents,
                                    author: isSquash ? headCommit.author : commit.author,
                                    committer: ident,
                                    message: message.isEmpty ? commit.message : message)
        let newOID = try repo.objects.write(.commit, value: payload)
        try repo.refs.setHEAD(oid: newOID)
        try MergeEngine(repo: repo).checkoutCommit(newOID)
        try repo.appendReflog(refName: "HEAD", old: headOID, new: newOID,
                              message: "rebase: \(item.action) \(String(item.oid.hex.prefix(7)))")
    }

    private func pickRoot(_ item: TodoItem, state: inout RebaseState) throws {
        let commit = try repo.commitObject(item.oid)
        guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        
        let headTree = try repo.commitObject(headOID).tree
        
        
        
        let baseFlat: [String: (oid: ObjectID, mode: FileMode)] = [:]
        let oursFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: headTree)
        let theirsFlat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
        let diffs = try DiffOps(repo: repo).diffFlats(baseFlat, theirsFlat)
        var mergedFlat = oursFlat
        for d in diffs {
            if d.status == .added || d.status == .modified || d.status == .renamed {
                if let nid = d.newOID, let nmode = d.newMode {
                    mergedFlat[d.newPath] = (nid, nmode)
                }
            }
        }
        let treeOID = try TreeBuilder.writeTree(entries: mergedFlat, objects: repo.objects)
        let ident = repo.identity()
        let payload = CommitPayload(tree: treeOID, parents: [headOID],
                                    author: commit.author, committer: ident,
                                    message: commit.message)
        let newOID = try repo.objects.write(.commit, value: payload)
        try repo.refs.setHEAD(oid: newOID)
        try MergeEngine(repo: repo).checkoutCommit(newOID)
        try repo.appendReflog(refName: "HEAD", old: headOID, new: newOID,
                              message: "rebase: pick \(String(item.oid.hex.prefix(7)))")
    }

    
    private func commitStep(_ state: inout RebaseState) throws {
        guard state.done < state.todo.count else { return }
        let item = state.todo[state.done]
        let commit = try repo.commitObject(item.oid)
        _ = commit
        _ = try StagingOps(repo: repo).add(".", all: true)
        let staging = StagingOps(repo: repo)
        let treeOID = try staging.writeIndexTree()
        guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        let ident = repo.identity()
        let payload = CommitPayload(tree: treeOID, parents: [headOID],
                                    author: commit.author, committer: ident,
                                    message: item.message.isEmpty ? commit.message : item.message)
        let newOID = try repo.objects.write(.commit, value: payload)
        try repo.refs.setHEAD(oid: newOID)
        repo.clearState(["CHERRY_PICK_HEAD", "conflicts.json"])
        try repo.appendReflog(refName: "HEAD", old: headOID, new: newOID,
                              message: "rebase: resolved \(String(item.oid.hex.prefix(7)))")
        state.step = nil
        state.todo[state.done].done = true
        state.done += 1
        try saveState(state)
    }

    
    public func skip() throws -> RebaseState? {
        try repo.performTransaction(steps: ["rebase-skip"]) {
            var state = try loadState()
            
            if let headOID = try repo.refs.headOID(objects: repo.objects),
               let headCommit = try? repo.commitObject(headOID) {
                try MergeEngine(repo: repo).checkoutTree(headCommit.tree, overlay: [:])
            }
            repo.clearState(["CHERRY_PICK_HEAD", "conflicts.json"])
            if state.done < state.todo.count {
                state.todo[state.done].done = true
                state.done += 1
                state.step = nil
            }
            try saveState(state)
            return try advance(&state)
        }
    }

    
    public func abort() throws {
        try repo.performTransaction(steps: ["rebase-abort"]) {
            guard inProgress() else { throw SpacesError.invalidArgument("no rebase in progress") }
            let state = try loadState()
            
            if let branch = state.origBranch {
                _ = try repo.refs.updateRef("refs/heads/\(branch)", to: state.origHead)
                try repo.refs.setHEAD(ref: "refs/heads/\(branch)")
            } else {
                try repo.refs.setHEAD(oid: state.origHead)
            }
            let origCommit = try repo.commitObject(state.origHead)
            try MergeEngine(repo: repo).checkoutTree(origCommit.tree, overlay: [:])
            repo.clearState(["REBASE_HEAD", "conflicts.json"])
            try? FileManager.default.removeItem(at: stateDir)
            try repo.appendReflog(refName: "HEAD", old: nil, new: state.origHead,
                                  message: "rebase aborted")
        }
    }

    
    private func finish(_ state: RebaseState) throws {
        guard let newHead = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        if let branch = state.origBranch {
            _ = try repo.refs.updateRef("refs/heads/\(branch)", to: newHead)
            try repo.refs.setHEAD(ref: "refs/heads/\(branch)")
        } else {
            try repo.refs.setHEAD(oid: newHead)
        }
        repo.clearState(["REBASE_HEAD", "conflicts.json"])
        try? FileManager.default.removeItem(at: stateDir)
        try repo.appendReflog(refName: "HEAD", old: state.origHead, new: newHead,
                              message: "rebase finished onto \(state.onto)")
    }

    private func ancestorSet(_ start: ObjectID) throws -> Set<ObjectID> {
        var seen = Set<ObjectID>()
        var stack = [start]
        while let oid = stack.popLast() {
            guard seen.insert(oid).inserted else { continue }
            stack.append(contentsOf: try repo.commitObject(oid).parents)
        }
        return seen
    }
}
