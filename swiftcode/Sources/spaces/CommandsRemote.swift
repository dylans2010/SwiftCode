import ArgumentParser
import Foundation
import SpacesEngine



struct Tag: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tag operations",
        subcommands: [TagCreate.self, TagDelete.self, TagList.self, TagVerify.self])
}

struct TagCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a tag")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @Argument var rev: String = "HEAD"
    @Flag(name: .long) var annotated: Bool = false
    @Flag(name: .long) var sign: Bool = false
    @Option(name: .shortAndLong) var message: String = ""
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "TagCreate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try TagOps(repo: repo).create(name, at: rev, annotated: annotated || !message.isEmpty,
                                                message: message, sign: sign)
        print("tag \(name) -> \(oid.hex.prefix(12))")
    }
}

struct TagDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a tag")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "TagDelete")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try TagOps(repo: repo).delete(name)
        print("deleted tag \(name)")
    }
}

struct TagList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List tags")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "TagList")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let tags = try TagOps(repo: repo).list()
        if wantsJSON(json) { printJSON(tags); return }
        for t in tags {
            let kind = t.isAnnotated ? "annotated" : "lightweight"
            print("\(t.name) \(kind) \(t.oid.hex.prefix(12)) \(t.message)")
        }
    }
}

struct Tags: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List tags")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Tags")
        var cmd = TagList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct TagVerify: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Verify a tag signature")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "TagVerify")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ok = try TagOps(repo: repo).verify(name)
        print(ok ? "signature valid" : "signature INVALID")
        if !ok { throw SpacesError.signatureInvalid(name) }
    }
}

struct VerifyTag: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tag-verify", abstract: "Verify tag (alias)")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "VerifyTag")
        var cmd = try TagVerify.parseAsRoot(["--repo", repo ?? ".", name])
        try cmd.run()
    }
}



struct Stash: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Stash operations",
        subcommands: [StashCreate.self, StashList.self, StashShow.self, StashApply.self,
                      StashPop.self, StashDrop.self, StashBranch.self])
}

struct StashCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a stash")
    @Option(name: .long) var repo: String?
    @Option(name: .shortAndLong) var message: String?
    @Flag(name: .long) var includeUntracked: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashCreate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if let e = try StashOps(repo: repo).create(message: message) {
            print("Saved working directory state: \(e.id) \(e.message)")
        } else { print("No local changes to save") }
    }
}

struct StashList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List stashes")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashList")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for e in try StashOps(repo: repo).list() {
            print("\(e.id) \(e.message) (\(e.branch ?? "-"), \(e.timestamp))")
        }
    }
}

struct Stashes: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stash-list", abstract: "List stashes")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Stashes")
        var cmd = StashList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct StashShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show a stash")
    @Option(name: .long) var repo: String?
    @Argument var id: String = ""
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashShow")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StashOps(repo: repo)
        let entries = try ops.list()
        guard let e = id.isEmpty ? entries.first : entries.first(where: { $0.id == id || String($0.oid.hex.prefix(8)) == id }) else {
            throw SpacesError.refNotFound("stash")
        }
        let commit = try repo.commitObject(e.oid)
        print("stash \(e.id): \(e.message)")
        print("commit \(e.oid.hex)")
        print(commit.message)
    }
}

struct StashApply: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Apply a stash")
    @Option(name: .long) var repo: String?
    @Argument var id: String = ""
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashApply")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StashOps(repo: repo)
        let entries = try ops.list()
        guard let e = id.isEmpty ? entries.first : entries.first(where: { $0.id == id || String($0.oid.hex.prefix(8)) == id }) else {
            throw SpacesError.refNotFound("stash")
        }
        try ops.apply(e.id)
        print("applied stash \(e.id)")
    }
}

struct StashPop: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pop", abstract: "Apply and drop a stash")
    @Option(name: .long) var repo: String?
    @Argument var id: String = ""
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashPop")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StashOps(repo: repo)
        let entries = try ops.list()
        guard let e = id.isEmpty ? entries.first : entries.first(where: { $0.id == id || String($0.oid.hex.prefix(8)) == id }) else {
            throw SpacesError.refNotFound("stash")
        }
        try ops.apply(e.id, drop: true)
        print("applied and dropped stash \(e.id)")
    }
}

struct StashDrop: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "drop", abstract: "Drop a stash")
    @Option(name: .long) var repo: String?
    @Argument var id: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashDrop")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try StashOps(repo: repo).drop(id)
        print("dropped stash \(id)")
    }
}

struct StashBranch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "branch", abstract: "Create branch from stash")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @Argument var id: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "StashBranch")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try StashOps(repo: repo).branch(name, at: id)
        print("created branch \(name) from stash \(id)")
    }
}



struct Remote: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remote operations",
        subcommands: [RemoteAdd.self, RemoteRemove.self, RemoteList.self, RemoteSetURL.self])
}

