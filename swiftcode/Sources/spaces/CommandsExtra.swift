import ArgumentParser
import Foundation
import SpacesEngine



struct Hooks: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repository hooks",
        subcommands: [HooksList.self, HookInstall.self, HookRemove.self, HookRun.self])
}

struct HooksList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List installed hooks")
    @Option(name: .long) var repo: String?
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let dir = repo.metaURL.appendingPathComponent("hooks")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            print("no hooks installed"); return
        }
        for f in files.sorted() {
            let url = dir.appendingPathComponent(f)
            let exec = FileManager.default.isExecutableFile(atPath: url.path) ? "exec" : "----"
            print("\(exec) \(f)")
        }
        if files.isEmpty { print("no hooks installed") }
    }
}

struct HookInstall: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install a hook")
    @Option(name: .long) var repo: String?
    @Argument var event: String
    @Argument var script: String
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let valid = ["pre-commit", "post-commit", "pre-push", "post-push",
                     "pre-merge", "post-merge", "pre-rebase", "post-checkout",
                     "post-rewrite", "pre-auto-gc"]
        guard valid.contains(event) else {
            throw SpacesError.invalidArgument("unknown hook event: \(event)")
        }
        let dir = repo.metaURL.appendingPathComponent("hooks")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(event)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: script), to: dest)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        print("installed \(event) hook")
    }
}

struct HookRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove a hook")
    @Option(name: .long) var repo: String?
    @Argument var event: String
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let dest = repo.metaURL.appendingPathComponent("hooks").appendingPathComponent(event)
        try? FileManager.default.removeItem(at: dest)
        print("removed \(event) hook")
    }
}

struct HookRun: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run a hook manually")
    @Option(name: .long) var repo: String?
    @Argument var event: String
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let result = try StagingOps(repo: repo).runHook(
            StagingOps.HookEvent(rawValue: event) ?? .preCommit, input: "")
        if let r = result { print("hook exited \(r.code)") }
        else { print("no hook installed for \(event)") }
    }
}

struct HookInstallCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hook-install", abstract: "Install hook (alias)")
    @Option(name: .long) var repo: String?
    @Argument var event: String
    @Argument var script: String
    func run() throws {
        var cmd = try HookInstall.parseAsRoot(["--repo", repo ?? ".", event, script])
        try cmd.run()
    }
}

struct HookRemoveCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hook-remove", abstract: "Remove hook (alias)")
    @Option(name: .long) var repo: String?
    @Argument var event: String
    func run() throws {
        var cmd = try HookRemove.parseAsRoot(["--repo", repo ?? ".", event])
        try cmd.run()
    }
}



struct Lfs: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Large File Storage",
        subcommands: [LfsTrack.self, LfsUntrack.self, LfsStatus.self, LfsFetch.self,
                      LfsPush.self, LfsPull.self, LfsPrune.self])
}

struct LfsTrack: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "track", abstract: "Track LFS patterns")
    @Option(name: .long) var repo: String?
    @Argument var patterns: [String]
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let url = repo.worktreeURL.appendingPathComponent(RepositoryFormat.lfsAttributesName)
        var existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        for p in patterns {
            existing += "\(p) filter=lfs diff=lfs merge=lfs -text\n"
        }
        try existing.write(to: url, atomically: true, encoding: .utf8)
        print("tracking: \(patterns.joined(separator: ", "))")
    }
}

struct LfsUntrack: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "untrack", abstract: "Stop tracking LFS patterns")
    @Option(name: .long) var repo: String?
    @Argument var patterns: [String]
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let url = repo.worktreeURL.appendingPathComponent(RepositoryFormat.lfsAttributesName)
        guard var text = try? String(contentsOf: url, encoding: .utf8) else { return }
        for p in patterns {
            text = text.components(separatedBy: "\n")
                .filter { !$0.hasPrefix(p + " ") && !$0.hasPrefix(p + "\t") }
                .joined(separator: "\n")
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        print("untracked: \(patterns.joined(separator: ", "))")
    }
}

