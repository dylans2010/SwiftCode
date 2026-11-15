import ArgumentParser
import Foundation
import SpacesEngine



struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a new Spaces repository")
    @Argument(help: "Directory to initialize") var path: String = "."
    @Option(name: .long, help: "Default branch name") var branch: String = "main"
    @Option(name: .long, help: "Author name") var name: String?
    @Option(name: .long, help: "Author email") var email: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Init")
        var user: SpacesConfig.User? = nil
        if let n = name, let e = email { user = SpacesConfig.User(name: n, email: e) }
        let repo = try Repository.create(at: URL(fileURLWithPath: path),
                                         defaultBranch: branch, user: user)
        print("Initialized empty Spaces repository in \(repo.worktreeURL.path)/.spaces/")
    }
}

struct Clone: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Clone a Spaces repository")
    @Argument(help: "Remote URL or local path") var url: String
    @Argument(help: "Destination directory") var directory: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Clone")
        let dest = directory.map { URL(fileURLWithPath: $0) }
        let repo = try CloneOps.clone(url: url, into: dest)
        print("Cloned into \(repo.worktreeURL.path)")
    }
}

struct Open: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Open a Spaces repository")
    @Argument(help: "Path") var path: String = "."
    @Option(name: .long) var repo: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Open")
        let repo = try Repository.open(at: URL(fileURLWithPath: path))
        let api = SpacesAPI(repo: repo)
        let info = try api.info()
        print("Repository: \(info.path)")
        print("Format: v\(info.formatVersion) · Branch: \(info.branch ?? "detached")")
        print("Objects: \(info.objectCount) · Storage: \(info.storageBytes) bytes")
    }
}

struct Discover: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Discover the repository containing a path")
    @Argument(help: "Path") var path: String = "."
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Discover")
        guard let root = RepositoryFormat.discover(from: URL(fileURLWithPath: path)) else {
            throw SpacesError.notARepository(path)
        }
        print(root.path)
    }
}

struct Inspect: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect repository metadata")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Inspect")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let api = SpacesAPI(repo: repo)
        let info = try api.info()
        printJSON(info)
        FileHandle.standardError.write("Config:\n".data(using: .utf8)!)
        FileHandle.standardError.write((try JSONEncoder().encode(repo.config)) )
        FileHandle.standardError.write("\n".data(using: .utf8)!)
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Validate repository structure")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Validate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let problems = repo.validate()
        if problems.isEmpty { print("Repository is valid") }
        else { for p in problems { print("problem: \(p)") }; throw SpacesError.internalInconsistency("validation failed") }
    }
}

struct Repair: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repair repository issues")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var dryRun: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Repair")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if dryRun {
            for d in try MaintenanceOps(repo: repo).diagnose() where d.level != .ok { print(d) }
            return
        }
        for action in try MaintenanceOps(repo: repo).repair() { print(action) }
    }
}

struct Migrate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Migrate repository format")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Migrate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if repo.config.version > RepositoryFormat.formatVersion {
            throw SpacesError.configError("downgrade not supported")
        }
        repo.config.version = RepositoryFormat.formatVersion
        try repo.saveConfig()
        print("Repository is at format v\(RepositoryFormat.formatVersion)")
    }
}