struct RemoteAdd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a remote")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @Argument var url: String
    @Option(name: .long) var pushURL: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RemoteAdd")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try RemoteOps(repo: repo).add(name, url: url, pushURL: pushURL)
        print("added remote \(name): \(url)")
    }
}

struct RemoteRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove a remote")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RemoteRemove")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try RemoteOps(repo: repo).remove(name)
        print("removed remote \(name)")
    }
}

struct RemoteList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List remotes")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RemoteList")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for r in RemoteOps(repo: repo).list() {
            print("\(r.name)\t\(r.url)")
        }
    }
}

struct Remotes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List remotes")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Remotes")
        var cmd = RemoteList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct RemoteSetURL: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set-url", abstract: "Change remote URL")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @Argument var url: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RemoteSetURL")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try RemoteOps(repo: repo).setURL(name, url: url)
        print("updated \(name) -> \(url)")
    }
}

struct Fetch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch from a remote")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @Flag(name: .long) var prune: Bool = false
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Fetch")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let report = try RemoteOps(repo: repo).fetch(remote, prune: prune)
        if wantsJSON(json) { printJSON(report); return }
        print("fetched from \(report.remote): \(report.newObjects) new object(s), \(report.updatedRefs.count) ref(s) updated")
        for r in report.updatedRefs { print("  \(r)") }
    }
}

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch and merge from a remote")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @Argument var branch: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Pull")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if let outcome = try RemoteOps(repo: repo).pull(remote, branch: branch) {
            switch outcome.result {
            case .upToDate: print("Already up to date.")
            case .fastForward(let oid): print("Fast-forward to \(oid.hex.prefix(7))")
            case .merged(_, let conflicts, _):
                if conflicts.isEmpty { print("Merged successfully") }
                else { print("Conflicts: \(conflicts.joined(separator: ", "))") }
            }
        }
    }
}

struct Push: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Push to a remote")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @Argument(help: "Refspec, e.g. HEAD:refs/heads/main or branch name") var refspec: String = "HEAD"
    @Flag(name: .long) var force: Bool = false
    @Flag(name: .long) var setUpstream: Bool = false
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Push")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        var spec = refspec
        
        if refspec == "HEAD", let branch = try repo.refs.currentBranch() {
            spec = "refs/heads/\(branch):refs/heads/\(branch)"
            if setUpstream {
                repo.config.branchTracking[branch] = "\(remote)/\(branch)"
                try repo.saveConfig()
            }
        }
        let report = try RemoteOps(repo: repo).push(remote, refspec: spec, force: force)
        if wantsJSON(json) { printJSON(report); return }
        print("pushed to \(remote): \(report.refsUpdated.joined(separator: ", ")) (\(report.objectsSent) objects)")
    }
}

struct Sync: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch then push current branch")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Sync")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let result = try RemoteOps(repo: repo).sync(remote)
        if let pushError = result.pushError {
            print("sync partial: \(result.fetch.newObjects) objects fetched, push failed: \(pushError)")
            throw SpacesError.remoteError("push failed during sync: \(pushError)")
        }
        print("sync complete: \(result.fetch.newObjects) objects fetched" +
              (result.push.map { ", \($0.objectsSent) objects pushed" } ?? ""))
    }
}

struct Publish: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Push current branch and set upstream")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Publish")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        guard let branch = try repo.refs.currentBranch() else {
            throw SpacesError.detachedHead
        }
        repo.config.branchTracking[branch] = "\(remote)/\(branch)"
        try repo.saveConfig()
        let report = try RemoteOps(repo: repo).push(remote,
            refspec: "refs/heads/\(branch):refs/heads/\(branch)")
        print("published \(branch) to \(remote) (\(report.objectsSent) objects)")
    }
}

struct Unpublish: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Delete remote branch")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @Argument var branch: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Unpublish")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        guard repo.config.remotes[remote] != nil else {
            throw SpacesError.invalidArgument("no such remote: \(remote)")
        }
        guard (try? repo.refs.readRef("refs/heads/\(branch)")) != nil ||
              (try? repo.refs.readRef("refs/remotes/\(remote)/\(branch)")) != nil else {
            throw SpacesError.refNotFound("refs/heads/\(branch)")
        }
        throw SpacesError.remoteError("cannot delete remote branch \(remote)/\(branch): the Spaces transport has no remote branch deletion operation")
    }
}

struct Upstream: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set upstream")
    @Option(name: .long) var repo: String?
    @Argument var branch: String?
    @Argument var upstream: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Upstream")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let current = try repo.refs.currentBranch()
        let name = branch ?? current ?? ""
        if let up = upstream {
            repo.config.branchTracking[name] = up
            try repo.saveConfig()
            print("set \(name) upstream to \(up)")
        } else if let up = repo.config.branchTracking[name] {
            print("\(name) -> \(up)")
        } else {
            print("no upstream for \(name)")
        }
    }
}

struct Transfer: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Manual object transfer diagnostics")
    @Option(name: .long) var repo: String?
    @Argument var remote: String = "origin"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Transfer")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let report = try RemoteOps(repo: repo).fetch(remote)
        print("transfer report: \(report.newObjects) objects, \(report.remoteRefs.count) remote refs")
    }
}



