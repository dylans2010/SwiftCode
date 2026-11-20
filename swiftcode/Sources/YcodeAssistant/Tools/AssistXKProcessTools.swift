// Expansion toolkit: Process. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKGitContributorSummaryTool: AssistTool {
    public init() {}
    public var id: String { "git_contributor_summary" }
    public var name: String { "Git Contributor Summary" }
    public var description: String { "Lists commit counts per author (git shortlog -sne) for the repository or `rev` range." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists commit counts per author (git shortlog -sne) for the repository or `rev` range.", properties: ["rev": JSONSchema(type: "string", description: "Git revision (default HEAD).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rev = AssistToolKit.string(input, "rev") ?? "HEAD"
        guard !rev.hasPrefix("-") else { return AssistToolKit.invalid("Revision must not start with '-'.") }
        return AssistToolKit.processResult("Git Contributor Summary", "git", ["shortlog", "-sne", rev], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitTagListTool: AssistTool {
    public init() {}
    public var id: String { "git_tag_list" }
    public var name: String { "Git Tag List" }
    public var description: String { "Lists tags sorted by version with their dates and subjects." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists tags sorted by version with their dates and subjects.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Tag List", "git", ["for-each-ref", "--sort=-version:refname", "--format=%(refname:short)\t%(creatordate:short)\t%(subject)", "refs/tags"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitRemoteListTool: AssistTool {
    public init() {}
    public var id: String { "git_remote_list" }
    public var name: String { "Git Remote List" }
    public var description: String { "Lists configured remotes with fetch/push URLs." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists configured remotes with fetch/push URLs.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Remote List", "git", ["remote", "-v"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitBranchOverviewTool: AssistTool {
    public init() {}
    public var id: String { "git_branch_overview" }
    public var name: String { "Git Branch Overview" }
    public var description: String { "Lists local and remote branches with last commit date, upstream tracking and ahead/behind status." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists local and remote branches with last commit date, upstream tracking and ahead/behind status.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Branch Overview", "git", ["for-each-ref", "--sort=-committerdate", "--format=%(refname:short)\t%(committerdate:relative)\t%(upstream:short)\t%(upstream:track)\t%(subject)", "refs/heads", "refs/remotes"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitStashOverviewTool: AssistTool {
    public init() {}
    public var id: String { "git_stash_overview" }
    public var name: String { "Git Stash Overview" }
    public var description: String { "Lists stash entries with dates and messages." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists stash entries with dates and messages.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Stash Overview", "git", ["stash", "list", "--date=relative"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitReflogRecentTool: AssistTool {
    public init() {}
    public var id: String { "git_reflog_recent" }
    public var name: String { "Git Reflog Recent" }
    public var description: String { "Shows the last `count` reflog entries (default 30) — the safety net for recovering lost commits." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows the last `count` reflog entries (default 30) — the safety net for recovering lost commits.", properties: ["count": JSONSchema(type: "integer", description: "Entries to show.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Reflog Recent", "git", ["reflog", "-n", String(max(1, AssistToolKit.int(input, "count", default: 30))), "--date=relative"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitFileHistoryTool: AssistTool {
    public init() {}
    public var id: String { "git_file_history" }
    public var name: String { "Git File History" }
    public var description: String { "Shows the commit history of one file (following renames) with authors, dates and subjects." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows the commit history of one file (following renames) with authors, dates and subjects.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path."), "count": JSONSchema(type: "integer", description: "Max commits.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Git File History", "git", ["log", "--follow", "--date=short", "--format=%h %ad %an  %s", "-n", String(max(1, AssistToolKit.int(input, "count", default: 50))), "--", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitShowCommitSummaryTool: AssistTool {
    public init() {}
    public var id: String { "git_show_commit_summary" }
    public var name: String { "Git Show Commit" }
    public var description: String { "Shows a commit's metadata and per-file change statistics (`rev`, default HEAD)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows a commit's metadata and per-file change statistics (`rev`, default HEAD).", properties: ["rev": JSONSchema(type: "string", description: "Git revision (default HEAD).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rev = AssistToolKit.string(input, "rev") ?? "HEAD"
        guard !rev.hasPrefix("-") else { return AssistToolKit.invalid("Revision must not start with '-'.") }
        return AssistToolKit.processResult("Git Show Commit", "git", ["show", "--stat", "--format=commit %H%nAuthor: %an <%ae>%nDate: %ad%n%n%B", rev], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitDiffStatRangeTool: AssistTool {
    public init() {}
    public var id: String { "git_diff_stat_range" }
    public var name: String { "Git Diff Stat" }
    public var description: String { "Summarizes changed files and line counts between `base` (default HEAD) and the working tree, or between `base` and `head` when given." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Summarizes changed files and line counts between `base` (default HEAD) and the working tree, or between `base` and `head` when given.", properties: ["base": JSONSchema(type: "string", description: "Base revision (default HEAD)."), "head": JSONSchema(type: "string", description: "Optional head revision.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let base = AssistToolKit.string(input, "base") ?? "HEAD"
        let headArg = AssistToolKit.string(input, "head") ?? ""
        let head = headArg.isEmpty ? "--" : headArg
        guard !base.hasPrefix("-"), !headArg.hasPrefix("-") else { return AssistToolKit.invalid("Revisions must not start with '-'.") }
        return AssistToolKit.processResult("Git Diff Stat", "git", ["diff", "--stat", base, head], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitStagedDiffStatTool: AssistTool {
    public init() {}
    public var id: String { "git_staged_diff_stat" }
    public var name: String { "Git Staged Diff Stat" }
    public var description: String { "Summarizes staged (index) changes with per-file line counts." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Summarizes staged (index) changes with per-file line counts.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Staged Diff Stat", "git", ["diff", "--cached", "--stat"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitUntrackedFilesTool: AssistTool {
    public init() {}
    public var id: String { "git_untracked_files" }
    public var name: String { "Git Untracked Files" }
    public var description: String { "Lists untracked files not covered by .gitignore." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists untracked files not covered by .gitignore.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Untracked Files", "git", ["ls-files", "--others", "--exclude-standard"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitIgnoredFilesTool: AssistTool {
    public init() {}
    public var id: String { "git_ignored_files" }
    public var name: String { "Git Ignored Files" }
    public var description: String { "Lists ignored files and directories present in the working tree." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists ignored files and directories present in the working tree.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Ignored Files", "git", ["ls-files", "--others", "--ignored", "--exclude-standard", "--directory"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitCheckIgnoreTool: AssistTool {
    public init() {}
    public var id: String { "git_check_ignore" }
    public var name: String { "Git Check Ignore" }
    public var description: String { "Explains whether `path` is ignored and which .gitignore rule matches." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Explains whether `path` is ignored and which .gitignore rule matches.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Git Check Ignore", "git", ["check-ignore", "-v", "--no-index", rel], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKGitLocalConfigTool: AssistTool {
    public init() {}
    public var id: String { "git_local_config" }
    public var name: String { "Git Local Config" }
    public var description: String { "Lists repository-local git configuration (git config --local --list)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists repository-local git configuration (git config --local --list).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Local Config", "git", ["config", "--local", "--list"], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKGitCommitCountTool: AssistTool {
    public init() {}
    public var id: String { "git_commit_count" }
    public var name: String { "Git Commit Count" }
    public var description: String { "Counts commits reachable from `rev` (default HEAD), plus merge commit count." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts commits reachable from `rev` (default HEAD), plus merge commit count.", properties: ["rev": JSONSchema(type: "string", description: "Git revision (default HEAD).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rev = AssistToolKit.string(input, "rev") ?? "HEAD"
        guard !rev.hasPrefix("-") else { return AssistToolKit.invalid("Revision must not start with '-'.") }
        return AssistToolKit.processResult("Git Commit Count", "git", ["rev-list", "--count", rev], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitLastCommitTool: AssistTool {
    public init() {}
    public var id: String { "git_last_commit" }
    public var name: String { "Git Last Commit" }
    public var description: String { "Shows the most recent commit's hash, author, relative date and subject." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows the most recent commit's hash, author, relative date and subject.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Last Commit", "git", ["log", "-1", "--format=%H%n%an <%ae>%n%ar%n%s"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitMergeBaseTool: AssistTool {
    public init() {}
    public var id: String { "git_merge_base" }
    public var name: String { "Git Merge Base" }
    public var description: String { "Finds the common ancestor commit of revisions `a` and `b`." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds the common ancestor commit of revisions `a` and `b`.", properties: ["a": JSONSchema(type: "string", description: "First revision."), "b": JSONSchema(type: "string", description: "Second revision.")], required: ["a", "b"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let a = AssistToolKit.string(input, "a"), let b = AssistToolKit.string(input, "b"), !a.hasPrefix("-"), !b.hasPrefix("-") else { return AssistToolKit.missing("a/b") }
        return AssistToolKit.processResult("Git Merge Base", "git", ["merge-base", a, b], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitAheadBehindTool: AssistTool {
    public init() {}
    public var id: String { "git_ahead_behind" }
    public var name: String { "Git Ahead/Behind" }
    public var description: String { "Counts commits the current branch is ahead/behind `upstream` (default @{u})." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts commits the current branch is ahead/behind `upstream` (default @{u}).", properties: ["upstream": JSONSchema(type: "string", description: "Upstream ref (default @{u}).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let up = AssistToolKit.string(input, "upstream") ?? "@{u}"
        guard !up.hasPrefix("-") else { return AssistToolKit.invalid("Invalid upstream.") }
        return AssistToolKit.processResult("Git Ahead/Behind", "git", ["rev-list", "--left-right", "--count", "HEAD..." + up], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitChangedFilesSinceTool: AssistTool {
    public init() {}
    public var id: String { "git_changed_files_since" }
    public var name: String { "Git Changed Files Since" }
    public var description: String { "Lists files changed between `rev` and HEAD with status letters (A/M/D/R)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists files changed between `rev` and HEAD with status letters (A/M/D/R).", properties: ["rev": JSONSchema(type: "string", description: "Git revision (default HEAD).")], required: ["rev"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rev = AssistToolKit.string(input, "rev") ?? "HEAD"
        guard !rev.hasPrefix("-") else { return AssistToolKit.invalid("Revision must not start with '-'.") }
        return AssistToolKit.processResult("Git Changed Files Since", "git", ["diff", "--name-status", rev, "HEAD"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitGrepTrackedTool: AssistTool {
    public init() {}
    public var id: String { "git_grep_tracked" }
    public var name: String { "Git Grep" }
    public var description: String { "Searches tracked files for `pattern` (extended regex) with line numbers using git grep." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Searches tracked files for `pattern` (extended regex) with line numbers using git grep.", properties: ["pattern": JSONSchema(type: "string", description: "Extended regex.")], required: ["pattern"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let pattern = AssistToolKit.string(input, "pattern"), !pattern.isEmpty else { return AssistToolKit.missing("pattern") }
        return AssistToolKit.processResult("Git Grep", "git", ["grep", "-n", "-I", "-E", "-e", pattern], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKGitBlameAuthorsTool: AssistTool {
    public init() {}
    public var id: String { "git_blame_authors" }
    public var name: String { "Git Blame Authors" }
    public var description: String { "Shows per-line authorship of a file condensed to author line counts (git blame --line-porcelain)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows per-line authorship of a file condensed to author line counts (git blame --line-porcelain).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Git Blame Authors", "git", ["blame", "--line-porcelain", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitLogSearchMessagesTool: AssistTool {
    public init() {}
    public var id: String { "git_log_search_messages" }
    public var name: String { "Git Log Search" }
    public var description: String { "Searches commit messages for `term` (case-insensitive) and lists matching commits." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Searches commit messages for `term` (case-insensitive) and lists matching commits.", properties: ["term": JSONSchema(type: "string", description: "Text to find in commit messages.")], required: ["term"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let term = AssistToolKit.string(input, "term"), !term.isEmpty else { return AssistToolKit.missing("term") }
        return AssistToolKit.processResult("Git Log Search", "git", ["log", "-i", "--grep", term, "--format=%h %ad %an  %s", "--date=short", "-n", "200"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitLogPickaxeTool: AssistTool {
    public init() {}
    public var id: String { "git_log_pickaxe" }
    public var name: String { "Git Pickaxe Search" }
    public var description: String { "Finds commits that added or removed the string `term` in code (git log -S), showing when a symbol appeared or vanished." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds commits that added or removed the string `term` in code (git log -S), showing when a symbol appeared or vanished.", properties: ["term": JSONSchema(type: "string", description: "Exact code string.")], required: ["term"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let term = AssistToolKit.string(input, "term"), !term.isEmpty else { return AssistToolKit.missing("term") }
        return AssistToolKit.processResult("Git Pickaxe Search", "git", ["log", "-S", term, "--format=%h %ad %an  %s", "--date=short", "-n", "100"], cwd: cwd, timeout: 180, allowNonZero: false)
    }
}


public struct XKGitLogByAuthorTool: AssistTool {
    public init() {}
    public var id: String { "git_log_by_author" }
    public var name: String { "Git Log By Author" }
    public var description: String { "Lists recent commits by `author` (name or email substring)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists recent commits by `author` (name or email substring).", properties: ["author": JSONSchema(type: "string", description: "Author name/email substring.")], required: ["author"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let author = AssistToolKit.string(input, "author"), !author.isEmpty else { return AssistToolKit.missing("author") }
        return AssistToolKit.processResult("Git Log By Author", "git", ["log", "--author", author, "--format=%h %ad  %s", "--date=short", "-n", "100"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitTreeAtRevisionTool: AssistTool {
    public init() {}
    public var id: String { "git_tree_at_revision" }
    public var name: String { "Git Tree At Revision" }
    public var description: String { "Lists files in `path` (default root) as they exist at revision `rev`." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists files in `path` (default root) as they exist at revision `rev`.", properties: ["rev": JSONSchema(type: "string", description: "Git revision (default HEAD)."), "path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rev = AssistToolKit.string(input, "rev") ?? "HEAD"
        guard !rev.hasPrefix("-") else { return AssistToolKit.invalid("Revision must not start with '-'.") }
        let rel = AssistToolKit.resolve(input, context: context).map { AssistToolKit.relative($0, context) } ?? "."
        return AssistToolKit.processResult("Git Tree At Revision", "git", ["ls-tree", "-r", "--name-only", rev, "--", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitShowFileAtRevisionTool: AssistTool {
    public init() {}
    public var id: String { "git_show_file_at_revision" }
    public var name: String { "Git Show File At Revision" }
    public var description: String { "Prints the contents of `path` at revision `rev` without checking it out." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Prints the contents of `path` at revision `rev` without checking it out.", properties: ["rev": JSONSchema(type: "string", description: "Git revision (default HEAD)."), "path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rev = AssistToolKit.string(input, "rev") ?? "HEAD"
        guard !rev.hasPrefix("-") else { return AssistToolKit.invalid("Revision must not start with '-'.") }
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Git Show File At Revision", "git", ["show", rev + ":" + rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitDescribeVersionTool: AssistTool {
    public init() {}
    public var id: String { "git_describe_version" }
    public var name: String { "Git Describe" }
    public var description: String { "Describes HEAD relative to the nearest tag (git describe --tags --always --dirty)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Describes HEAD relative to the nearest tag (git describe --tags --always --dirty).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Describe", "git", ["describe", "--tags", "--always", "--dirty"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitWorktreeOverviewTool: AssistTool {
    public init() {}
    public var id: String { "git_worktree_overview" }
    public var name: String { "Git Worktree Overview" }
    public var description: String { "Lists git worktrees attached to this repository." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists git worktrees attached to this repository.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Worktree Overview", "git", ["worktree", "list", "--porcelain"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitSubmoduleOverviewTool: AssistTool {
    public init() {}
    public var id: String { "git_submodule_overview" }
    public var name: String { "Git Submodule Overview" }
    public var description: String { "Shows submodule status (commit, path, described ref)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows submodule status (commit, path, described ref).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Submodule Overview", "git", ["submodule", "status", "--recursive"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitRepositorySizeTool: AssistTool {
    public init() {}
    public var id: String { "git_repository_size" }
    public var name: String { "Git Repository Size" }
    public var description: String { "Reports object counts and pack sizes (git count-objects -vH)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports object counts and pack sizes (git count-objects -vH).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Repository Size", "git", ["count-objects", "-vH"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKGitWhitespaceCheckTool: AssistTool {
    public init() {}
    public var id: String { "git_whitespace_check" }
    public var name: String { "Git Whitespace Check" }
    public var description: String { "Detects whitespace errors and conflict markers in uncommitted changes (git diff --check)." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Detects whitespace errors and conflict markers in uncommitted changes (git diff --check).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Whitespace Check", "git", ["diff", "--check", "HEAD"], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKGitConflictFilesTool: AssistTool {
    public init() {}
    public var id: String { "git_conflict_files" }
    public var name: String { "Git Conflicted Files" }
    public var description: String { "Lists files with unresolved merge conflicts." }
    public var capability: ToolCapability { .gitOperations }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists files with unresolved merge conflicts.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Git Conflicted Files", "git", ["diff", "--name-only", "--diff-filter=U"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSwiftToolchainInfoTool: AssistTool {
    public init() {}
    public var id: String { "swift_toolchain_info" }
    public var name: String { "Swift Toolchain Info" }
    public var description: String { "Reports the active Swift compiler version and target triple." }
    public var capability: ToolCapability { .compilation }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports the active Swift compiler version and target triple.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Swift Toolchain Info", "swift", ["--version"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSwiftpmDescribePackageTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_describe_package" }
    public var name: String { "SwiftPM Describe Package" }
    public var description: String { "Describes the Swift package at the workspace root (targets, products, dependencies, platforms) as JSON via `swift package describe --type json`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Describes the Swift package at the workspace root (targets, products, dependencies, platforms) as JSON via `swift package describe --type json`.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("SwiftPM Describe Package", "swift", ["package", "describe", "--type", "json"], cwd: cwd, timeout: 180, allowNonZero: false)
    }
}


public struct XKSwiftpmDependencyTreeTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_dependency_tree" }
    public var name: String { "SwiftPM Dependency Tree" }
    public var description: String { "Shows the resolved dependency graph of the Swift package (`swift package show-dependencies`)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows the resolved dependency graph of the Swift package (`swift package show-dependencies`).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("SwiftPM Dependency Tree", "swift", ["package", "show-dependencies", "--format", "text"], cwd: cwd, timeout: 300, allowNonZero: false)
    }
}


public struct XKSwiftpmDumpManifestTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_dump_manifest" }
    public var name: String { "SwiftPM Dump Manifest" }
    public var description: String { "Evaluates Package.swift and prints the manifest as JSON (`swift package dump-package`)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Evaluates Package.swift and prints the manifest as JSON (`swift package dump-package`).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("SwiftPM Dump Manifest", "swift", ["package", "dump-package"], cwd: cwd, timeout: 180, allowNonZero: false)
    }
}


public struct XKSwiftpmResolveDependenciesTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_resolve_dependencies" }
    public var name: String { "SwiftPM Resolve" }
    public var description: String { "Resolves and fetches package dependencies, updating Package.resolved if needed (network access)." }
    public var capability: ToolCapability { .compilation }
    public var riskLevel: ToolRiskLevel { .execution }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Resolves and fetches package dependencies, updating Package.resolved if needed (network access).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("SwiftPM Resolve", "swift", ["package", "resolve"], cwd: cwd, timeout: 900, allowNonZero: false)
    }
}


public struct XKSwiftpmListTestsTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_list_tests" }
    public var name: String { "SwiftPM List Tests" }
    public var description: String { "Builds test targets and lists every discovered test identifier (`swift test list`)." }
    public var capability: ToolCapability { .testing }
    public var riskLevel: ToolRiskLevel { .execution }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Builds test targets and lists every discovered test identifier (`swift test list`).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("SwiftPM List Tests", "swift", ["test", "list"], cwd: cwd, timeout: 1800, allowNonZero: false)
    }
}


public struct XKSwiftpmBuildTargetTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_build_target" }
    public var name: String { "SwiftPM Build Target" }
    public var description: String { "Builds a single SwiftPM `target` (or the whole package when omitted) in debug and returns compiler output." }
    public var capability: ToolCapability { .compilation }
    public var riskLevel: ToolRiskLevel { .execution }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Builds a single SwiftPM `target` (or the whole package when omitted) in debug and returns compiler output.", properties: ["target": JSONSchema(type: "string", description: "Target name (optional).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let target = AssistToolKit.string(input, "target") ?? ""
        guard !target.hasPrefix("-") else { return AssistToolKit.invalid("Invalid target.") }
        return AssistToolKit.processResult("SwiftPM Build Target", "swift", [target.isEmpty ? "build" : "build", target.isEmpty ? "--build-tests" : "--target", target.isEmpty ? "--quiet" : target], cwd: cwd, timeout: 1800, allowNonZero: false)
    }
}


public struct XKSwiftpmRunFilteredTestsTool: AssistTool {
    public init() {}
    public var id: String { "swiftpm_run_filtered_tests" }
    public var name: String { "SwiftPM Run Filtered Tests" }
    public var description: String { "Runs `swift test --filter <filter>` and returns the full test output (pass/fail per test)." }
    public var capability: ToolCapability { .testing }
    public var riskLevel: ToolRiskLevel { .execution }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Runs `swift test --filter <filter>` and returns the full test output (pass/fail per test).", properties: ["filter": JSONSchema(type: "string", description: "Test filter regex, e.g. MyTests/testLogin.")], required: ["filter"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let filter = AssistToolKit.string(input, "filter"), !filter.isEmpty, !filter.hasPrefix("-") else { return AssistToolKit.missing("filter") }
        return AssistToolKit.processResult("SwiftPM Run Filtered Tests", "swift", ["test", "--filter", filter], cwd: cwd, timeout: 1800, allowNonZero: true)
    }
}


public struct XKSwiftFormatLintCheckTool: AssistTool {
    public init() {}
    public var id: String { "swift_format_lint_check" }
    public var name: String { "Swift Format Lint" }
    public var description: String { "Lints Swift sources at `path` with `swift format lint --recursive` and returns diagnostics." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lints Swift sources at `path` with `swift format lint --recursive` and returns diagnostics.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rel = AssistToolKit.resolve(input, context: context).map { AssistToolKit.relative($0, context) } ?? "."
        return AssistToolKit.processResult("Swift Format Lint", "swift", ["format", "lint", "--recursive", rel], cwd: cwd, timeout: 300, allowNonZero: true)
    }
}


public struct XKSwiftFormatApplyTool: AssistTool {
    public init() {}
    public var id: String { "swift_format_apply" }
    public var name: String { "Swift Format Apply" }
    public var description: String { "Formats Swift sources at `path` in place with `swift format --in-place --recursive`." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Formats Swift sources at `path` in place with `swift format --in-place --recursive`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Swift Format Apply", "swift", ["format", "--in-place", "--recursive", rel], cwd: cwd, timeout: 300, allowNonZero: false)
    }
}


public struct XKSwiftTypecheckFileTool: AssistTool {
    public init() {}
    public var id: String { "swift_typecheck_file" }
    public var name: String { "Swift Typecheck File" }
    public var description: String { "Type-checks a standalone Swift file with `swiftc -typecheck` (for scripts and files without package dependencies)." }
    public var capability: ToolCapability { .compilation }
    public var riskLevel: ToolRiskLevel { .execution }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Type-checks a standalone Swift file with `swiftc -typecheck` (for scripts and files without package dependencies).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Swift Typecheck File", "xcrun", ["swiftc", "-typecheck", rel], cwd: cwd, timeout: 300, allowNonZero: true)
    }
}


public struct XKXcodeDeveloperDirTool: AssistTool {
    public init() {}
    public var id: String { "xcode_developer_dir" }
    public var name: String { "Xcode Developer Directory" }
    public var description: String { "Prints the active developer directory (xcode-select -p)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Prints the active developer directory (xcode-select -p).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Xcode Developer Directory", "xcode-select", ["-p"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKXcodebuildVersionInfoTool: AssistTool {
    public init() {}
    public var id: String { "xcodebuild_version_info" }
    public var name: String { "xcodebuild Version" }
    public var description: String { "Prints the installed Xcode toolchain version and build number." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Prints the installed Xcode toolchain version and build number.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("xcodebuild Version", "xcodebuild", ["-version"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKXcodebuildListJsonTool: AssistTool {
    public init() {}
    public var id: String { "xcodebuild_list_json" }
    public var name: String { "xcodebuild List" }
    public var description: String { "Lists targets, configurations and schemes of the project/workspace in the workspace root as JSON." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists targets, configurations and schemes of the project/workspace in the workspace root as JSON.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("xcodebuild List", "xcodebuild", ["-list", "-json"], cwd: cwd, timeout: 180, allowNonZero: false)
    }
}


public struct XKXcodebuildSdkListTool: AssistTool {
    public init() {}
    public var id: String { "xcodebuild_sdk_list" }
    public var name: String { "xcodebuild SDK List" }
    public var description: String { "Lists installed SDKs as JSON (xcodebuild -showsdks -json)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists installed SDKs as JSON (xcodebuild -showsdks -json).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("xcodebuild SDK List", "xcodebuild", ["-showsdks", "-json"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKXcodebuildBuildSettingsTool: AssistTool {
    public init() {}
    public var id: String { "xcodebuild_build_settings" }
    public var name: String { "xcodebuild Build Settings" }
    public var description: String { "Shows resolved build settings for `scheme` as JSON (optionally filtered by `setting_filter`)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows resolved build settings for `scheme` as JSON (optionally filtered by `setting_filter`).", properties: ["scheme": JSONSchema(type: "string", description: "Scheme name.")], required: ["scheme"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let scheme = AssistToolKit.string(input, "scheme"), !scheme.hasPrefix("-") else { return AssistToolKit.missing("scheme") }
        return AssistToolKit.processResult("xcodebuild Build Settings", "xcodebuild", ["-showBuildSettings", "-json", "-scheme", scheme], cwd: cwd, timeout: 300, allowNonZero: false)
    }
}


public struct XKSimctlDeviceListTool: AssistTool {
    public init() {}
    public var id: String { "simctl_device_list" }
    public var name: String { "Simulator Device List" }
    public var description: String { "Lists simulator devices and their states as JSON (xcrun simctl list devices --json)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists simulator devices and their states as JSON (xcrun simctl list devices --json).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Simulator Device List", "xcrun", ["simctl", "list", "devices", "--json"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSimctlRuntimeListTool: AssistTool {
    public init() {}
    public var id: String { "simctl_runtime_list" }
    public var name: String { "Simulator Runtime List" }
    public var description: String { "Lists installed simulator runtimes (xcrun simctl list runtimes)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists installed simulator runtimes (xcrun simctl list runtimes).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Simulator Runtime List", "xcrun", ["simctl", "list", "runtimes"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKXcrunFindToolTool: AssistTool {
    public init() {}
    public var id: String { "xcrun_find_tool" }
    public var name: String { "xcrun Find Tool" }
    public var description: String { "Locates a developer tool inside the active toolchain (xcrun --find <tool>)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Locates a developer tool inside the active toolchain (xcrun --find <tool>).", properties: ["tool": JSONSchema(type: "string", description: "Tool name, e.g. swift-format, lldb.")], required: ["tool"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let tool = AssistToolKit.string(input, "tool"), tool.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) }) else { return AssistToolKit.invalid("Invalid tool name.") }
        return AssistToolKit.processResult("xcrun Find Tool", "xcrun", ["--find", tool], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKPlistLintFileTool: AssistTool {
    public init() {}
    public var id: String { "plist_lint_file" }
    public var name: String { "Property List Lint" }
    public var description: String { "Validates a property list file's syntax with plutil -lint." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Validates a property list file's syntax with plutil -lint.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Property List Lint", "plutil", ["-lint", rel], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKPlistPrintFileTool: AssistTool {
    public init() {}
    public var id: String { "plist_print_file" }
    public var name: String { "Property List Print" }
    public var description: String { "Prints a property list (XML or binary) in human-readable form with plutil -p." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Prints a property list (XML or binary) in human-readable form with plutil -p.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Property List Print", "plutil", ["-p", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKCodesignInspectTool: AssistTool {
    public init() {}
    public var id: String { "codesign_inspect" }
    public var name: String { "Codesign Inspect" }
    public var description: String { "Shows code signature details (identity, team, entitlements summary) of an app/binary at `path`." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Shows code signature details (identity, team, entitlements summary) of an app/binary at `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Codesign Inspect", "codesign", ["-dv", "--verbose=4", rel], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKCodesignIdentitiesTool: AssistTool {
    public init() {}
    public var id: String { "codesign_identities" }
    public var name: String { "Code Signing Identities" }
    public var description: String { "Lists valid code-signing identities in the keychain (security find-identity -v -p codesigning)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists valid code-signing identities in the keychain (security find-identity -v -p codesigning).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Code Signing Identities", "security", ["find-identity", "-v", "-p", "codesigning"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKBinaryArchitecturesTool: AssistTool {
    public init() {}
    public var id: String { "binary_architectures" }
    public var name: String { "Binary Architectures" }
    public var description: String { "Lists CPU architectures in a Mach-O binary or library (lipo -info)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists CPU architectures in a Mach-O binary or library (lipo -info).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Binary Architectures", "lipo", ["-info", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKBinaryLinkedLibrariesTool: AssistTool {
    public init() {}
    public var id: String { "binary_linked_libraries" }
    public var name: String { "Binary Linked Libraries" }
    public var description: String { "Lists dynamic libraries a Mach-O binary links against (otool -L)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists dynamic libraries a Mach-O binary links against (otool -L).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Binary Linked Libraries", "otool", ["-L", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKBinaryExportedSymbolsTool: AssistTool {
    public init() {}
    public var id: String { "binary_exported_symbols" }
    public var name: String { "Binary Exported Symbols" }
    public var description: String { "Lists external defined symbols of a binary/object (nm -gU), demangled." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists external defined symbols of a binary/object (nm -gU), demangled.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("Binary Exported Symbols", "nm", ["-gUj", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKFileTypeDetectTool: AssistTool {
    public init() {}
    public var id: String { "file_type_detect" }
    public var name: String { "File Type Detect" }
    public var description: String { "Identifies a file's real type from its contents (file -b)." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Identifies a file's real type from its contents (file -b).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let raw = AssistToolKit.string(input, "path"), let target = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("A workspace-relative path is required.") }
        let rel = AssistToolKit.relative(target, context)
        return AssistToolKit.processResult("File Type Detect", "file", ["-b", rel], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSystemOsVersionTool: AssistTool {
    public init() {}
    public var id: String { "system_os_version" }
    public var name: String { "OS Version" }
    public var description: String { "Reports macOS product name, version and build (sw_vers)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports macOS product name, version and build (sw_vers).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("OS Version", "sw_vers", [], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSystemHardwareSummaryTool: AssistTool {
    public init() {}
    public var id: String { "system_hardware_summary" }
    public var name: String { "Hardware Summary" }
    public var description: String { "Reports machine model, CPU brand, core count and memory (sysctl)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports machine model, CPU brand, core count and memory (sysctl).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Hardware Summary", "sysctl", ["hw.model", "hw.ncpu", "hw.memsize", "machdep.cpu.brand_string"], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKSystemDiskFreeTool: AssistTool {
    public init() {}
    public var id: String { "system_disk_free" }
    public var name: String { "Disk Free Space" }
    public var description: String { "Reports free/used space for mounted volumes (df -h)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports free/used space for mounted volumes (df -h).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Disk Free Space", "df", ["-h"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSystemUptimeLoadTool: AssistTool {
    public init() {}
    public var id: String { "system_uptime_load" }
    public var name: String { "Uptime and Load" }
    public var description: String { "Reports uptime and load averages." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports uptime and load averages.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Uptime and Load", "uptime", [], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSystemTopProcessesTool: AssistTool {
    public init() {}
    public var id: String { "system_top_processes" }
    public var name: String { "Top Processes" }
    public var description: String { "Lists processes sorted by CPU usage (ps) with PID, CPU%, memory% and command." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists processes sorted by CPU usage (ps) with PID, CPU%, memory% and command.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Top Processes", "ps", ["-Arco", "pid,pcpu,pmem,comm"], cwd: cwd, timeout: 60, allowNonZero: false)
    }
}


public struct XKSystemListeningPortsTool: AssistTool {
    public init() {}
    public var id: String { "system_listening_ports" }
    public var name: String { "Listening TCP Ports" }
    public var description: String { "Lists processes listening on TCP ports (lsof -nP -iTCP -sTCP:LISTEN) — find dev servers and port conflicts." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists processes listening on TCP ports (lsof -nP -iTCP -sTCP:LISTEN) — find dev servers and port conflicts.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Listening TCP Ports", "lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKSystemLocateExecutableTool: AssistTool {
    public init() {}
    public var id: String { "system_locate_executable" }
    public var name: String { "Locate Executable" }
    public var description: String { "Finds every executable named `tool` on PATH (which -a)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds every executable named `tool` on PATH (which -a).", properties: ["tool": JSONSchema(type: "string", description: "Executable name.")], required: ["tool"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        guard let tool = AssistToolKit.string(input, "tool"), tool.allSatisfy({ $0.isLetter || $0.isNumber || "-_.+".contains($0) }) else { return AssistToolKit.invalid("Invalid tool name.") }
        return AssistToolKit.processResult("Locate Executable", "which", ["-a", tool], cwd: cwd, timeout: 60, allowNonZero: true)
    }
}


public struct XKSystemDirectoryUsageTool: AssistTool {
    public init() {}
    public var id: String { "system_directory_usage" }
    public var name: String { "Directory Disk Usage" }
    public var description: String { "Reports disk usage of `path` and its immediate children (du -sh)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports disk usage of `path` and its immediate children (du -sh).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative path.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        let rel = AssistToolKit.resolve(input, context: context).map { AssistToolKit.relative($0, context) } ?? "."
        return AssistToolKit.processResult("Directory Disk Usage", "du", ["-sh", rel], cwd: cwd, timeout: 300, allowNonZero: false)
    }
}


public struct XKHomebrewInstalledPackagesTool: AssistTool {
    public init() {}
    public var id: String { "homebrew_installed_packages" }
    public var name: String { "Homebrew Installed Packages" }
    public var description: String { "Lists installed Homebrew formulae with versions (brew list --versions)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists installed Homebrew formulae with versions (brew list --versions).", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let cwd = context.workspaceRoot
        return AssistToolKit.processResult("Homebrew Installed Packages", "brew", ["list", "--versions"], cwd: cwd, timeout: 120, allowNonZero: false)
    }
}