struct Upgrade: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Upgrade repository format")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Upgrade")
        var cmd = Migrate()
        cmd.repo = repo
        try cmd.run()
    }
}

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Get/set repository configuration")
    @Option(name: .long) var repo: String?
    @Argument(help: "Key (e.g. core.defaultbranch, user.name, remote.origin.url)") var key: String?
    @Argument(help: "Value") var value: String?
    @Flag(name: .long) var list: Bool = false

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Config")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if list || (key == nil && value == nil) {
            print(String(data: try JSONEncoder().encode(repo.config), encoding: .utf8)!)
            return
        }
        guard let key else { throw SpacesError.invalidArgument("key required") }
        let parts = key.split(separator: ".").map(String.init)
        if parts.count == 3, parts[0] == "remote", parts[2] == "url" {
            if let v = value {
                if var remote = repo.config.remotes[parts[1]] {
                    remote.url = v
                    repo.config.remotes[parts[1]] = remote
                } else {
                    repo.config.remotes[parts[1]] = SpacesConfig.RemoteConfig(url: v)
                }
                try repo.saveConfig()
                print("set \(key) = \(v)")
            } else if let remote = repo.config.remotes[parts[1]] {
                print(remote.url)
            } else {
                throw SpacesError.invalidArgument("no such remote: \(parts[1])")
            }
            return
        }
        if parts.count == 2, parts[0] == "remote", let remote = repo.config.remotes[parts[1]] {
            print(remote.url); return
        }
        switch key {
        case "core.defaultbranch": print(repo.config.core.defaultBranch)
        case "user.name": print(repo.config.user?.name ?? "")
        case "user.email": print(repo.config.user?.email ?? "")
        case "init.defaultbranch": print(repo.config.core.defaultBranch)
        default:
            if let v = value {
                switch key {
                case "core.defaultbranch", "init.defaultbranch": repo.config.core.defaultBranch = v
                case "user.name": repo.config.user = SpacesConfig.User(name: v, email: repo.config.user?.email ?? "")
                case "user.email": repo.config.user = SpacesConfig.User(name: repo.config.user?.name ?? "", email: v)
                default: throw SpacesError.invalidArgument("unknown key: \(key)")
                }
                try repo.saveConfig()
                print("set \(key) = \(v)")
            } else {
                throw SpacesError.invalidArgument("unknown key: \(key)")
            }
        }
    }
}

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print Spaces version")
    @OptionGroup var global: GlobalOptions
    func run() throws { try SpacesOutput.apply(global, command: "Version"); print("spaces 1.0.0 (SwiftCode native source control)") }
}

struct Info: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repository information")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Info")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let api = SpacesAPI(repo: repo)
        let info = try api.info()
        print("path:        \(info.path)")
        print("format:      v\(info.formatVersion)")
        print("branch:      \(info.branch ?? "detached")")
        print("head:        \(info.headOID ?? "-")")
        print("objects:     \(info.objectCount)")
        print("storage:     \(info.storageBytes) bytes")
        print("default:     \(info.defaultBranch)")
        print("remotes:     \(repo.config.remotes.keys.sorted().joined(separator: ", "))")
    }
}



struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show working tree status")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var short: Bool = false
    @Flag(name: .long) var branch: Bool = false
    @Flag(name: .long) var json: Bool = false

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Status")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let report = try WorktreeScanner(repo: repo).status()
        if branch {
            print("\(report.branch ?? "HEAD")")
            return
        }
        if wantsJSON(json) {
            printStatus(report, json: true)
        } else if short {
            for s in report.staged { print("\(s.indexStatus?.rawValue.prefix(1) ?? " ") \(s.path)") }
            for s in report.unstaged { print(" \(s.worktreeStatus?.rawValue.prefix(1) ?? " ") \(s.path)") }
            for s in report.untrackedFiles { print("? \(s.path)") }
        } else {
            printStatus(report, json: false)
        }
    }
}

struct Changes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List changed files")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var staged: Bool = false
    @Flag(name: .long) var nameOnly: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Changes")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let report = try WorktreeScanner(repo: repo).status()
        let entries = staged ? report.staged : report.entries.filter { $0.isStaged || $0.isUnstaged }
        if nameOnly {
            for e in entries { print(e.path) }
        } else {
            for e in entries {
                let st = e.indexStatus ?? e.worktreeStatus
                print("\(st?.rawValue ?? "?") \(e.path)")
            }
        }
    }
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Stage files")
    @Option(name: .long) var repo: String?
    @Argument(help: "Path(s) to stage, or . for all") var paths: [String] = ["."]
    @Flag(name: .long) var all: Bool = false

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Add")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StagingOps(repo: repo)
        var staged: [String] = []
        for p in paths {
            staged.append(contentsOf: try ops.add(p, all: all || p == "."))
        }
        for s in staged.sorted() { print("added \(s)") }
    }
}

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove files from index and worktree")
    @Option(name: .long) var repo: String?
    @Argument var paths: [String]
    @Flag(name: .long) var cached: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Remove")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StagingOps(repo: repo)
        for p in paths {
            if cached { try ops.remove(p, cachedOnly: true) }
            else { try ops.remove(p) }
            print("removed \(p)")
        }
    }
}