struct Snapshot: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Snapshot operations",
        subcommands: [SnapshotCreate.self, SnapshotList.self, SnapshotRestore.self, SnapshotDelete.self])
}

struct SnapshotCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a snapshot")
    @Option(name: .long) var repo: String?
    @Option(name: .shortAndLong) var message: String = "manual snapshot"
    @Option(name: .long) var kind: String = "manual"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "SnapshotCreate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        guard let k = SnapshotOps.Kind(rawValue: kind) else {
            throw SpacesError.invalidArgument("unknown snapshot kind: \(kind) (manual, automatic, pre-operation, scheduled, workspace)")
        }
        let oid = try SnapshotOps(repo: repo).create(message: message, kind: k)
        print("snapshot created: \(oid.hex.prefix(12))")
    }
}

struct Snapshots: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List snapshots")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Snapshots")
        var cmd = SnapshotList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct SnapshotList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List snapshots")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "SnapshotList")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let snaps = try SnapshotOps(repo: repo).list()
        if wantsJSON(json) { printJSON(snaps); return }
        for s in snaps {
            print("\(s.timestamp) \(s.oid.hex.prefix(8)) [\(s.kind)] \(s.message)")
        }
        if snaps.isEmpty { print("no snapshots") }
    }
}

struct SnapshotRestore: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "restore", abstract: "Restore a snapshot")
    @Option(name: .long) var repo: String?
    @Argument var rev: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "SnapshotRestore")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try SnapshotOps(repo: repo).restore(rev)
        print("restored snapshot \(rev)")
    }
}

struct SnapshotDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a snapshot")
    @Option(name: .long) var repo: String?
    @Argument var rev: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "SnapshotDelete")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try SnapshotOps(repo: repo).delete(rev)
        print("deleted snapshot \(rev)")
    }
}

struct Timeline: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repository timeline (snapshots + commits + reflog)")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var limit: Int = 100
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Timeline")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for e in try SnapshotOps(repo: repo).timeline(limit: limit) {
            print("\(e.timestamp) [\(e.kind.rawValue)] \(e.title) — \(e.detail)")
        }
    }
}

struct Checkpoint: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a recovery checkpoint (snapshot)")
    @Option(name: .long) var repo: String?
    @Option(name: .shortAndLong) var message: String = "checkpoint"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Checkpoint")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try SnapshotOps(repo: repo).create(message: message, kind: .preOperation,
                                                    operation: "manual checkpoint")
        print("checkpoint: \(oid.hex.prefix(12))")
    }
}

struct Recover: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List recovery points")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Recover")
        var cmd = Timeline()
        cmd.repo = repo
        try cmd.run()
    }
}

struct RestorePoint: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a named restore point")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RestorePoint")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try SnapshotOps(repo: repo).create(message: name, kind: .manual,
                                                    metadata: ["name": name])
        print("restore point '\(name)': \(oid.hex.prefix(12))")
    }
}

struct RecoveryList: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List recovery points")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RecoveryList")
        var cmd = SnapshotList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct RecoveryPrune: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Prune old snapshots")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var olderThan: Int = 30
    @Flag(name: .long) var dryRun: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RecoveryPrune")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let cutoff = Int64(Date().timeIntervalSince1970) - Int64(olderThan * 86400)
        let snaps = try SnapshotOps(repo: repo).list()
        var removed = 0
        for s in snaps where s.timestamp < cutoff {
            if dryRun { print("would delete \(s.oid.hex.prefix(8)) \(s.message)") }
            else { try? SnapshotOps(repo: repo).delete(s.oid.hex); removed += 1 }
        }
        if !dryRun { print("pruned \(removed) snapshot(s)") }
    }
}



struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search the repository",
        subcommands: [FindFile.self, FindCommit.self, FindChange.self, FindBranch.self, FindHistory.self])
    @Option(name: .long) var repo: String?
    @Argument var query: String
    @Flag(name: .long) var files: Bool = false
    @Flag(name: .long) var commits: Bool = false
    @Flag(name: .long) var content: Bool = false
    @Flag(name: .long) var caseSensitive: Bool = false
    @Option(name: .long) var limit: Int = 50
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Search")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        var kinds: Set<SearchOps.ResultKind> = []
        if files { kinds.insert(.file) }
        if commits { kinds.insert(.commit) }
        if content { kinds.insert(.content) }
        if kinds.isEmpty { kinds = [.file, .commit, .content] }
        let q = SearchOps.Query(text: query, kinds: kinds,
                                caseSensitive: caseSensitive, limit: limit)
        let results = try SearchOps(repo: repo).search(q)
        if wantsJSON(json) { printJSON(results); return }
        for r in results {
            print("[\(r.kind.rawValue)] \(r.title)\(r.detail.isEmpty ? "" : " — \(r.detail)")")
        }
        if results.isEmpty { print("no results") }
    }
}

