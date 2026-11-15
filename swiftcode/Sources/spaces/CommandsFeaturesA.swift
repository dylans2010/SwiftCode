import ArgumentParser
import Foundation
import SpacesEngine

func openAPI(_ repoOptions: RepoOptions) throws -> SpacesAPI {
    SpacesAPI(repo: try repoOptions.openRepo())
}

func requireDestructiveConfirmation(_ output: OutputOptions, operation: String) throws {
    guard output.yes || output.force else {
        throw SpacesError.invalidArgument("\(operation) requires --yes or --force")
    }
}

struct SemanticSearch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search indexed Swift declarations by name")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Query text") var query: String
    @Option(name: .long, help: "Symbol kind: function, class, struct, enum, protocol, extension, variable, typealias, import") var kind: String?
    @Option(name: .long, help: "Maximum matches") var limit: Int = 100

    func run() throws {
        try SpacesOutput.apply(output, command: "SemanticSearch")
        let api = try openAPI(repoOptions)
        var symbolKind: SemanticSearchOps.SymbolKind?
        if let kind {
            guard let parsed = SemanticSearchOps.SymbolKind(rawValue: kind) else {
                throw SpacesError.invalidArgument("unknown symbol kind: \(kind)")
            }
            symbolKind = parsed
        }
        let matches = try api.semanticSearch(query: query, kind: symbolKind, limit: limit)
        if output.jsonRequested { printJSON(matches); return }
        for m in matches {
            print("\(m.kind.rawValue) \(m.name) \(m.file):\(m.line)")
        }
        if matches.isEmpty { print("no matches") }
    }
}

struct HistorySearch: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search file contents across commit history")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Query text") var query: String
    @Option(name: .long, help: "Maximum matches") var limit: Int = 100
    @Flag(name: .long, help: "Treat the query as a regular expression") var regex: Bool = false

    struct Row: Encodable {
        var commit: String
        var path: String
        var line: Int
        var text: String
        var summary: String
        var timestamp: Int64
    }

    func run() throws {
        try SpacesOutput.apply(output, command: "HistorySearch")
        let api = try openAPI(repoOptions)
        let matches = try api.historySearch(query: query, limit: limit, useRegex: regex)
        if output.jsonRequested {
            printJSON(matches.map { Row(commit: $0.commit.hex, path: $0.path, line: $0.line, text: $0.text, summary: $0.summary, timestamp: $0.timestamp) })
            return
        }
        for m in matches {
            print("\(m.commit.hex.prefix(7)) \(m.path):\(m.line) \(m.text)")
        }
        if matches.isEmpty { print("no matches") }
    }
}

struct Dependencies: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show the file-to-module dependency graph")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Flag(name: .long, help: "Rebuild the graph from current files") var refresh: Bool = false

    func run() throws {
        try SpacesOutput.apply(output, command: "Dependencies")
        let api = try openAPI(repoOptions)
        let graph = refresh ? try api.refreshDependencyGraph() : try api.dependencyGraph()
        if output.jsonRequested { printJSON(graph); return }
        for edge in graph.edges {
            print("\(edge.from) -> \(edge.to)")
        }
        if graph.edges.isEmpty { print("no dependencies") }
    }
}

struct FileEvolution: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show how a file changed across history")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Path of the file") var path: String
    @Option(name: .long, help: "Maximum steps") var limit: Int = 100

    struct Row: Encodable {
        var commit: String
        var timestamp: Int64
        var summary: String
        var change: String
        var oldPath: String?
        var path: String
    }

    func run() throws {
        try SpacesOutput.apply(output, command: "FileEvolution")
        let api = try openAPI(repoOptions)
        let steps = try api.fileEvolution(path: path, limit: limit)
        if output.jsonRequested {
            printJSON(steps.map { Row(commit: $0.commit.hex, timestamp: $0.timestamp, summary: $0.summary, change: $0.change.rawValue, oldPath: $0.oldPath, path: $0.path) })
            return
        }
        for step in steps {
            let renamed = step.oldPath.map { " (was \($0))" } ?? ""
            print("\(step.commit.hex.prefix(7)) \(step.change.rawValue) \(step.path)\(renamed) \(step.summary)")
        }
        if steps.isEmpty { print("no history for \(path)") }
    }
}

struct BranchStack: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Branch stack operations",
        subcommands: [BranchStackCreate.self, BranchStackList.self, BranchStackStatusCmd.self, BranchStackUpdate.self])
}

struct BranchStackCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a branch stack")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Stack name") var name: String
    @Argument(help: "Branches in the stack, bottom to top") var branches: [String]
    @Option(name: .long, help: "Base branch (default: current branch)") var base: String?

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchStackCreate")
        let repo = try repoOptions.openRepo()
        let api = SpacesAPI(repo: repo)
        let resolvedBase: String
        if let base {
            resolvedBase = base
        } else if let current = try repo.refs.currentBranch() {
            resolvedBase = current
        } else {
            throw SpacesError.invalidArgument("branch-stack create requires --base when not on a branch")
        }
        let record = try api.createBranchStack(name: name, branches: branches, base: resolvedBase)
        print("created stack \(record.name) on base \(record.base): \(record.branches.joined(separator: ", "))")
    }
}

