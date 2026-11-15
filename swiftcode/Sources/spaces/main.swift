import ArgumentParser
import Foundation
import SpacesEngine

@main
struct SpacesCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spaces",
        abstract: "Spaces — SwiftCode's native source control",
        version: "1.0.0",
        subcommands: [
            Init.self, Status.self, Changes.self, Stage.self, Add.self, Remove.self,
            Move.self, Restore.self, Clean.self, Unstage.self, Reset.self, ResetHistory.self,
            Commit.self, Amend.self, Log.self, Show.self, Describe.self, Diff.self,
            Patch.self, Ancestry.self, Graph.self, Blame.self, Annotate.self,
            Branch.self, Branches.self, Switch.self, Checkout.self, Merge.self, MergeAbort.self,
            MergeContinue.self, MergePreview.self, MergeStrategyList.self,
            Rebase.self, RebaseContinue.self, RebaseAbort.self, RebaseSkip.self,
            CherryPick.self, CherryPickContinue.self, CherryPickAbort.self,
            Revert.self, Reflog.self, Tag.self, Tags.self, VerifyTag.self, Stash.self, Stashes.self,
            Snapshot.self, Timeline.self, Checkpoint.self, Recover.self,
            RestorePoint.self, RecoveryList.self, RecoveryPrune.self,
            Remote.self, Remotes.self, Fetch.self, Pull.self, Push.self, Sync.self,
            Publish.self, Unpublish.self, Upstream.self, Transfer.self,
            Clone.self, Doctor.self, Fsck.self, GC.self, Prune.self,
            Compact.self, Optimize.self, Repack.self, Count.self,
            CountObjects.self, Storage.self, Integrity.self, Diagnostics.self,
            Health.self, Repair.self, RepairIndex.self, RebuildIndex.self,
            Maintenance.self, Migrate.self, Upgrade.self, Config.self,
            Version.self, Info.self, Inspect.self, Validate.self,
            Open.self, Discover.self, Explain.self, Impact.self, Compare.self,
            Benchmark.self, Trace.self, Events.self, Notes.self, Security.self, Sign.self,
            VerifySignature.self, Identities.self, Credentials.self,
            Permissions.self, Audit.self, Search.self, Find.self,
            FindFile.self, FindCommit.self, FindChange.self, FindBranch.self,
            FindHistory.self, Hooks.self, HookInstallCmd.self, HookRemoveCmd.self,
            Lfs.self, Extensions.self, ImportGit.self, Import.self,
            ExportGit.self, Export.self, Archive.self,
            Bundle.self,
            Worktree.self, Worktrees.self, Workspace.self, Workspaces.self,
            LsFiles.self, LsTree.self, CatFile.self,
            MergeStrategy.self,
            SemanticSearch.self, HistorySearch.self, Dependencies.self,
            FileEvolution.self, BranchStack.self, BranchCheckpoint.self,
            ChangeSet.self,
            Provenance.self, Policy.self, SecurityReport.self, SecretHistory.self,
            Ownership.self, Review.self, ReviewStatus.self, Discussion.self,
            Notifications.self, Backup.self, BackupVerify.self, BackupRestore.self,
            StorageHeatmap.self, StorageProfile.self, WorkspaceTemplate.self,
            Automation.self, PatchCollection.self, SymbolHistory.self,
            ApiCompatibility.self, TestProvenance.self, BuildImpact.self,
            Performance.self, OperationUndo.self, Snapshots.self, History.self,
        ])

    static func formatError(_ message: String) -> String {
        "spaces: error: \(message)"
    }
}



struct RepoOptions: ParsableArguments {
    @Option(name: .long, help: "Repository path (default: discover upward)")
    var repo: String?

    func openRepo() throws -> Repository {
        try Repository.open(at: repo.map { URL(fileURLWithPath: $0) })
    }
}

struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Machine-readable JSON output")
    var json: Bool = false

    @Flag(name: .long, help: "Quiet output")
    var quiet: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Disable colored output")
    var noColor: Bool = false

    @Flag(name: .long, help: "Assume yes for prompts")
    var yes: Bool = false

    @Flag(name: .long, help: "Dry run")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Force operation")
    var force: Bool = false

    @Option(name: .long, help: "Output format: text, json, jsonl")
    var format: String = "text"

    @Flag(name: .long, help: "Debug output")
    var debug: Bool = false

    var jsonRequested: Bool { json || format == "json" || format == "jsonl" }
}

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "Output format: text, json, jsonl")
    var format: String = "text"

    @Flag(name: .long, help: "Suppress non-essential output")
    var quiet: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Debug output")
    var debug: Bool = false

    @Flag(name: .long, help: "Disable colored output")
    var noColor: Bool = false
}