struct Find: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search (alias)")
    @Option(name: .long) var repo: String?
    @Argument var query: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Find")
        var cmd = try Search.parseAsRoot(["--repo", repo ?? ".", query])
        try cmd.run()
    }
}

struct FindFile: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "find-file", abstract: "Find files by pattern")
    @Option(name: .long) var repo: String?
    @Argument var pattern: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "FindFile")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for p in try SearchOps(repo: repo).findFiles(pattern: pattern) { print(p) }
    }
}

struct FindCommit: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "find-commit", abstract: "Find commits by message")
    @Option(name: .long) var repo: String?
    @Argument var query: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "FindCommit")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let q = SearchOps.Query(text: query, kinds: [.commit], limit: 100)
        for r in try SearchOps(repo: repo).search(q) {
            print("\(r.oid?.hex.prefix(7) ?? "") \(r.title)")
        }
    }
}

struct FindChange: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "find-change", abstract: "Find content in history")
    @Option(name: .long) var repo: String?
    @Argument var query: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "FindChange")
        var cmd = try Search.parseAsRoot(["--repo", repo ?? ".", "--content", query])
        try cmd.run()
    }
}

struct FindBranch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "find-branch", abstract: "Find branches/tags")
    @Option(name: .long) var repo: String?
    @Argument var query: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "FindBranch")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let q = SearchOps.Query(text: query, kinds: [.branch], limit: 100)
        for r in try SearchOps(repo: repo).search(q) { print(r.title) }
    }
}

struct FindHistory: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "find-history", abstract: "History of a path")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "FindHistory")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for c in try SearchOps(repo: repo).historyOf(path: path) {
            print("\(c.oid.hex.prefix(7)) \(c.summary)")
        }
    }
}



struct Fsck: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Verify repository integrity")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Fsck")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let issues = try MaintenanceOps(repo: repo).fsck()
        if wantsJSON(json) { printJSON(issues); return }
        if issues.isEmpty { print("no issues found") }
        for i in issues { print("\(i.severity.rawValue): \(i.message)") }
        if issues.contains(where: { $0.severity == .error }) {
            throw SpacesError.internalInconsistency("fsck found errors")
        }
    }
}

struct GC: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Garbage-collect unreachable objects")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var pruneDays: Int = 0
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "GC")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let result = try MaintenanceOps(repo: repo).gc(pruneDays: pruneDays)
        print("gc complete: pruned \(result.pruned), \(result.reachable) reachable objects kept")
    }
}

struct Prune: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Prune unreachable objects")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var dryRun: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Prune")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if dryRun {
            let reachable = try MaintenanceOps(repo: repo).reachableSet()
            let all = try repo.objects.allIDs()
            print("\(all.count - reachable.count) unreachable object(s)")
        } else {
            var cmd = GC()
            cmd.repo = repo
            try cmd.run()
        }
    }
}

struct Compact: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Compact the journal and indexes")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Compact")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try repo.journal.compact()
        try MaintenanceOps(repo: repo).rebuildIndex()
        print("compacted")
    }
}

struct Optimize: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Optimize repository (gc + rebuild index)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Optimize")
        var gc = try GC.parseAsRoot(["--repo", repo ?? "."])
        try gc.run()
        var ri = try RebuildIndex.parseAsRoot(["--repo", repo ?? "."])
        try ri.run()
    }
}

struct Repack: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repack objects (no-op for loose store; runs gc)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Repack")
        var cmd = try GC.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}

struct Count: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Count objects")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Count")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let c = try MaintenanceOps(repo: repo).countObjects()
        if wantsJSON(json) {
            let obj: [String: Any] = ["blobs": c.blobs, "trees": c.trees, "commits": c.commits,
                                      "tags": c.tags, "snapshots": c.snapshots, "total": c.total]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: d, encoding: .utf8) { print(str) }
            return
        }
        print("blobs:     \(c.blobs)")
        print("trees:     \(c.trees)")
        print("commits:   \(c.commits)")
        print("tags:      \(c.tags)")
        print("snapshots: \(c.snapshots)")
        print("total:     \(c.total)")
    }
}

struct CountObjects: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "count-objects", abstract: "Count objects (alias)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "CountObjects")
        var cmd = try Count.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}

struct Storage: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Storage usage")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Storage")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let s = try MaintenanceOps(repo: repo).storage()
        print("objects:   \(s.objects) bytes")
        print("index:     \(s.index) bytes")
        print("metadata:  \(s.total) bytes total (\(s.fileCount) files)")
    }
}

struct Integrity: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Integrity check (fsck alias)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Integrity")
        var cmd = try Fsck.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}

struct Diagnostics: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run diagnostics")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Diagnostics")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let diags = try MaintenanceOps(repo: repo).diagnose()
        if wantsJSON(json) { printJSON(diags); return }
        for d in diags {
            print("[\(d.level.rawValue)] \(d.name): \(d.detail)")
        }
    }
}

