import Foundation

public struct WorkspaceTemplateOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct Config: Codable, Sendable {
        public var defaultBranch: String
        public var reviewPolicy: ReviewPolicyOps.Policy
        public var ownershipRules: [OwnershipOps.Rule]
        public var ignorePatterns: [String]

        public init(defaultBranch: String = "main",
                    reviewPolicy: ReviewPolicyOps.Policy = ReviewPolicyOps.Policy(),
                    ownershipRules: [OwnershipOps.Rule] = [],
                    ignorePatterns: [String] = []) {
            self.defaultBranch = defaultBranch
            self.reviewPolicy = reviewPolicy
            self.ownershipRules = ownershipRules
            self.ignorePatterns = ignorePatterns
        }
    }

    public struct Template: Codable, Sendable {
        public var name: String
        public var defaultBranch: String
        public var reviewPolicy: ReviewPolicyOps.Policy
        public var ownershipRules: [OwnershipOps.Rule]
        public var ignorePatterns: [String]

        public init(name: String, config: Config) {
            self.name = name
            self.defaultBranch = config.defaultBranch
            self.reviewPolicy = config.reviewPolicy
            self.ownershipRules = config.ownershipRules
            self.ignorePatterns = config.ignorePatterns
        }

        public var config: Config {
            Config(defaultBranch: defaultBranch, reviewPolicy: reviewPolicy,
                   ownershipRules: ownershipRules, ignorePatterns: ignorePatterns)
        }
    }

    private var templatesDirectory: URL {
        repo.metaURL.appendingPathComponent("templates")
    }

    private func url(for name: String) -> URL {
        templatesDirectory.appendingPathComponent("\(name).json")
    }

    public static func isValidTemplateName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("..")
            && !name.contains("\n")
    }

    @discardableResult
    public func createTemplate(name: String, config: Config) throws -> Template {
        guard Self.isValidTemplateName(name) else {
            throw SpacesError.invalidArgument("invalid workspace template name \(name)")
        }
        guard !config.defaultBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpacesError.invalidArgument("template default branch must not be empty")
        }
        let template = Template(name: name, config: config)
        return try repo.performTransaction(steps: ["template-create:\(name)"]) {
            if FileManager.default.fileExists(atPath: url(for: name).path) {
                throw SpacesError.invalidArgument("workspace template already exists: \(name)")
            }
            try CollaborationStore.save(template, to: url(for: name))
            return template
        }
    }

    public func template(_ name: String) throws -> Template {
        try CollaborationStore.loadRequired(url(for: name),
                                           label: "workspace template \(name)")
    }

    public func workspaceTemplates() throws -> [Template] {
        var result: [Template] = []
        for file in try CollaborationStore.listJSONFiles(in: templatesDirectory) {
            if let stored: Template = try CollaborationStore.load(file) {
                result.append(stored)
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    public func applyTemplate(name: String) throws {
        let template = try template(name)
        try repo.performTransaction(steps: ["template-apply:\(name)"]) {
            if let headOID = try repo.refs.headOID(objects: repo.objects) {
                if try repo.refs.readRef("refs/heads/\(template.defaultBranch)") == nil {
                    _ = try BranchOps(repo: repo).create(
                        template.defaultBranch, at: headOID.hex)
                }
            } else {
                try repo.refs.setHEAD(ref: "refs/heads/\(template.defaultBranch)")
            }
            try ReviewPolicyOps(repo: repo).setReviewPolicy(template.reviewPolicy)
            try OwnershipOps(repo: repo).setOwnershipRules(template.ownershipRules)
            try appendIgnorePatterns(template.ignorePatterns)
            var config = repo.config
            config.core.defaultBranch = template.defaultBranch
            try repo.saveConfig(config)
        }
    }

    private func appendIgnorePatterns(_ patterns: [String]) throws {
        let trimmed = patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        let fileURL = repo.worktreeURL
            .appendingPathComponent(RepositoryFormat.ignoreFileName)
        let current = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var lines = current.isEmpty ? [] : current.components(separatedBy: "\n")
        for pattern in trimmed where !lines.contains(pattern) {
            lines.append(pattern)
        }
        try CollaborationStore.saveText(lines.joined(separator: "\n") + "\n", to: fileURL)
    }
}
