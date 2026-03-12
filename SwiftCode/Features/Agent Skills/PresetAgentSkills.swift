import Foundation

struct PresetAgentSkills {
    static let all: [AgentSkillBundle] = [
        make("Swift Refactor Planner", "Architectural refactoring workflow for Swift modules.", ["refactor", "swift", "architecture"]),
        make("Test-First Generator", "Generates XCTest plans before implementation.", ["testing", "xctest", "tdd"]),
        make("Concurrency Auditor", "Finds async/await, actor and thread-safety issues.", ["concurrency", "async", "audit"]),
        make("UIKit to SwiftUI Migrator", "Migration checklist and code templates.", ["swiftui", "uikit", "migration"]),
        make("Dependency Hardener", "Dependency review and lockfile hygiene.", ["dependencies", "security"]),
        make("API Contract Reviewer", "Ensures schema and client code stay aligned.", ["api", "contracts"]),
        make("Tool-Driven Bug Hunter", "Combines logs + search tools to isolate regressions.", ["debug", "tools"]),
        make("Documentation Composer", "Writes DocC and markdown implementation docs.", ["docs", "docc"]),
        make("Performance Profiler Coach", "Guides profiling workflows for bottlenecks.", ["performance", "profiling"]),
        make("Accessibility Enforcer", "Audits labels, traits and dynamic type coverage.", ["a11y", "ios"]),
        make("Localization Assistant", "Automates string extraction and review.", ["localization", "strings"]),
        make("Secure Storage Advisor", "Helps use Keychain and data-protection best practices.", ["security", "keychain"]),
        make("Network Resilience Designer", "Builds retry/caching strategy playbooks.", ["network", "resilience"]),
        make("Feature Flag Operator", "Patterns for safely launching features.", ["feature-flags", "release"]),
        make("Release Checklist Expert", "Pre-flight and post-release production checklists.", ["release", "ops"]),
        make("Git Hygiene Mentor", "Branching, commit quality and PR standards.", ["git", "workflow"]),
        make("Code Style Enforcer", "Swift formatting and linting rules.", ["style", "lint"]),
        make("Error Handling Architect", "Designs typed errors and recovery.", ["errors", "architecture"]),
        make("Modularization Planner", "Breaks large apps into cohesive modules.", ["modularization", "design"]),
        make("Build Optimization Specialist", "Improves compile-time and CI throughput.", ["build", "ci"]),
        make("Data Model Normalizer", "Improves Codable and persistence schema evolution.", ["data", "models"])
    ]

    private static func make(_ name: String, _ summary: String, _ tags: [String]) -> AgentSkillBundle {
        AgentSkillBundle(
            id: UUID(),
            source: .preset,
            markdown: "# \(name)\n\n\(summary)\n\n## How to Use\n1. Define intent.\n2. Use linked tools.\n3. Validate output.",
            scheme: AgentSkillScheme(
                name: name,
                version: "1.0.0",
                author: "SwiftCode",
                summary: summary,
                tags: tags,
                recommendedTools: ["search_project", "read_file", "write_file"],
                guidance: [
                    "Always gather context first.",
                    "Prefer small iterative changes.",
                    "Run validation commands after edits."
                ]
            )
        )
    }
}