struct Health: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repository health score")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Health")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let (score, issues) = try MaintenanceOps(repo: repo).healthScore()
        print("health: \(score)/100")
        for i in issues { print("  [\(i.level.rawValue)] \(i.name): \(i.detail)") }
    }
}

struct RepairIndex: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "repair-index", abstract: "Rebuild the index")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RepairIndex")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let n = try MaintenanceOps(repo: repo).rebuildIndex()
        print("index rebuilt: \(n) entries")
    }
}

struct RebuildIndex: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Rebuild the index (alias)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "RebuildIndex")
        var cmd = try RepairIndex.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Doctor: full diagnostic + repair suggestions")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Doctor")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let diags = try MaintenanceOps(repo: repo).diagnose()
        var errors = 0, warnings = 0
        for d in diags {
            switch d.level {
            case .error: errors += 1; print("ERROR \(d.name): \(d.detail)")
            case .warning: warnings += 1; print("warn  \(d.name): \(d.detail)")
            case .ok: print("ok    \(d.name): \(d.detail)")
            }
        }
        print("\n\(errors) error(s), \(warnings) warning(s)")
        if errors > 0 {
            print("run 'spaces repair' to attempt fixes")
            throw SpacesError.internalInconsistency("doctor found errors")
        }
    }
}

struct Maintenance: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Maintenance recommendations")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Maintenance")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let counts = try MaintenanceOps(repo: repo).countObjects()
        let reachable = try MaintenanceOps(repo: repo).reachableSet()
        print("objects: \(counts.total) (\(reachable.count) reachable)")
        if counts.total - reachable.count > 100 {
            print("recommendation: run 'spaces gc' to prune \(counts.total - reachable.count) unreachable objects")
        } else {
            print("repository is well-maintained")
        }
    }
}



struct LsFiles: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ls-files", abstract: "List tracked files")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var stage: Bool = false
    @Flag(name: .long) var others: Bool = false
    @Flag(name: .long) var deleted: Bool = false
    @Flag(name: .long) var modified: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "LsFiles")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if stage {
            for p in try repo.trackedPaths() { print(p) }
            return
        }
        let report = try WorktreeScanner(repo: repo).status()
        if others {
            for s in report.untrackedFiles { print(s.path) }
        } else if deleted || modified {
            for s in report.entries where (deleted && s.worktreeStatus == .deleted) || (modified && s.worktreeStatus == .modified) {
                print(s.path)
            }
        } else {
            for p in try repo.trackedPaths() { print(p) }
        }
    }
}

struct LsTree: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ls-tree", abstract: "List tree contents")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @Argument var path: String = ""
    @Flag(name: .long) var recursive: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "LsTree")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try repo.resolveRevision(rev)
        var flat = try TreeBuilder.flattenTree(repo: repo, treeOID: repo.commitObject(oid).tree)
        if !path.isEmpty {
            flat = flat.filter { $0.key == path || $0.key.hasPrefix(path + "/") }
        }
        for (p, e) in flat.sorted(by: { $0.key < $1.key }) {
            print("\(e.mode.rawValue) \(e.oid.hex) \(p)")
        }
    }
}

struct CatFile: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cat-file", abstract: "Print object contents")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var type: Bool = false
    @Flag(name: .long) var size: Bool = false
    @Argument var object: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "CatFile")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try ObjectID.resolve(object, in: repo.objects)
        let stored = try repo.objects.read(oid)
        if type { print(stored.type.rawValue); return }
        if size { print(stored.payload.count); return }
        if stored.type == .blob {
            FileHandle.standardOutput.write(stored.payload)
        } else {
            print(String(decoding: stored.payload, as: UTF8.self), terminator: "")
        }
    }
}

struct Explain: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Explain a revision or object")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Explain")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        print("commit: \(oid.hex)")
        print("tree:   \(commit.tree.hex)")
        print("parents: \(commit.parents.map { $0.hex.prefix(12) }.joined(separator: " "))")
        print("author: \(commit.author.name) <\(commit.author.email)> @\(commit.author.timestamp)")
        print("committer: \(commit.committer.name) <\(commit.committer.email)> @\(commit.committer.timestamp)")
        print("message: \(commit.summary)")
        if !commit.metadata.trailers.isEmpty {
            print("trailers:")
            for (k, v) in commit.metadata.trailers.sorted(by: { $0.key < $1.key }) {
                print("  \(k): \(v)")
            }
        }
    }
}

struct Impact: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Change impact of a commit")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Impact")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let result = try HistoryOps(repo: repo).show(rev)
        print("commit \(result.info.oid.hex.prefix(12)): \(result.info.summary)")
        print("files changed: \(result.diffStat.files)")
        print("lines: +\(result.diffStat.added) -\(result.diffStat.removed)")
    }
}

