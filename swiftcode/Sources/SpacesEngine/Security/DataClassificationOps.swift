import Foundation

public struct DataClassificationOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let rulesRelativePath = "security/classification.json"

    public struct ClassificationCategory: Codable, Sendable {
        public var name: String
        public var pathPatterns: [String]
        public var contentPatterns: [String]

        public init(name: String, pathPatterns: [String] = [], contentPatterns: [String] = []) {
            self.name = name
            self.pathPatterns = pathPatterns
            self.contentPatterns = contentPatterns
        }
    }

    public struct ClassificationRuleSet: Codable, Sendable {
        public var categories: [ClassificationCategory]

        public init(categories: [ClassificationCategory] = []) {
            self.categories = categories
        }
    }

    public struct ClassificationResult: Codable, Sendable {
        public var path: String
        public var categories: [String]

        public init(path: String, categories: [String]) {
            self.path = path
            self.categories = categories
        }
    }

    public func classificationRules() throws -> ClassificationRuleSet {
        try SecurityFileStore.load(repo: repo, relativePath: Self.rulesRelativePath)
            ?? ClassificationRuleSet()
    }

    public func setClassificationRules(_ rules: ClassificationRuleSet) throws {
        for category in rules.categories {
            for pattern in category.contentPatterns {
                guard (try? NSRegularExpression(pattern: pattern)) != nil else {
                    throw SpacesError.invalidArgument(
                        "category \(category.name): invalid content pattern \(pattern)")
                }
            }
        }
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.rulesRelativePath, value: rules)
        }
    }

    public func classify(path: String, content: String) throws -> [String] {
        let rules = try classificationRules()
        var matched: [String] = []
        for category in rules.categories {
            let pathHit = category.pathPatterns.contains {
                securityGlobMatch(pattern: $0, value: path)
            }
            let contentHit = category.contentPatterns.contains {
                securityRegexMatches(pattern: $0, text: content)
            }
            if pathHit || contentHit {
                matched.append(category.name)
            }
        }
        return matched
    }

    public func classifyRepository() throws -> [ClassificationResult] {
        let rules = try classificationRules()
        guard !rules.categories.isEmpty else { return [] }
        let index = try repo.index()
        var results: [ClassificationResult] = []
        for path in index.entries.keys.sorted() {
            guard let entry = index.entries[path],
                  let data = try? repo.blobData(entry.oid),
                  !DiffEngine.isBinary(data),
                  let text = String(data: data, encoding: .utf8) else { continue }
            var matched: [String] = []
            for category in rules.categories {
                let pathHit = category.pathPatterns.contains {
                    securityGlobMatch(pattern: $0, value: path)
                }
                let contentHit = category.contentPatterns.contains {
                    securityRegexMatches(pattern: $0, text: text)
                }
                if pathHit || contentHit {
                    matched.append(category.name)
                }
            }
            if !matched.isEmpty {
                results.append(ClassificationResult(path: path, categories: matched))
            }
        }
        return results
    }
}
