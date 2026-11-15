import ArgumentParser
import Foundation
import SpacesEngine

struct Provenance: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Verify the provenance of a revision")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Revision to verify") var rev: String

    func run() throws {
        try SpacesOutput.apply(output, command: "Provenance")
        let api = try openAPI(repoOptions)
        let checks = try api.verifyProvenance(rev: rev)
        if output.jsonRequested { printJSON(checks); return }
        for check in checks {
            print("\(check.passed ? "PASS" : "FAIL") \(check.name): \(check.detail)")
        }
        let failed = checks.filter { !$0.passed }
        if !failed.isEmpty {
            throw SpacesError.invalidArgument("provenance verification failed: \(failed.count) check(s) failed")
        }
    }
}

struct Policy: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Repository policy operations",
        subcommands: [PolicyShow.self, PolicyCheck.self])
}

struct PolicyShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show the repository policy")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "PolicyShow")
        let api = try openAPI(repoOptions)
        let policy = try api.repositoryPolicy()
        if output.jsonRequested { printJSON(policy); return }
        for rule in policy.rules {
            print("\(rule.id) \(rule.kind.rawValue) = \(rule.value) (\(rule.enabled ? "enabled" : "disabled"))")
        }
        if policy.rules.isEmpty { print("no policy rules") }
    }
}

struct PolicyCheck: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "check", abstract: "Check an operation against the repository policy")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Operation: commit, branch-create, branch-delete, push, tag") var operation: String
    @Option(name: .long, help: "Commit message to check") var message: String?
    @Option(name: .long, help: "Path involved in the operation") var path: [String] = []

    func run() throws {
        try SpacesOutput.apply(output, command: "PolicyCheck")
        let api = try openAPI(repoOptions)
        guard let parsed = PolicyEngineOps.PolicyOperation(rawValue: operation) else {
            throw SpacesError.invalidArgument("unknown policy operation: \(operation)")
        }
        let details = PolicyEngineOps.PolicyOperationDetails(message: message, paths: path)
        let violations = try api.checkPolicy(operation: parsed, details: details)
        if output.jsonRequested { printJSON(violations); return }
        for violation in violations {
            print("\(violation.ruleID): \(violation.message)")
        }
        if violations.isEmpty {
            print("policy check passed")
        } else {
            throw SpacesError.invalidArgument("policy check failed: \(violations.count) violation(s)")
        }
    }
}

struct SecurityReport: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "security-report", abstract: "Generate a security report")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "SecurityReport")
        let api = try openAPI(repoOptions)
        let report = try api.generateSecurityReport()
        if output.jsonRequested { printJSON(report); return }
        print("generated at: \(report.generatedAt)")
        print("secret findings: \(report.secretFindingCount)")
        let passed = report.provenance.filter { $0.allPassed }.count
        print("provenance: \(passed)/\(report.provenance.count) commit(s) fully passed")
        print("audit events: \(report.auditEventCount)")
        for (operation, count) in report.auditEventsByOperation.sorted(by: { $0.key < $1.key }) {
            print("  \(operation): \(count)")
        }
        for (label, count) in report.classificationSummary.sorted(by: { $0.key < $1.key }) {
            print("classification \(label): \(count)")
        }
        print("policy violations: \(report.policyViolations.count)")
        for violation in report.policyViolations {
            print("  \(violation.ruleID): \(violation.message)")
        }
    }
}

struct SecretHistory: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "secret-history", abstract: "List secrets found across history")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Option(name: .long, help: "Maximum findings") var limit: Int = 100

    func run() throws {
        try SpacesOutput.apply(output, command: "SecretHistory")
        let api = try openAPI(repoOptions)
        let findings = try api.secretHistory(limit: limit)
        if output.jsonRequested { printJSON(findings); return }
        for finding in findings {
            print("\(finding.commit) \(finding.path): \(finding.patternName)")
        }
        if findings.isEmpty {
            print("no secrets found in history")
        } else {
            throw SpacesError.invalidArgument("\(findings.count) secret(s) found in history")
        }
    }
}

struct Ownership: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Code ownership operations",
        subcommands: [OwnershipRules.self, OwnershipOwners.self])
}

struct OwnershipRules: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rules", abstract: "List ownership rules")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "OwnershipRules")
        let api = try openAPI(repoOptions)
        let rules = try api.ownershipRules()
        if output.jsonRequested { printJSON(rules); return }
        for rule in rules {
            print("\(rule.pattern) -> \(rule.owners.joined(separator: ", "))")
        }
        if rules.isEmpty { print("no ownership rules") }
    }
}