struct Compare: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Compare two revisions")
    @Option(name: .long) var repo: String?
    @Argument var a: String
    @Argument var b: String = "HEAD"
    @Flag(name: .long) var stat: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Compare")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let diffs = try DiffOps(repo: repo).commitDiff(a, b)
        var adds = 0, dels = 0
        for d in diffs {
            adds += d.added; dels += d.removed
            if !stat { print(DiffOps.renderPatch([d]), terminator: "") }
            else { print(" \(d.added)+ \(d.removed)- \(d.newPath)") }
        }
        if stat { print(" \(diffs.count) file(s), +\(adds) -\(dels)") }
    }
}

struct Benchmark: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Benchmark repository operations")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Benchmark")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        var timings: [(String, Double)] = []
        func time(_ name: String, _ body: () throws -> Void) {
            let start = Date()
            try? body()
            timings.append((name, Date().timeIntervalSince(start) * 1000))
        }
        time("status") { _ = try WorktreeScanner(repo: repo).status() }
        time("log-100") { _ = try HistoryOps(repo: repo).log(limit: 100) }
        time("fsck") { _ = try MaintenanceOps(repo: repo).fsck() }
        time("storage") { _ = try MaintenanceOps(repo: repo).storage() }
        for (name, ms) in timings { print("\(name): \(String(format: "%.1f", ms)) ms") }
    }
}

struct Trace: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Trace an operation (timing + object counts)")
    @Option(name: .long) var repo: String?
    @Argument var operation: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Trace")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let api = SpacesAPI(repo: repo)
        let start = Date()
        let countsBefore = try api.countObjects().total
        let summary: String
        switch operation {
        case "status":
            let report = try api.status()
            summary = "branch \(report.branch ?? "detached"), \(report.staged.count) staged, \(report.unstaged.count) unstaged, \(report.untrackedFiles.count) untracked, clean: \(report.isClean)"
        case "log":
            let commits = try api.log(limit: 100)
            summary = "\(commits.count) commit(s), latest: \(commits.first?.summary ?? "none")"
        case "fsck":
            let issues = try api.fsck()
            summary = "\(issues.count) issue(s)"
        case "storage":
            let storage = try api.storage()
            summary = "\(storage.total) bytes total, \(storage.fileCount) file(s)"
        case "search":
            let results = try api.search(SearchOps.Query(text: "a", limit: 50))
            summary = "\(results.count) result(s)"
        default:
            throw SpacesError.invalidArgument("unknown operation: \(operation) (status, log, fsck, storage, search)")
        }
        let elapsedMs = Date().timeIntervalSince(start) * 1000
        let countsAfter = try api.countObjects().total
        print("trace: \(operation)")
        print("elapsed: \(String(format: "%.1f", elapsedMs)) ms")
        print("objects before: \(countsBefore), after: \(countsAfter) (delta \(countsAfter - countsBefore))")
        print("result: \(summary)")
    }
}

struct Events: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show recent repository events (reflog)")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var limit: Int = 50
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Events")
        var cmd = try Reflog.parseAsRoot(["--repo", repo ?? ".", "--limit", String(limit)])
        try cmd.run()
    }
}



struct Security: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Security tools",
        subcommands: [Scan.self, Secrets.self, Signatures.self, Identities.self,
                      Credentials.self, Permissions.self, Audit.self])
}

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Scan files for secrets")
    @Option(name: .long) var repo: String?
    @Argument var path: String = "."
    @Flag(name: .long) var staged: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Scan")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        
        let patterns: [(String, String)] = [
            ("aws-access-key", #"AKIA[0-9A-Z]{16}"#),
            ("private-key", #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#),
            ("generic-secret", #"(?i)(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][^'\"]{8,}"#),
            ("github-token", #"gh[pousr]_[A-Za-z0-9]{36,}"#),
            ("slack-token", #"xox[baprs]-[A-Za-z0-9-]{10,}"#),
        ]
        var findings = 0
        let index = try repo.index()
        for (p, e) in index.entries.sorted(by: { $0.key < $1.key }) {
            guard let data = try? repo.blobData(e.oid),
                  let text = String(data: data, encoding: .utf8),
                  !DiffEngine.isBinary(data) else { continue }
            for (name, pat) in patterns {
                if let re = try? NSRegularExpression(pattern: pat),
                   re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    print("\(p): possible \(name)")
                    findings += 1
                }
            }
        }
        if findings == 0 { print("no secrets found in \(index.entries.count) tracked file(s)") }
        else { throw SpacesError.invalidArgument("\(findings) potential secret(s) found") }
    }
}

struct Secrets: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Alias for scan")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Secrets")
        var cmd = try Scan.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}

struct Signatures: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List/sign commits")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @Flag(name: .long) var verify: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Signatures")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        if let sig = commit.metadata.signature {
            if verify {
                let ok = try SigningOps(repo: repo).verify(
                    type: .commit, object: oid.hex + commit.message, signature: sig)
                print(ok ? "signature valid" : "signature INVALID")
            } else {
                print("signed: \(sig.prefix(16))...")
            }
        } else {
            print("commit is unsigned")
        }
    }
}

