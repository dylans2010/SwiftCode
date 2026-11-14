import Foundation

public struct ChangeValidationOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct ValidationPlanEntry: Codable, Sendable, Equatable {
        public var component: String
        public var testSuite: String
        public var testSuiteExists: Bool

        public init(component: String, testSuite: String, testSuiteExists: Bool) {
            self.component = component
            self.testSuite = testSuite
            self.testSuiteExists = testSuiteExists
        }
    }

    public func affectedComponents(rev: String) throws -> [String] {
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        var paths: [String] = []
        if let parent = commit.parents.first {
            let diffs = try DiffOps(repo: repo).commitDiff(parent.hex, rev)
            paths = diffs.map { $0.newPath }
        } else {
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            paths = Array(flat.keys)
        }
        var components = Set<String>()
        for path in paths {
            if let component = component(for: path) {
                components.insert(component)
            }
        }
        return components.sorted()
    }

    public func validationPlan(rev: String) throws -> [ValidationPlanEntry] {
        let components = try affectedComponents(rev: rev)
        let flat = try ToolingStorage.flatTree(repo: repo, rev: rev)
        return components.map { component in
            let suite = component + "Tests"
            let exists = flat.keys.contains { key in
                key.hasPrefix("Tests/" + suite + "/") || key.contains("/Tests/" + suite + "/")
            }
            return ValidationPlanEntry(component: component, testSuite: suite, testSuiteExists: exists)
        }
    }

    public static func component(for path: String) -> String? {
        let segments = path.split(separator: "/").map(String.init)
        guard !segments.isEmpty else { return nil }
        if let sourcesIndex = segments.firstIndex(of: "Sources"), sourcesIndex + 1 < segments.count {
            return segments[sourcesIndex + 1]
        }
        if let testsIndex = segments.firstIndex(of: "Tests"), testsIndex + 1 < segments.count {
            let target = segments[testsIndex + 1]
            if target.hasSuffix("Tests") {
                return String(target.dropLast("Tests".count))
            }
            return target
        }
        return segments[0]
    }
}