struct Move: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Move/rename a tracked file")
    @Option(name: .long) var repo: String?
    @Argument var old: String
    @Argument var new: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Move")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try StagingOps(repo: repo).move(old, new)
        print("renamed \(old) -> \(new)")
    }
}

struct Restore: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Restore worktree or index state")
    @Option(name: .long) var repo: String?
    @Argument var paths: [String]
    @Flag(name: .long) var staged: Bool = false
    @Option(name: .long) var source: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Restore")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StagingOps(repo: repo)
        for p in paths {
            if let src = source {
                
                let oid = try repo.resolveRevision(src)
                let commit = try repo.commitObject(oid)
                let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
                guard let e = flat[p] else { throw SpacesError.pathNotFound(p) }
                let data = try repo.blobData(e.oid)
                let url = try repo.worktreeURL(forRelativePath: p)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url)
            } else if staged {
                try ops.unstage(p)
            } else {
                try ops.restoreWorktree(p)
            }
            print("restored \(p)")
        }
    }
}

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Remove untracked files")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var dryRun: Bool = false
    @Flag(name: .long) var force: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Clean")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StagingOps(repo: repo)
        if !force && !dryRun {
            FileHandle.standardError.write("spaces: 'clean' requires --force (or --dry-run to preview)\n".data(using: .utf8)!)
            throw SpacesError.invalidArgument("refusing to delete untracked files without --force")
        }
        let removed = try ops.clean(dryRun: dryRun)
        for r in removed { print("\(dryRun ? "would remove" : "removed") \(r)") }
        if removed.isEmpty { print("nothing to clean") }
    }
}

struct Unstage: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Unstage paths")
    @Option(name: .long) var repo: String?
    @Argument var paths: [String]
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Unstage")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = StagingOps(repo: repo)
        for p in paths { try ops.unstage(p); print("unstaged \(p)") }
    }
}

struct Stage: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Stage paths (alias for add)")
    @Option(name: .long) var repo: String?
    @Argument var paths: [String]
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Stage")
        var cmd = try Add.parseAsRoot((["--repo", repo ?? "."] + paths))
        try cmd.run()
    }
}



struct Commit: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a commit")
    @Option(name: .long) var repo: String?
    @Option(name: .shortAndLong, help: "Commit message") var message: String?
    @Option(name: .long, help: "Read message from file") var file: String?
    @Flag(name: .long) var all: Bool = false
    @Flag(name: .long) var allowEmpty: Bool = false
    @Option(name: .long, help: "Commit author name") var authorName: String?
    @Option(name: .long, help: "Commit author email") var authorEmail: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Commit")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        var msg = message
        if let f = file { msg = try String(contentsOfFile: f, encoding: .utf8) }
        if msg == nil {
            
            if isatty(STDIN_FILENO) == 0 {
                msg = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8)
            }
        }
        guard let msg, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpacesError.invalidArgument("commit message required (-m, -F, or stdin)")
        }
        var trailers: [String: String] = [:]
        if allowEmpty { trailers["allow-empty"] = "true" }
        var author: Signature? = nil
        if let n = authorName, let e = authorEmail {
            author = Signature(name: n, email: e)
        }
        let result = try StagingOps(repo: repo).commit(message: msg, stageAll: all,
                                                        author: author, trailers: trailers)
        print("[\(try repo.refs.currentBranch() ?? "HEAD")] \(result.oid.hex.prefix(7)) \(result.summary)")
        print(" \(result.filesChanged) file(s) changed")
    }
}

struct Amend: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Amend the last commit")
    @Option(name: .long) var repo: String?
    @Option(name: .shortAndLong) var message: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Amend")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let result = try StagingOps(repo: repo).amend(message: message)
        print("[\(try repo.refs.currentBranch() ?? "HEAD")] \(result.oid.hex.prefix(7)) \(result.summary) (amended)")
    }
}