struct OwnershipOwners: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "owners", abstract: "Show the owners of a path")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Path to look up") var path: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "OwnershipOwners")
        let api = try openAPI(repoOptions)
        let owners = try api.ownersOf(path: path)
        if owners.isEmpty {
            print("no owners for \(path)")
        } else {
            for owner in owners { print(owner) }
        }
    }
}

struct Review: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Review operations",
        subcommands: [ReviewCreate.self, ReviewList.self, ReviewStatusCmd.self, ReviewApprove.self])
}

struct ReviewCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a review")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Review title") var title: String
    @Option(name: .long, help: "Base revision") var base: String
    @Option(name: .long, help: "Head revision") var head: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "ReviewCreate")
        let api = try openAPI(repoOptions)
        let review = try api.createReview(title: title, base: base, head: head)
        print("created review \(review.id): \(review.title)")
    }
}

struct ReviewList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List reviews")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "ReviewList")
        let api = try openAPI(repoOptions)
        let reviews = try api.listReviews()
        if output.jsonRequested { printJSON(reviews); return }
        for review in reviews {
            print("\(review.id) [\(review.status.rawValue)] \(review.title) (\(review.baseRev.prefix(7))..\(review.headRev.prefix(7)), \(review.approvals.count) approval(s))")
        }
        if reviews.isEmpty { print("no reviews") }
    }
}

struct ReviewStatusCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show a review's status")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Review id") var id: String

    func run() throws {
        try SpacesOutput.apply(output, command: "ReviewStatusCmd")
        let api = try openAPI(repoOptions)
        let status = try api.reviewStatus(id: id)
        if output.jsonRequested {
            struct Row: Encodable { var id: String; var status: String }
            printJSON(Row(id: id, status: status.rawValue))
            return
        }
        print("\(id): \(status.rawValue)")
    }
}

struct ReviewApprove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "approve", abstract: "Approve a review")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Review id") var id: String
    @Option(name: .long, help: "Reviewer name") var reviewer: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "ReviewApprove")
        let api = try openAPI(repoOptions)
        let review = try api.approveReview(id: id, reviewer: reviewer)
        print("review \(review.id) approved by \(reviewer): \(review.status.rawValue)")
    }
}

struct ReviewStatus: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "review-status", abstract: "Show a review's status")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Review id") var id: String

    func run() throws {
        try SpacesOutput.apply(output, command: "ReviewStatus")
        let api = try openAPI(repoOptions)
        let status = try api.reviewStatus(id: id)
        if output.jsonRequested {
            struct Row: Encodable { var id: String; var status: String }
            printJSON(Row(id: id, status: status.rawValue))
            return
        }
        print("\(id): \(status.rawValue)")
    }
}

struct Discussion: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Review discussion operations",
        subcommands: [DiscussionAdd.self, DiscussionList.self, DiscussionResolve.self])
}

struct DiscussionAdd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a comment to a review")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Review id") var review: String
    @Argument(help: "File path") var path: String
    @Argument(help: "Line number") var line: Int
    @Argument(help: "Comment body") var body: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "DiscussionAdd")
        let api = try openAPI(repoOptions)
        let comment = try api.addComment(review: review, path: path, line: line, body: body)
        print("added comment \(comment.id) on \(comment.path):\(comment.line)")
    }
}

struct DiscussionList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List comments on a review")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Review id") var review: String

    func run() throws {
        try SpacesOutput.apply(output, command: "DiscussionList")
        let api = try openAPI(repoOptions)
        let comments = try api.listComments(review: review)
        if output.jsonRequested { printJSON(comments); return }
        for comment in comments {
            print("\(comment.id) \(comment.path):\(comment.line) \(comment.author) (\(comment.resolved ? "resolved" : "open")): \(comment.body)")
        }
        if comments.isEmpty { print("no comments on review \(review)") }
    }
}

struct DiscussionResolve: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "resolve", abstract: "Resolve a comment on a review")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Review id") var review: String
    @Argument(help: "Comment id") var id: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "DiscussionResolve")
        let api = try openAPI(repoOptions)
        let comment = try api.resolveComment(review: review, id: id)
        print("resolved comment \(comment.id) on \(comment.path):\(comment.line)")
    }
}

struct Notifications: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Notification operations",
        subcommands: [NotificationsRules.self, NotificationsPending.self, NotificationsSeen.self])
}