struct Sign: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Sign the HEAD commit")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Sign")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        guard let head = try repo.refs.headOID(objects: repo.objects) else {
            throw SpacesError.branchNotFound("HEAD")
        }
        let commit = try repo.commitObject(head)
        let sig = try SigningOps(repo: repo).sign(type: .commit,
                                                  object: head.hex + commit.message)
        var meta = commit.metadata
        meta.signature = sig
        let payload = CommitPayload(tree: commit.tree, parents: commit.parents,
                                    author: commit.author, committer: commit.committer,
                                    message: commit.message, metadata: meta)
        let newOID = try repo.objects.write(.commit, value: payload)
        if let sym = try repo.refs.symbolicHEAD() {
            _ = try repo.refs.updateRef(sym, to: newOID)
        }
        try repo.appendReflog(refName: "HEAD", old: head, new: newOID,
                              message: "sign commit")
        print("signed commit: \(newOID.hex.prefix(12))")
    }
}

struct VerifySignature: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify-signature", abstract: "Verify commit signature")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "VerifySignature")
        var cmd = try Signatures.parseAsRoot(["--repo", repo ?? ".", rev, "--verify"])
        try cmd.run()
    }
}

struct Identities: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show configured identities")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Identities")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ident = repo.identity()
        print("name:  \(ident.name)")
        print("email: \(ident.email)")
        print("configured: \(repo.config.user != nil)")
    }
}

struct Credentials: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Credential storage",
        subcommands: [CredList.self, CredSet.self, CredDelete.self])
}

struct CredList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List stored credentials (hosts only)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "CredList")
        #if os(macOS)
        let store = KeychainCredentialStore()
        #else
        let store = FileCredentialStore()
        #endif
        let identities = try store.listCredentialIdentities()
        for identity in identities {
            if let username = identity.username {
                print("\(identity.host) (\(username))")
            } else {
                print(identity.host)
            }
        }
        if identities.isEmpty { print("no stored credentials") }
    }
}

struct CredSet: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Store a credential")
    @Option(name: .long) var repo: String?
    @Argument var host: String
    @Option(name: .long) var token: String?
    @Option(name: .long) var username: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "CredSet")
        #if os(macOS)
        let store = KeychainCredentialStore()
        #else
        let store = FileCredentialStore()
        #endif
        var creds = SpacesEngine.Credentials()
        creds.token = token
        creds.username = username
        try store.save(creds, for: host)
        print("credential stored for \(host)")
    }
}

struct CredDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a credential")
    @Option(name: .long) var repo: String?
    @Argument var host: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "CredDelete")
        #if os(macOS)
        let store = KeychainCredentialStore()
        #else
        let store = FileCredentialStore()
        #endif
        try store.delete(host: host)
        print("credential deleted for \(host)")
    }
}

struct Permissions: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show repository file permissions summary")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Permissions")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        var worldWritable = 0, executables = 0
        for (p, e) in try repo.index().entries {
            if e.mode == .executable { executables += 1 }
            let url = try repo.worktreeURL(forRelativePath: p)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let perms = attrs[.posixPermissions] as? Int, (perms & 0o002) != 0 {
                worldWritable += 1
                print("world-writable: \(p)")
            }
        }
        print("\(executables) executable file(s), \(worldWritable) world-writable file(s)")
    }
}

struct Audit: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Audit log (reflog + journal)")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var limit: Int = 100
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Audit")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for e in try repo.readReflog(limit: limit) {
            print("\(e.timestamp) \(e.ident): \(e.message)")
        }
        if repo.journal.hasUnfinishedTransactions {
            print("WARNING: unfinished transactions in journal")
        }
    }
}



struct ImportGit: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "import-git", abstract: "Import a Git repository")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @Flag(name: .long) var dryRun: Bool = false
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "ImportGit")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let report = try GitMigration(repo: repo).importGit(at: path, dryRun: dryRun)
        if wantsJSON(json) { printJSON(report); return }
        print("imported \(report.commits) commits, \(report.objectsWritten) objects")
        print("branches: \(report.branches.joined(separator: ", "))")
        print("tags: \(report.tags.joined(separator: ", "))")
        print("gitlinks: \(report.gitlinks.count)")
        for entry in report.gitlinks { print("  gitlink: \(entry.path) -> \(entry.target)") }
        print("gpg signatures: \(report.gpgSignatures.count)")
        print("notes imported: \(report.notesImported)")
        if !report.notesRefs.isEmpty { print("notes refs: \(report.notesRefs.joined(separator: ", "))") }
        print("lfs pointers: \(report.lfsPointers.count)")
        for entry in report.lfsPointers {
            print("  lfs: \(entry.path) \(entry.oid) \(entry.size) bytes\(entry.objectImported ? "" : " (object not imported)")")
        }
        for w in report.warnings { print("warning: \(w)") }
    }
}

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Import (alias for import git)",
        subcommands: [ImportGitCmd.self])
}

struct ImportGitCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "git", abstract: "Import a Git repository")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "ImportGitCmd")
        var cmd = try ImportGit.parseAsRoot((["--repo", repo ?? ".", path]))
        try cmd.run()
    }
}