struct Log: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show commit history")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var limit: Int = 50
    @Flag(name: .long) var all: Bool = false
    @Flag(name: .long) var graph: Bool = false
    @Flag(name: .long) var oneline: Bool = false
    @Flag(name: .long) var firstParent: Bool = false
    @Flag(name: .long) var json: Bool = false
    @Argument var path: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Log")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let history = HistoryOps(repo: repo)
        if wantsJSON(json) {
            let infos = try history.log(firstParentOnly: firstParent, limit: limit, all: all)
            var rows: [[String: Any]] = []
            for c in infos {
                rows.append(["oid": c.oid.hex, "summary": c.summary,
                             "author": c.author.name, "email": c.author.email,
                             "timestamp": c.timestamp,
                             "parents": c.parents.map { $0.hex }, "refs": c.refs])
            }
            if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) { print(str) }
            return
        }
        if graph {
            let nodes = try BranchOps(repo: repo).graph(limit: limit)
            for n in nodes {
                let lane = String(repeating: " ", count: n.lane * 2) + "*"
                let refs = n.refs.isEmpty ? "" : " (\(n.refs.joined(separator: ", ")))"
                print("\(lane) \(n.oid.hex.prefix(7)) \(n.summary)\(refs)")
            }
            return
        }
        let commits = try history.log(firstParentOnly: firstParent, limit: limit, all: all)
        for c in commits {
            if oneline {
                let refs = c.refs.isEmpty ? "" : " (\(c.refs.joined(separator: ", ")))"
                print("\(c.oid.hex.prefix(7))\(refs) \(c.summary)")
            } else {
                print("commit \(c.oid.hex)")
                for r in c.refs { print("  \(r)") }
                print("Author: \(c.author.name) <\(c.author.email)> \(c.author.timestamp)")
                print("")
                print(c.message)
                print("")
            }
        }
    }
}

struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show a commit")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @Flag(name: .long) var stat: Bool = false
    @Flag(name: .long) var nameOnly: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Show")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let result = try HistoryOps(repo: repo).show(rev)
        let c = result.info
        print("commit \(c.oid.hex)")
        for r in c.refs { print("  \(r)") }
        print("Author: \(c.author.name) <\(c.author.email)>")
        print("Date:   \(c.timestamp)")
        print("")
        print(c.message)
        if !stat && !nameOnly {
            print("")
            print(result.patch)
        } else {
            print("\n \(result.diffStat.files) file(s) changed, +\(result.diffStat.added) -\(result.diffStat.removed)")
        }
    }
}

struct Describe: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Describe HEAD relative to nearest tag")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Describe")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        print(try HistoryOps(repo: repo).describe())
    }
}

struct Diff: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show differences")
    @Option(name: .long) var repo: String?
    @Argument var from: String?
    @Argument var to: String?
    @Flag(name: .long) var staged: Bool = false
    @Flag(name: .long) var cached: Bool = false
    @Flag(name: .long) var stat: Bool = false
    @Flag(name: .long) var nameOnly: Bool = false
    @Option(name: .long) var path: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Diff")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let ops = DiffOps(repo: repo)
        let diffs: [DiffOps.FileDiff]
        if let f = from {
            diffs = try ops.commitDiff(f, to ?? "HEAD")
        } else {
            diffs = try ops.workingDiff(stagedOnly: staged || cached)
        }
        let filtered = path.map { p in diffs.filter { $0.newPath == p || $0.oldPath == p } } ?? diffs
        if stat {
            var adds = 0, dels = 0
            for d in filtered { adds += d.added; dels += d.removed
                print(" \(d.added)+ \(d.removed)- \(d.newPath)") }
            print(" \(filtered.count) file(s) changed, +\(adds) -\(dels)")
            return
        }
        if nameOnly {
            for d in filtered { print(d.newPath) }
            return
        }
        print(DiffOps.renderPatch(filtered))
    }
}

struct Patch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate a patch")
    @Option(name: .long) var repo: String?
    @Argument var from: String
    @Argument var to: String = "HEAD"
    @Argument(help: "Output file") var output: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Patch")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let diffs = try DiffOps(repo: repo).commitDiff(from, to)
        let patch = DiffOps.renderPatch(diffs)
        if let out = output {
            try patch.write(toFile: out, atomically: true, encoding: .utf8)
            print("wrote \(out)")
        } else {
            print(patch, terminator: "")
        }
    }
}



struct Branch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Branch operations",
        subcommands: [BranchCreate.self, BranchDelete.self, BranchRename.self, BranchList.self])
}