struct NotificationsRules: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rules", abstract: "List notification rules")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "NotificationsRules")
        let api = try openAPI(repoOptions)
        let rules = try api.notificationRules()
        if output.jsonRequested { printJSON(rules); return }
        for rule in rules {
            print("\(rule.event.rawValue): \(rule.enabled ? "enabled" : "disabled")")
        }
        if rules.isEmpty { print("no notification rules") }
    }
}

struct NotificationsPending: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pending", abstract: "List pending notifications")
    @OptionGroup var repoOptions: RepoOptions

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "NotificationsPending")
        let api = try openAPI(repoOptions)
        let pending = try api.pendingNotifications()
        for notification in pending {
            print("\(notification.timestamp) [\(notification.event.rawValue)] \(notification.message)")
        }
        if pending.isEmpty { print("no pending notifications") }
    }
}

struct NotificationsSeen: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "seen", abstract: "Mark pending notifications as seen")
    @OptionGroup var repoOptions: RepoOptions

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "NotificationsSeen")
        let api = try openAPI(repoOptions)
        try api.markNotificationsSeen()
        print("notifications marked seen")
    }
}

struct Backup: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Backup operations",
        subcommands: [BackupCreate.self, BackupVerifyCmd.self, BackupRestoreCmd.self, BackupList.self])
}

struct BackupCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a backup")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Backup destination path") var path: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BackupCreate")
        let api = try openAPI(repoOptions)
        let manifest = try api.createBackup(to: path)
        print("backup \(manifest.id) created at \(path): \(manifest.objects.count) object(s)")
    }
}

struct BackupVerifyCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Verify a backup")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Backup path") var path: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BackupVerifyCmd")
        let api = try openAPI(repoOptions)
        let report = try api.verifyBackup(url: path)
        print("backup OK: \(report.objectCount) object(s), \(report.refs.count) ref(s)")
    }
}

struct BackupRestoreCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "restore", abstract: "Restore a backup")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Backup path") var path: String

    func run() throws {
        try SpacesOutput.apply(output, command: "BackupRestoreCmd")
        try requireDestructiveConfirmation(output, operation: "backup restore")
        let api = try openAPI(repoOptions)
        let report = try api.restoreBackup(url: path)
        print("backup restored from \(path): \(report.objectCount) object(s), \(report.refs.count) ref(s)")
    }
}

struct BackupList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List backups")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "BackupList")
        let api = try openAPI(repoOptions)
        let backups = try api.backups()
        if output.jsonRequested { printJSON(backups); return }
        for backup in backups {
            print("\(backup.timestamp) \(backup.id): \(backup.objects.count) object(s)")
        }
        if backups.isEmpty { print("no backups") }
    }
}

struct BackupVerify: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "backup-verify", abstract: "Verify a backup")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Backup path") var path: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BackupVerify")
        let api = try openAPI(repoOptions)
        let report = try api.verifyBackup(url: path)
        print("backup OK: \(report.objectCount) object(s), \(report.refs.count) ref(s)")
    }
}

struct BackupRestore: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "backup-restore", abstract: "Restore a backup")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Backup path") var path: String

    func run() throws {
        try SpacesOutput.apply(output, command: "BackupRestore")
        try requireDestructiveConfirmation(output, operation: "backup-restore")
        let api = try openAPI(repoOptions)
        let report = try api.restoreBackup(url: path)
        print("backup restored from \(path): \(report.objectCount) object(s), \(report.refs.count) ref(s)")
    }
}

struct StorageHeatmap: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "storage-heatmap", abstract: "Show a storage heatmap")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "StorageHeatmap")
        let api = try openAPI(repoOptions)
        let heatmap = try api.storageHeatmap()
        if output.jsonRequested { printJSON(heatmap); return }
        print("objects: \(heatmap.totalObjects), bytes: \(heatmap.totalBytes)")
        print("reachable: \(heatmap.reachableBytes) bytes, unreachable: \(heatmap.unreachableBytes) bytes")
        print("by type:")
        for bucket in heatmap.byType {
            print("  \(bucket.label): \(bucket.count) object(s), \(bucket.bytes) bytes")
        }
        print("by size:")
        for bucket in heatmap.sizeBands {
            print("  \(bucket.label): \(bucket.count) object(s), \(bucket.bytes) bytes")
        }
        print("by age:")
        for bucket in heatmap.ageBands {
            print("  \(bucket.label): \(bucket.count) object(s), \(bucket.bytes) bytes")
        }
    }
}