struct BranchStackList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List branch stacks")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "BranchStackList")
        let api = try openAPI(repoOptions)
        let stacks = try api.branchStacks()
        if output.jsonRequested { printJSON(stacks); return }
        for stack in stacks {
            print("\(stack.name) [base \(stack.base)]: \(stack.branches.joined(separator: ", "))")
        }
        if stacks.isEmpty { print("no branch stacks") }
    }
}

struct BranchStackStatusCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show a branch stack's ahead/behind status")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Stack name") var name: String

    func run() throws {
        try SpacesOutput.apply(output, command: "BranchStackStatusCmd")
        let api = try openAPI(repoOptions)
        let status = try api.branchStackStatus(name: name)
        if output.jsonRequested { printJSON(status); return }
        print("stack \(status.name) [base \(status.base)]")
        for branch in status.branches {
            print("  \(branch.branch) (parent \(branch.parent)) \(branch.oid.hex.prefix(7)) ahead \(branch.ahead), behind \(branch.behind)")
        }
    }
}

struct BranchStackUpdate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "update", abstract: "Replace a branch stack's branches")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Stack name") var name: String
    @Argument(help: "New branches in the stack, bottom to top") var branches: [String]

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchStackUpdate")
        let api = try openAPI(repoOptions)
        let record = try api.updateBranchStack(name: name, branches: branches)
        print("updated stack \(record.name): \(record.branches.joined(separator: ", "))")
    }
}

struct BranchCheckpoint: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Branch checkpoint operations",
        subcommands: [BranchCheckpointCreate.self, BranchCheckpointList.self, BranchCheckpointRestore.self])
}

struct BranchCheckpointCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a checkpoint for a branch")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Branch name") var branch: String
    @Argument(help: "Checkpoint name") var name: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BranchCheckpointCreate")
        let api = try openAPI(repoOptions)
        let oid = try api.createBranchCheckpoint(branch: branch, name: name)
        print("checkpoint \(name) for branch \(branch): \(oid.hex.prefix(12))")
    }
}

struct BranchCheckpointList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List checkpoints for a branch")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Branch name") var branch: String

    func run() throws {
        try SpacesOutput.apply(output, command: "BranchCheckpointList")
        let api = try openAPI(repoOptions)
        let checkpoints = try api.branchCheckpoints(branch: branch)
        if output.jsonRequested { printJSON(checkpoints); return }
        for checkpoint in checkpoints {
            print("\(checkpoint.timestamp) \(checkpoint.name) \(checkpoint.oid.hex.prefix(12)) \(checkpoint.message)")
        }
        if checkpoints.isEmpty { print("no checkpoints for branch \(branch)") }
    }
}

struct BranchCheckpointRestore: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "restore", abstract: "Restore a branch to a checkpoint")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Branch name") var branch: String
    @Argument(help: "Checkpoint name") var name: String

    func run() throws {
        try SpacesOutput.apply(output, command: "BranchCheckpointRestore")
        try requireDestructiveConfirmation(output, operation: "branch-checkpoint restore")
        let api = try openAPI(repoOptions)
        try api.restoreBranchCheckpoint(branch: branch, name: name)
        print("restored branch \(branch) to checkpoint \(name)")
    }
}

struct ChangeSet: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "changeset", abstract: "Change set operations",
        subcommands: [ChangeSetCreate.self, ChangeSetList.self, ChangeSetAdd.self, ChangeSetStage.self])
}

struct ChangeSetCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a change set")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Change set name") var name: String
    @Option(name: .long, help: "Description") var description: String = ""

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "ChangeSetCreate")
        let api = try openAPI(repoOptions)
        let record = try api.createChangeSet(name: name, description: description)
        print("created change set \(record.id) (\(record.name))")
    }
}

struct ChangeSetList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List change sets")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "ChangeSetList")
        let api = try openAPI(repoOptions)
        let sets = try api.changeSets()
        if output.jsonRequested { printJSON(sets); return }
        for set in sets {
            print("\(set.id) \(set.name) (\(set.paths.count) path(s)): \(set.paths.joined(separator: ", "))")
        }
        if sets.isEmpty { print("no change sets") }
    }
}

struct ChangeSetAdd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a path to a change set")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Change set id") var id: String
    @Argument(help: "Path to add") var path: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "ChangeSetAdd")
        let api = try openAPI(repoOptions)
        let record = try api.addToChangeSet(id: id, path: path)
        print("added \(path) to change set \(record.id) (\(record.paths.count) path(s))")
    }
}

struct ChangeSetStage: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stage", abstract: "Stage all paths in a change set")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Change set id") var id: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "ChangeSetStage")
        let api = try openAPI(repoOptions)
        let staged = try api.stageChangeSet(id: id)
        for path in staged { print("staged \(path)") }
        if staged.isEmpty { print("nothing staged for change set \(id)") }
    }
}