struct BranchCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a branch")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @Argument var startPoint: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchCreate")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try BranchOps(repo: repo).create(name, at: startPoint)
        print("created branch \(name) at \(oid.hex.prefix(7))")
    }
}

struct BranchDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a branch (recoverable)")
    @Option(name: .long) var repo: String?
    @Argument var name: String
    @Flag(name: .long) var force: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchDelete")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try BranchOps(repo: repo).delete(name, force: force)
        print("deleted branch \(name) (archived for recovery)")
    }
}

struct BranchRename: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rename", abstract: "Rename a branch")
    @Option(name: .long) var repo: String?
    @Argument var old: String
    @Argument var new: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchRename")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try BranchOps(repo: repo).rename(old, to: new)
        print("renamed \(old) -> \(new)")
    }
}

struct BranchList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List branches")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var all: Bool = false
    @Flag(name: .long) var json: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchList")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let branches = try BranchOps(repo: repo).list(includeRemote: all)
        if wantsJSON(json) { printJSON(branches); return }
        for b in branches {
            let marker = b.isCurrent ? "*" : " "
            let remote = b.isRemote ? " (remote)" : ""
            let track = b.upstream.map { " -> \($0)" } ?? ""
            print("\(marker) \(b.name)\(remote)\(track) \(b.oid.hex.prefix(7)) \(b.lastCommit)")
        }
    }
}

struct Branches: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List branches (alias)")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Branches")
        var cmd = BranchList()
        cmd.repo = repo
        try cmd.run()
    }
}

struct Switch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Switch branches or checkout a revision")
    @Option(name: .long) var repo: String?
    @Argument var target: String
    @Flag(name: .long) var create: Bool = false
    @Flag(name: .long) var force: Bool = false
    @Flag(name: .long) var detach: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Switch")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if detach {
            let oid = try repo.resolveRevision(target)
            try BranchOps(repo: repo).switchTo(target, force: force, create: create)
            try repo.setDetachedHead(oid)
            print("detached HEAD at \(oid.hex.prefix(12))")
        } else {
            try BranchOps(repo: repo).switchTo(target, force: force, create: create)
            print("switched to \(target)")
        }
    }
}

struct Checkout: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Checkout (alias for switch)")
    @Option(name: .long) var repo: String?
    @Argument var target: String
    @Flag(name: .long) var create: Bool = false
    @Flag(name: .long) var force: Bool = false
    @Flag(name: .long) var detach: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Checkout")
        var cmd = try Switch.parseAsRoot(["--repo", repo ?? ".", target] + (create ? ["--create"] : []) + (force ? ["--force"] : []) + (detach ? ["--detach"] : []))
        try cmd.run()
    }
}



struct Merge: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Merge a branch into HEAD")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var noFF: Bool = false
    @Flag(name: .long) var abort: Bool = false
    @Flag(name: .long) var `continue`: Bool = false
    @Option(name: .shortAndLong, help: "Commit message (for --continue)") var message: String?
    @Option(name: .long) var strategy: String = "ort"
    @Flag(name: .long) var preview: Bool = false
    @Argument var targetArg: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Merge")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let engine = MergeEngine(repo: repo)
        if abort { try engine.mergeAbort(); print("merge aborted"); return }
        if `continue` {
            let oid = try engine.mergeContinue(message: message)
            print("merge committed: \(oid.hex.prefix(7))")
            return
        }
        guard let target = targetArg else {
            throw SpacesError.invalidArgument("merge requires a target (or --continue/--abort)")
        }
        if preview {
            
            guard let head = try repo.refs.headOID(objects: repo.objects) else {
                throw SpacesError.branchNotFound("HEAD")
            }
            let theirs = try repo.resolveRevision(target)
            let merged = try engine.mergeTrees(oursHead: head, theirsOID: theirs)
            print("would merge \(target) (\(theirs.hex.prefix(7)))")
            print("conflicts: \(merged.conflicts.count)")
            for c in merged.conflicts { print("  \(c.kind.rawValue): \(c.path)") }
            return
        }
        let outcome = try engine.merge(target, allowFF: !noFF, strategy: strategy)
        switch outcome.result {
        case .upToDate:
            print("Already up to date.")
        case .fastForward(let oid):
            print("Fast-forward to \(oid.hex.prefix(7))")
        case .merged(_, let conflicts, _):
            if conflicts.isEmpty {
                print("Merge completed: \(outcome.commitOID?.hex.prefix(7) ?? "")")
            } else {
                print("Merge stopped with \(conflicts.count) conflict(s):")
                for c in conflicts { print("  \(c)") }
                print("Resolve conflicts, then run 'spaces merge --continue'")
            }
        }
    }
}