struct StorageProfile: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "storage-profile", abstract: "Compaction profile operations",
        subcommands: [StorageProfileList.self, StorageProfileApply.self])
}

struct StorageProfileList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List compaction profiles")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "StorageProfileList")
        let api = try openAPI(repoOptions)
        let profiles = try api.compactionProfiles()
        if output.jsonRequested { printJSON(profiles); return }
        for profile in profiles {
            print("\(profile.name) (\(profile.kind)): rebuild-index \(profile.rebuildIndex), prune-unreachable \(profile.pruneUnreachable), prune-days \(profile.pruneDays)")
        }
        if profiles.isEmpty { print("no compaction profiles") }
    }
}

struct StorageProfileApply: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Apply a compaction profile")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Profile name") var name: String

    func run() throws {
        try SpacesOutput.apply(output, command: "StorageProfileApply")
        try requireDestructiveConfirmation(output, operation: "storage-profile apply")
        let api = try openAPI(repoOptions)
        let result = try api.applyCompactionProfile(name: name)
        print("applied profile \(result.profile): \(result.objectsBefore) -> \(result.objectsAfter) objects, pruned \(result.pruned)")
    }
}

struct WorkspaceTemplate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "workspace-template", abstract: "Workspace template operations",
        subcommands: [WorkspaceTemplateCreate.self, WorkspaceTemplateList.self, WorkspaceTemplateApply.self])
}

struct WorkspaceTemplateCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a workspace template")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Template name") var name: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "WorkspaceTemplateCreate")
        let repo = try repoOptions.openRepo()
        let api = SpacesAPI(repo: repo)
        let config = WorkspaceTemplateOps.Config(defaultBranch: repo.config.core.defaultBranch)
        let template = try api.createWorkspaceTemplate(name: name, config: config)
        print("created workspace template \(template.name) (default branch \(template.defaultBranch))")
    }
}

struct WorkspaceTemplateList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List workspace templates")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "WorkspaceTemplateList")
        let api = try openAPI(repoOptions)
        let templates = try api.workspaceTemplates()
        if output.jsonRequested { printJSON(templates); return }
        for template in templates {
            print("\(template.name) (default branch \(template.defaultBranch))")
        }
        if templates.isEmpty { print("no workspace templates") }
    }
}

struct WorkspaceTemplateApply: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Apply a workspace template")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Template name") var name: String

    func run() throws {
        try SpacesOutput.apply(output, command: "WorkspaceTemplateApply")
        try requireDestructiveConfirmation(output, operation: "workspace-template apply")
        let api = try openAPI(repoOptions)
        try api.applyWorkspaceTemplate(name: name)
        print("applied workspace template \(name)")
    }
}

struct Automation: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Automation pipeline operations",
        subcommands: [AutomationList.self, AutomationRun.self])
}

struct AutomationList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List automation pipelines")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "AutomationList")
        let api = try openAPI(repoOptions)
        let pipelines = try api.automationPipelines()
        if output.jsonRequested { printJSON(pipelines); return }
        for pipeline in pipelines {
            print("\(pipeline.id) [\(pipeline.event.rawValue)] \(pipeline.enabled ? "enabled" : "disabled"): \(pipeline.command)")
        }
        if pipelines.isEmpty { print("no automation pipelines") }
    }
}

struct AutomationRun: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Run automation pipelines for an event")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Event: post-commit, post-merge, post-checkout") var event: String

    func run() throws {
        try SpacesOutput.apply(output, command: "AutomationRun")
        let api = try openAPI(repoOptions)
        guard let parsed = AutomationOps.AutomationEvent(rawValue: event) else {
            throw SpacesError.invalidArgument("unknown automation event: \(event)")
        }
        let results = try api.runAutomation(event: parsed)
        if output.jsonRequested { printJSON(results); return }
        for result in results {
            print("\(result.pipelineId) [\(result.event.rawValue)] \(result.status.rawValue): \(result.reason)")
        }
        if results.isEmpty { print("no pipelines ran for \(event)") }
    }
}

struct PatchCollection: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "patch-collection", abstract: "Patch collection operations",
        subcommands: [PatchCollectionCreate.self, PatchCollectionList.self, PatchCollectionApply.self])
}

struct PatchCollectionCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a patch collection")
    @OptionGroup var repoOptions: RepoOptions
    @Argument(help: "Collection name") var name: String
    @Option(name: .long, help: "From revision") var from: String
    @Option(name: .long, help: "To revision") var to: String

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "PatchCollectionCreate")
        let api = try openAPI(repoOptions)
        let collection = try api.createPatchCollection(name: name, from: from, to: to)
        print("created patch collection \(collection.name): \(collection.patches.count) patch(es)")
    }
}