struct ExportGit: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export-git", abstract: "Export to Git format")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "ExportGit")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let report = try GitMigration(repo: repo).exportGit(to: path)
        if wantsJSON(json) { printJSON(report); return }
        print("exported to \(report.gitDir): \(report.objectsWritten) objects, \(report.refsWritten.count) refs")
        if report.updatedExisting { print("updated existing git repository") }
        if !report.hooksExported.isEmpty { print("hooks: \(report.hooksExported.joined(separator: ", "))") }
        if !report.reflogsExported.isEmpty { print("reflogs: \(report.reflogsExported.joined(separator: ", "))") }
        if !report.configKeysWritten.isEmpty { print("config: \(report.configKeysWritten.joined(separator: ", "))") }
        for w in report.warnings { print("warning: \(w)") }
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export (alias)",
        subcommands: [ExportGitCmd.self])
}

struct ExportGitCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "git", abstract: "Export to Git format")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "ExportGitCmd")
        var cmd = try ExportGit.parseAsRoot((["--repo", repo ?? ".", path]))
        try cmd.run()
    }
}








struct BundleCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a bundle file")
    @Option(name: .long) var repo: String?
    @Argument var output: String
    @Argument var refs: [String] = []
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "BundleCreate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try BundleOps.create(repo: repo, output: output, refNames: refs)
        print("bundle written to \(output)")
    }
}

struct BundleVerify: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Verify a bundle")
    @Argument var path: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "BundleVerify")
        let report = try BundleOps.verify(path: path)
        print("bundle OK: \(report.objectCount) objects, \(report.refs.count) refs")
    }
}

struct BundleInspect: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a bundle")
    @Argument var path: String
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "BundleInspect")
        let report = try BundleOps.inspect(path: path)
        if wantsJSON(json) { printJSON(report); return }
        print("objects: \(report.objectCount)")
        print("refs:")
        for (name, oid) in report.refs.sorted(by: { $0.key < $1.key }) {
            print("  \(name) \(oid)")
        }
        print("created: \(report.created)")
    }
}

struct Bundle: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Bundle operations",
        subcommands: [BundleCreate.self, BundleVerify.self, BundleInspect.self])
}

struct Archive: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a tar archive of a revision")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @Argument var output: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Archive")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try ArchiveOps.create(repo: repo, rev: rev, output: output)
        print("archive written to \(output)")
    }
}



struct Worktree: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Worktree operations",
        subcommands: [WorktreeAdd.self, WorktreeRemove.self, WorktreeList.self])
}

struct Worktrees: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List worktrees")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Worktrees")
        var cmd = WorktreeList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct WorktreeList: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List worktrees")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorktreeList")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for w in try WorktreeOps(repo: repo).list() {
            print("\(w.isMain ? "*" : " ") \(w.name)\t\(w.path)\t\(w.head)")
        }
    }
}

struct WorktreeAdd: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Add a worktree")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @Option(name: .long) var branch: String?
    @Option(name: .long) var newBranch: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorktreeAdd")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let wt = try WorktreeOps(repo: repo).add(path: path, branch: branch, newBranch: newBranch)
        print("worktree added: \(wt.path) (\(wt.head))")
    }
}

struct WorktreeRemove: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a worktree")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorktreeRemove")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try WorktreeOps(repo: repo).remove(name)
        print("worktree removed: \(name)")
    }
}

struct Workspace: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Workspace operations (alias for worktree)",
        subcommands: [WorkspaceCreate.self, WorkspaceSwitch.self, WorkspaceRemove.self, WorkspaceList.self])
}

struct Workspaces: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List workspaces")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "Workspaces")
        var cmd = WorkspaceList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct WorkspaceCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a workspace (worktree)")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @Option(name: .long) var branch: String?
    @Option(name: .long) var newBranch: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorkspaceCreate")
        var args = ["--repo", repo ?? ".", path]
        if let b = branch { args += ["--branch", b] }
        if let nb = newBranch { args += ["--new-branch", nb] }
        var cmd = try WorktreeAdd.parseAsRoot(args)
        try cmd.run()
    }
}

struct WorkspaceSwitch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Switch workspace")
    @Option(name: .long) var repo: String?
    @Argument var target: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorkspaceSwitch")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let resolved = try WorktreeOps(repo: repo).resolve(target)
        print("workspace: \(resolved.name)")
        print("path: \(resolved.path)")
        print("branch: \(resolved.branch ?? "(detached)")")
        print("HEAD: \(resolved.headOID)")
        print("cd \(resolved.path)")
    }
}

struct WorkspaceRemove: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a workspace")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorkspaceRemove")
        var cmd = try WorktreeRemove.parseAsRoot(["--repo", repo ?? ".", name])
        try cmd.run()
    }
}

struct WorkspaceList: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List workspaces")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        SpacesOutput.apply(global, command: "WorkspaceList")
        var cmd = try WorktreeList.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}