struct MergeAbort: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "merge-abort", abstract: "Abort a merge")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "MergeAbort")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try MergeEngine(repo: repo).mergeAbort()
        print("merge aborted")
    }
}

struct MergeContinue: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "merge-continue", abstract: "Continue a merge after resolving conflicts")
    @Option(name: .long) var repo: String?
    @Option(name: .shortAndLong) var message: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "MergeContinue")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let oid = try MergeEngine(repo: repo).mergeContinue(message: message)
        print("merge committed: \(oid.hex.prefix(7))")
    }
}

struct MergePreview: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "merge-preview", abstract: "Preview a merge")
    @Option(name: .long) var repo: String?
    @Argument var target: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "MergePreview")
        var cmd = try Merge.parseAsRoot(["--repo", repo ?? ".", "--preview", target])
        try cmd.run()
    }
}

struct MergeStrategy: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "merge-strategy", abstract: "Show the default merge strategy, or details for one strategy")
    @Option(name: .long) var repo: String?
    @Argument var name: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "MergeStrategy")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let engine = MergeEngine(repo: repo)
        if let name {
            let info = try engine.strategy(named: name)
            print("\(info.name)\(info.name == engine.defaultMergeStrategy().name ? " (default)" : "")")
            print("implemented: \(info.implemented ? "yes" : "no")")
            print(info.description)
            return
        }
        let info = engine.defaultMergeStrategy()
        print("default: \(info.name)")
        print("implemented: \(info.implemented ? "yes" : "no")")
        print(info.description)
    }
}



struct Rebase: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Rebase current branch onto a target",
        subcommands: [RebaseContinue.self, RebaseAbort.self, RebaseSkip.self])
    @Option(name: .long) var repo: String?
    @Argument var onto: String
    @Argument var branch: String?
    @Option(name: .long, help: "Todo spec lines: 'pick <rev>', 'drop <rev>', 'squash <rev>'...") var todo: [String] = []
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Rebase")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if let b = branch {
            try BranchOps(repo: repo).switchTo(b)
        }
        let state = try RebaseOps(repo: repo).start(onto: onto,
                                                     todo: todo.isEmpty ? nil : todo)
        if let s = state {
            print("rebase in progress: \(s.todo.count - s.done) commits remaining")
            if !s.conflicts.isEmpty {
                print("conflicts: \(s.conflicts.joined(separator: ", "))")
            }
        } else {
            print("already up to date")
        }
    }
}

struct RebaseContinue: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rebase-continue", abstract: "Continue rebase")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "RebaseContinue")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let state = try RebaseOps(repo: repo).continueRebase()
        if let s = state { print("rebase: \(s.todo.count - s.done) commits remaining") }
        else { print("rebase finished") }
    }
}

struct RebaseAbort: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rebase-abort", abstract: "Abort rebase")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "RebaseAbort")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try RebaseOps(repo: repo).abort()
        print("rebase aborted")
    }
}

struct RebaseSkip: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rebase-skip", abstract: "Skip current rebase commit")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "RebaseSkip")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let state = try RebaseOps(repo: repo).skip()
        if let s = state { print("rebase: \(s.todo.count - s.done) commits remaining") }
        else { print("rebase finished") }
    }
}

struct CherryPick: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Apply a commit onto HEAD")
    @Option(name: .long) var repo: String?
    @Argument var revs: [String]
    @Flag(name: .long) var `continue`: Bool = false
    @Flag(name: .long) var abort: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "CherryPick")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let engine = MergeEngine(repo: repo)
        if abort { try engine.cherryPickAbort(); print("cherry-pick aborted"); return }
        if `continue` {
            do {
                if let oid = try engine.cherryPickContinue() {
                    print("cherry-pick committed: \(oid.hex.prefix(7))")
                } else {
                    print("nothing to continue: no cherry-pick in progress")
                }
            } catch SpacesError.invalidArgument(let message) where message == "no cherry-pick/revert in progress" {
                print("nothing to continue: no cherry-pick in progress")
            }
            return
        }
        for rev in revs {
            if let oid = try engine.cherryPick(rev) {
                print("cherry-picked \(rev) as \(oid.hex.prefix(7))")
            } else {
                print("cherry-pick of \(rev) stopped with conflicts")
                return
            }
        }
    }
}