struct PatchCollectionList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List patch collections")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "PatchCollectionList")
        let api = try openAPI(repoOptions)
        let collections = try api.patchCollections()
        if output.jsonRequested { printJSON(collections); return }
        for collection in collections {
            print("\(collection.name): \(collection.patches.count) patch(es)")
        }
        if collections.isEmpty { print("no patch collections") }
    }
}

struct PatchCollectionApply: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Apply a patch collection")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Collection name") var name: String

    func run() throws {
        try SpacesOutput.apply(output, command: "PatchCollectionApply")
        try requireDestructiveConfirmation(output, operation: "patch-collection apply")
        let api = try openAPI(repoOptions)
        let applied = try api.applyPatchCollection(name: name)
        for path in applied { print("applied \(path)") }
        if applied.isEmpty { print("nothing applied from patch collection \(name)") }
    }
}

struct SymbolHistory: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "symbol-history", abstract: "Show a symbol's history in a file")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "Symbol name") var symbol: String
    @Option(name: .long, help: "File path to trace the symbol in") var path: String = ""

    func run() throws {
        try SpacesOutput.apply(output, command: "SymbolHistory")
        guard !path.isEmpty else {
            throw SpacesError.invalidArgument("symbol-history requires --path")
        }
        let api = try openAPI(repoOptions)
        let entries = try api.symbolHistory(symbol: symbol, path: path)
        if output.jsonRequested { printJSON(entries); return }
        for entry in entries {
            print("\(entry.commit.hex.prefix(7)) \(entry.path):\(entry.declaration.line) \(entry.declaration.signature) (\(entry.message))")
        }
        if entries.isEmpty { print("no history for symbol \(symbol) in \(path)") }
    }
}

struct ApiCompatibility: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "api-compatibility", abstract: "Compare the public API surface between two revisions")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Argument(help: "From revision") var from: String
    @Argument(help: "To revision") var to: String
    @Flag(name: .long, help: "Allow breaking changes") var allowBreaking: Bool = false

    func run() throws {
        try SpacesOutput.apply(output, command: "ApiCompatibility")
        let api = try openAPI(repoOptions)
        let changes = try api.apiCompatibilityBetween(from: from, to: to)
        if output.jsonRequested { printJSON(changes); return }
        for change in changes {
            let flag = change.breaking ? " BREAKING" : ""
            print("\(change.change.rawValue) \(change.kind.rawValue) \(change.name) \(change.path)\(flag)")
        }
        if changes.isEmpty { print("no API changes between \(from) and \(to)") }
        if changes.contains(where: { $0.breaking }) && !allowBreaking {
            throw SpacesError.invalidArgument("breaking API changes found between \(from) and \(to)")
        }
    }
}

struct TestProvenance: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "test-provenance", abstract: "Test provenance operations",
        subcommands: [TestProvenanceRecord.self, TestProvenanceList.self])
}

struct TestProvenanceRecord: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "record", abstract: "Record a test result for a commit")
    @OptionGroup var repoOptions: RepoOptions
    @Option(name: .long, help: "Commit revision") var commit: String
    @Option(name: .long, help: "Test suite name") var suite: String
    @Option(name: .long, help: "Tests passed") var passed: Int = 0
    @Option(name: .long, help: "Tests failed") var failed: Int = 0

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "TestProvenanceRecord")
        let repo = try repoOptions.openRepo()
        let api = SpacesAPI(repo: repo)
        let oid = try repo.resolveRevision(commit)
        try api.recordTestResult(commit: oid, suite: suite, passed: passed, failed: failed)
        print("recorded test result for \(oid.hex.prefix(7)): \(suite) passed \(passed), failed \(failed)")
    }
}

struct TestProvenanceList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List test results for a commit")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Option(name: .long, help: "Commit revision") var commit: String

    func run() throws {
        try SpacesOutput.apply(output, command: "TestProvenanceList")
        let repo = try repoOptions.openRepo()
        let api = SpacesAPI(repo: repo)
        let oid = try repo.resolveRevision(commit)
        let records = try api.testResultsFor(commit: oid)
        if output.jsonRequested { printJSON(records); return }
        for record in records {
            print("\(record.timestamp) \(record.suite): passed \(record.passed), failed \(record.failed)")
        }
        if records.isEmpty { print("no test results for \(oid.hex.prefix(7))") }
    }
}