struct LfsStatus: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "LFS status")
    @Option(name: .long) var repo: String?
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let lfsDir = repo.metaURL.appendingPathComponent("lfs/objects")
        var count = 0, bytes: Int64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(atPath: lfsDir.path) {
            for f in files {
                let fp = lfsDir.appendingPathComponent(f)
                if let s = try? FileManager.default.attributesOfItem(atPath: fp.path)[.size] as? Int64 {
                    bytes += s; count += 1
                }
            }
        }
        let enabled = repo.config.lfs.enabled
        print("lfs: \(enabled ? "enabled" : "disabled"), threshold \(repo.config.lfs.thresholdBytes) bytes")
        print("local lfs objects: \(count) (\(bytes) bytes)")
        print("note: remote LFS transfer requires a Spaces server")
    }
}

struct LfsFetch: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "fetch", abstract: "Fetch LFS objects")
    @Option(name: .long) var repo: String?
    func run() throws {
        print("LFS fetch requires a Spaces LFS server (not yet available); local objects are already stored")
    }
}

struct LfsPush: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "push", abstract: "Push LFS objects")
    @Option(name: .long) var repo: String?
    func run() throws {
        print("LFS push requires a Spaces LFS server (not yet available)")
    }
}

struct LfsPull: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pull", abstract: "Pull LFS objects")
    @Option(name: .long) var repo: String?
    func run() throws {
        print("LFS pull requires a Spaces LFS server (not yet available)")
    }
}

struct LfsPrune: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "prune", abstract: "Prune local LFS cache")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var dryRun: Bool = false
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let lfsDir = repo.metaURL.appendingPathComponent("lfs/objects")
        var removed = 0
        if let files = try? FileManager.default.contentsOfDirectory(atPath: lfsDir.path) {
            for f in files {
                let fp = lfsDir.appendingPathComponent(f)
                if dryRun { print("would remove \(f)") }
                else { try? FileManager.default.removeItem(at: fp); removed += 1 }
            }
        }
        if !dryRun { print("pruned \(removed) lfs object(s)") }
    }
}



struct Notes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Commit notes",
        subcommands: [NotesAdd.self, NotesList.self, NotesShow.self])
}

struct NotesAdd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a note to a commit")
    @Option(name: .long) var repo: String?
    @Argument var rev: String
    @Option(name: .shortAndLong) var message: String
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try repo.resolveRevision(rev)
        let notesURL = repo.metaURL.appendingPathComponent("notes.json")
        var notes: [String: [String]] = [:]
        if let data = try? Data(contentsOf: notesURL),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            notes = decoded
        }
        notes[oid.hex, default: []].append(message)
        try JSONEncoder().encode(notes).write(to: notesURL)
        print("note added to \(oid.hex.prefix(7))")
    }
}

struct NotesList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List notes")
    @Option(name: .long) var repo: String?
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let notesURL = repo.metaURL.appendingPathComponent("notes.json")
        guard let data = try? Data(contentsOf: notesURL),
              let notes = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            print("no notes"); return
        }
        for (oid, msgs) in notes.sorted(by: { $0.key < $1.key }) {
            for m in msgs { print("\(oid.prefix(7)): \(m)") }
        }
    }
}

struct NotesShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show notes for a commit")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    func run() throws {
        var cmd = try NotesList.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}

struct Annotate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Alias for blame")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    func run() throws {
        var cmd = try Blame.parseAsRoot(["--repo", repo ?? ".", path])
        try cmd.run()
    }
}



struct Extensions: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Extension management",
        subcommands: [ExtensionsList.self, ExtensionInstall.self, ExtensionRemove.self])
}

struct ExtensionsList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List extensions")
    @Option(name: .long) var repo: String?
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for (name, enabled) in repo.config.extensions.sorted(by: { $0.key < $1.key }) {
            print("\(enabled ? "on " : "off") \(name)")
        }
        if repo.config.extensions.isEmpty { print("no extensions") }
    }
}

struct ExtensionInstall: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Enable an extension")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        repo.config.extensions[name] = true
        try repo.saveConfig()
        print("enabled extension \(name)")
    }
}

struct ExtensionRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Disable an extension")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    func run() throws {
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        repo.config.extensions[name] = false
        try repo.saveConfig()
        print("disabled extension \(name)")
    }
}



struct MergeStrategyList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "merge-strategies", abstract: "List merge strategies")
    @Option(name: .long) var repo: String?
    func run() throws {
        var cmd = try MergeStrategy.parseAsRoot(["--repo", repo ?? "."])
        try cmd.run()
    }
}