struct CherryPickContinue: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cherry-pick-continue", abstract: "Continue cherry-pick")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "CherryPickContinue")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        do {
            if let oid = try MergeEngine(repo: repo).cherryPickContinue() {
                print("committed \(oid.hex.prefix(7))")
            } else {
                print("nothing to continue: no cherry-pick in progress")
            }
        } catch SpacesError.invalidArgument(let message) where message == "no cherry-pick/revert in progress" {
            print("nothing to continue: no cherry-pick in progress")
        }
    }
}

struct CherryPickAbort: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cherry-pick-abort", abstract: "Abort cherry-pick")
    @Option(name: .long) var repo: String?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "CherryPickAbort")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        try MergeEngine(repo: repo).cherryPickAbort()
        print("aborted")
    }
}

struct Revert: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Revert a commit")
    @Option(name: .long) var repo: String?
    @Argument var revs: [String]
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Revert")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for rev in revs {
            if let oid = try MergeEngine(repo: repo).cherryPick(rev, revert: true) {
                print("reverted \(rev) as \(oid.hex.prefix(7))")
            } else {
                print("revert of \(rev) stopped with conflicts")
                return
            }
        }
    }
}

struct Reset: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Reset HEAD/index/worktree")
    @Option(name: .long) var repo: String?
    @Flag(name: .long) var soft: Bool = false
    @Flag(name: .long) var mixed: Bool = false
    @Flag(name: .long) var hard: Bool = false
    @Argument var rev: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Reset")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let mode: BranchOps.ResetMode = hard ? .hard : (soft ? .soft : .mixed)
        try BranchOps(repo: repo).reset(to: rev, mode: mode)
        print("reset \(mode) to \(rev)")
    }
}

struct ResetHistory: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reset-history", abstract: "Alias for reset --hard")
    @Option(name: .long) var repo: String?
    @Argument var rev: String = "HEAD"
    @Flag(name: .long) var hard: Bool = true
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "ResetHistory")
        var cmd = try Reset.parseAsRoot(["--repo", repo ?? ".", "--hard", rev])
        try cmd.run()
    }
}

struct Reflog: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show reflog")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var limit: Int = 50
    @Argument var ref: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Reflog")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for e in try repo.readReflog(refName: ref, limit: limit) {
            print("\(e.timestamp) \(e.new?.hex.prefix(7) ?? "--------") \(e.message) (\(e.ident))")
        }
    }
}

struct Blame: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Line-level authorship")
    @Option(name: .long) var repo: String?
    @Argument var path: String
    @Argument var rev: String = "HEAD"
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Blame")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        for line in try HistoryOps(repo: repo).blame(path, rev: rev) {
            print("\(line.commit.hex.prefix(7)) (\(line.author)) \(line.line)")
        }
    }
}

struct Ancestry: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Merge base of two revisions")
    @Option(name: .long) var repo: String?
    @Argument var a: String
    @Argument var b: String
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Ancestry")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        if let mb = try HistoryOps(repo: repo).mergeBase(
            repo.resolveRevision(a), repo.resolveRevision(b)) {
            print(mb.hex)
        } else {
            print("no common ancestor")
        }
    }
}

struct Graph: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Commit graph")
    @Option(name: .long) var repo: String?
    @Option(name: .long) var limit: Int = 100
    @Flag(name: .long) var all: Bool = false
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Graph")
        let repo = try (repo.map { try Repository.open(at: URL(fileURLWithPath: $0)) } ?? Repository.open())
        let nodes = try BranchOps(repo: repo).graph(limit: limit)
        for n in nodes {
            let lane = String(repeating: " ", count: n.lane * 2) + "*"
            let refs = n.refs.isEmpty ? "" : " (\(n.refs.joined(separator: ", ")))"
            print("\(lane) \(n.oid.hex.prefix(7)) \(n.summary)\(refs)")
        }
    }
}