struct BuildImpact: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build-impact", abstract: "Build impact operations",
        subcommands: [BuildImpactRecord.self, BuildImpactHistory.self])
}

struct BuildImpactRecord: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "record", abstract: "Record a build result for a commit")
    @OptionGroup var repoOptions: RepoOptions
    @Option(name: .long, help: "Commit revision") var commit: String
    @Option(name: .long, help: "Build result: success, failure") var result: String
    @Option(name: .long, help: "Build duration in milliseconds") var durationMs: Int64 = 0
    @Option(name: .long, help: "Failure message (repeatable)") var failure: [String] = []

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "BuildImpactRecord")
        let repo = try repoOptions.openRepo()
        let api = SpacesAPI(repo: repo)
        let oid = try repo.resolveRevision(commit)
        guard let parsed = BuildImpactOps.BuildResult(rawValue: result) else {
            throw SpacesError.invalidArgument("unknown build result: \(result)")
        }
        try api.recordBuildResult(commit: oid, result: parsed, durationMs: durationMs, failures: failure)
        print("recorded build result for \(oid.hex.prefix(7)): \(parsed.rawValue) (\(durationMs) ms)")
    }
}

struct BuildImpactHistory: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "history", abstract: "Show build history for a commit")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions
    @Option(name: .long, help: "Commit revision") var commit: String

    func run() throws {
        try SpacesOutput.apply(output, command: "BuildImpactHistory")
        let repo = try repoOptions.openRepo()
        let api = SpacesAPI(repo: repo)
        let oid = try repo.resolveRevision(commit)
        let records = try api.buildHistory(commit: oid)
        if output.jsonRequested { printJSON(records); return }
        for record in records {
            print("\(record.timestamp) \(record.result.rawValue) (\(record.durationMs) ms): \(record.failures.joined(separator: "; "))")
        }
        if records.isEmpty { print("no build history for \(oid.hex.prefix(7))") }
    }
}

struct Performance: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Profile core repository operations")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    struct Report: Encodable {
        var samples: [PerformanceProfilerOps.ProfileSample]
        var summaries: [PerformanceProfilerOps.ProfileSummary]
    }

    func run() throws {
        try SpacesOutput.apply(output, command: "Performance")
        let api = try openAPI(repoOptions)
        var samples: [PerformanceProfilerOps.ProfileSample] = []
        for operation in PerformanceProfilerOps.ProfileOperation.allCases {
            samples.append(try api.profileOperation(operation))
        }
        let summaries = try api.performanceProfile()
        if output.jsonRequested { printJSON(Report(samples: samples, summaries: summaries)); return }
        for sample in samples {
            print("\(sample.operation): \(sample.durationMs) ms, \(sample.objectCount) object(s), \(sample.bytes) bytes")
        }
        print("aggregates:")
        for summary in summaries {
            print("  \(summary.operation): \(summary.samples) sample(s), avg \(String(format: "%.1f", summary.averageDurationMs)) ms, min \(summary.minDurationMs) ms, max \(summary.maxDurationMs) ms")
        }
    }
}

struct OperationUndo: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "operation-undo", abstract: "Operation undo operations",
        subcommands: [OperationUndoList.self, OperationUndoUndo.self])
}

struct OperationUndoList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List undoable operations")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "OperationUndoList")
        let api = try openAPI(repoOptions)
        let operations = try api.undoableOperations()
        if output.jsonRequested { printJSON(operations); return }
        for operation in operations {
            print("\(operation.timestamp) \(operation.id) \(operation.operation) \(operation.target)")
        }
        if operations.isEmpty { print("no undoable operations") }
    }
}

struct OperationUndoUndo: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "undo", abstract: "Undo the last undoable operation")
    @OptionGroup var repoOptions: RepoOptions
    @OptionGroup var output: OutputOptions

    func run() throws {
        try SpacesOutput.apply(output, command: "OperationUndoUndo")
        try requireDestructiveConfirmation(output, operation: "operation-undo undo")
        let api = try openAPI(repoOptions)
        let record = try api.undoLast()
        print("undid \(record.operation) \(record.target) (\(record.id))")
    }
}

struct History: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show commit history (alias for log)")
    @OptionGroup var repoOptions: RepoOptions

    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "History")
        var cmd = try Log.parseAsRoot(["--repo", repoOptions.repo ?? "."])
        try cmd.run()
    }
}