enum SpacesOutput {
    nonisolated(unsafe) static var format: String = "text"
    nonisolated(unsafe) static var quiet: Bool = false
    nonisolated(unsafe) static var verbose: Bool = false
    nonisolated(unsafe) static var debug: Bool = false
    nonisolated(unsafe) static var noColor: Bool = false

    static func apply(_ global: GlobalOptions, command: String) throws {
        guard ["text", "json", "jsonl"].contains(global.format) else {
            throw SpacesError.invalidArgument("unknown --format '\(global.format)' (expected text, json, or jsonl)")
        }
        if global.format != "text" { format = global.format }
        quiet = quiet || global.quiet
        verbose = verbose || global.verbose
        debug = debug || global.debug
        noColor = noColor || global.noColor
        if verbose && !quiet {
            FileHandle.standardError.write("spaces: running \(command)\n".data(using: .utf8)!)
        }
        if debug && !quiet {
            FileHandle.standardError.write("spaces: debug: \(command) format=\(format) quiet=\(quiet) verbose=\(verbose) no-color=\(noColor)\n".data(using: .utf8)!)
        }
    }

    static func apply(_ output: OutputOptions, command: String) throws {
        try apply(GlobalOptions(format: output.format, quiet: output.quiet,
                                verbose: output.verbose, debug: output.debug,
                                noColor: output.noColor), command: command)
    }
}

func wantsJSON(_ localJSON: Bool) -> Bool {
    localJSON || SpacesOutput.format == "json" || SpacesOutput.format == "jsonl"
}

func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if SpacesOutput.quiet && SpacesOutput.format == "text" { return }
    Swift.print(items.map { String(describing: $0) }.joined(separator: separator), terminator: terminator)
}

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    if SpacesOutput.format == "jsonl" {
        encoder.outputFormatting = [.sortedKeys]
    } else {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    if let data = try? encoder.encode(value),
       let str = String(data: data, encoding: .utf8) {
        Swift.print(str)
    }
}

func printStatus(_ report: WorktreeScanner.StatusReport, json: Bool) {
    if json {
        struct S: Encodable {
            var branch: String?
            var head: String?
            var staged: [String]
            var unstaged: [String]
            var untracked: [String]
            var clean: Bool
            var ahead: Int
            var behind: Int
        }
        printJSON(S(branch: report.branch, head: report.headOID?.hex,
                    staged: report.staged.map { "\($0.indexStatus?.rawValue ?? "") \($0.path)" },
                    unstaged: report.unstaged.map { "\($0.worktreeStatus?.rawValue ?? "") \($0.path)" },
                    untracked: report.untrackedFiles.map { $0.path },
                    clean: report.isClean, ahead: report.ahead, behind: report.behind))
        return
    }
    if let branch = report.branch {
        print("On branch \(branch)")
        if report.ahead > 0 || report.behind > 0 {
            print("  ahead \(report.ahead), behind \(report.behind)")
        }
    } else if let head = report.headOID {
        print("HEAD detached at \(head.hex.prefix(12))")
    } else {
        print("No commits yet")
    }
    if report.inMerge { print("You have unmerged paths (merge in progress)") }
    if report.inRebase { print("Rebase in progress") }
    let staged = report.staged
    let unstaged = report.unstaged
    let untracked = report.untrackedFiles
    if staged.isEmpty && unstaged.isEmpty && untracked.isEmpty && !report.isClean {
        
    }
    if !staged.isEmpty {
        print("Changes to be committed:")
        for s in staged {
            print("  \(s.indexStatus?.rawValue ?? "") \(s.oldPath != nil ? "\(s.oldPath!) -> " : "")\(s.path)")
        }
    }
    if !unstaged.isEmpty {
        print("Changes not staged for commit:")
        for s in unstaged {
            print("  \(s.worktreeStatus?.rawValue ?? "") \(s.path)")
        }
    }
    if !untracked.isEmpty {
        print("Untracked files:")
        for s in untracked { print("  \(s.path)") }
    }
    if report.isClean { print("nothing to commit, working tree clean") }
}
