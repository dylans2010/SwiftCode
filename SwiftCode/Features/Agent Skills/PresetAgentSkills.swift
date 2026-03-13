import Foundation

struct PresetAgentSkills {
    static let all: [AgentSkillBundle] = [
        // Architecture & Design
        makeAdvanced(
            "Swift Refactor Planner",
            "Deep architectural refactoring workflow for Swift modules. Analyzes coupling, cohesion, and dependency graphs to propose targeted refactors that minimize risk.",
            ["refactor", "swift", "architecture"],
            tools: ["search_project", "read_file", "write_file", "extract_swift_symbols", "find_imports", "analyze_complexity", "dependency_graph"],
            guidance: [
                "Map all type dependencies before proposing changes.",
                "Identify high-coupling areas using search_project.",
                "Extract symbols to understand the type hierarchy.",
                "Propose changes in small, reversible increments.",
                "Validate each refactor step compiles conceptually.",
                "Document architectural decisions inline."
            ]
        ),
        makeAdvanced(
            "MVVM Architecture Enforcer",
            "Validates and enforces MVVM separation of concerns. Detects business logic in Views, missing ViewModels, and direct model access from the UI layer.",
            ["mvvm", "architecture", "patterns"],
            tools: ["search_project", "read_file", "extract_swift_symbols", "find_imports", "analyze_complexity"],
            guidance: [
                "Scan views for business logic patterns (network calls, data transformation).",
                "Verify every View has a corresponding ViewModel.",
                "Check that Models are only accessed through ViewModels.",
                "Flag any UIKit imports in SwiftUI view files.",
                "Suggest ObservableObject patterns for state management."
            ]
        ),
        makeAdvanced(
            "Protocol-Oriented Designer",
            "Designs protocol hierarchies and default implementations. Identifies opportunities for protocol composition and generic abstractions.",
            ["protocols", "generics", "design"],
            tools: ["read_file", "write_file", "extract_swift_symbols", "generate_protocol", "generate_extension"],
            guidance: [
                "Prefer protocol composition over inheritance.",
                "Use associated types for maximum flexibility.",
                "Provide sensible default implementations via extensions.",
                "Design protocols around capabilities, not types.",
                "Keep protocols focused—one responsibility each."
            ]
        ),
        makeAdvanced(
            "Modularization Planner",
            "Breaks large monolithic apps into cohesive Swift packages and modules. Analyzes dependency graphs to find clean module boundaries.",
            ["modularization", "spm", "design"],
            tools: ["search_project", "read_file", "list_directory", "extract_swift_symbols", "find_imports", "dependency_graph"],
            guidance: [
                "Map the full import graph across the project.",
                "Identify clusters of files with shared dependencies.",
                "Define module boundaries along domain concepts.",
                "Create Package.swift manifests for each module.",
                "Ensure no circular dependencies between modules.",
                "Plan migration order from leaf modules inward."
            ]
        ),

        // Testing & Quality
        makeAdvanced(
            "Test-First Generator",
            "Generates comprehensive XCTest plans before implementation. Covers unit, integration, and snapshot test strategies with proper mocking patterns.",
            ["testing", "xctest", "tdd"],
            tools: ["read_file", "write_file", "generate_unit_tests", "extract_swift_symbols", "search_project"],
            guidance: [
                "Write test cases before implementation code.",
                "Cover happy path, edge cases, and error scenarios.",
                "Use protocol-based mocking for dependencies.",
                "Generate both sync and async test variants.",
                "Include performance test baselines for critical paths.",
                "Structure tests using Given-When-Then pattern."
            ]
        ),
        makeAdvanced(
            "UI Test Architect",
            "Designs XCUITest strategies including page objects, accessibility identifiers, and test recording patterns for reliable UI automation.",
            ["uitest", "xcuitest", "automation"],
            tools: ["read_file", "write_file", "search_project", "generate_unit_tests"],
            guidance: [
                "Create page object models for each screen.",
                "Ensure all interactive elements have accessibility identifiers.",
                "Design tests that are resilient to UI changes.",
                "Implement test data factories for consistent state.",
                "Add screenshot capture at key validation points.",
                "Build reusable test helper extensions."
            ]
        ),
        makeAdvanced(
            "Code Coverage Optimizer",
            "Analyzes existing test coverage and identifies critical untested paths. Prioritizes test writing by risk and complexity.",
            ["coverage", "testing", "quality"],
            tools: ["search_project", "read_file", "extract_swift_symbols", "analyze_complexity", "find_todos"],
            guidance: [
                "Identify public APIs without corresponding tests.",
                "Prioritize testing of complex functions (high cyclomatic complexity).",
                "Focus on error handling and edge case coverage.",
                "Suggest property-based testing for data transformations.",
                "Flag any force-unwraps that lack test coverage."
            ]
        ),

        // Concurrency & Performance
        makeAdvanced(
            "Concurrency Auditor",
            "Deep audit for async/await, actor isolation, Sendable conformance, and thread-safety issues. Identifies data races and concurrency anti-patterns.",
            ["concurrency", "async", "audit", "sendable"],
            tools: ["search_project", "read_file", "extract_swift_symbols", "find_imports", "analyze_complexity"],
            guidance: [
                "Scan for @MainActor annotations on all view-facing types.",
                "Verify Sendable conformance for types crossing actor boundaries.",
                "Identify shared mutable state without actor protection.",
                "Check for proper Task cancellation handling.",
                "Flag synchronous blocking calls in async contexts.",
                "Audit TaskGroup usage for proper error propagation."
            ]
        ),
        makeAdvanced(
            "Performance Profiler Coach",
            "Guides profiling workflows for identifying bottlenecks. Covers Instruments templates, Time Profiler patterns, and memory optimization strategies.",
            ["performance", "profiling", "optimization"],
            tools: ["read_file", "search_project", "analyze_complexity", "extract_swift_symbols", "count_lines"],
            guidance: [
                "Identify O(n²) or worse algorithms in hot paths.",
                "Check for unnecessary view recomputations in SwiftUI.",
                "Flag large array copies and suggest inout or COW patterns.",
                "Review image loading for proper caching and resizing.",
                "Suggest lazy loading for expensive computed properties.",
                "Audit retain cycles in closures and delegates."
            ]
        ),
        makeAdvanced(
            "Memory Management Expert",
            "Identifies memory leaks, retain cycles, and excessive allocations. Provides patterns for weak references, unowned captures, and value type optimization.",
            ["memory", "leaks", "optimization"],
            tools: ["search_project", "read_file", "extract_swift_symbols"],
            guidance: [
                "Search for closure capture lists missing [weak self].",
                "Identify delegate properties not marked as weak.",
                "Flag large struct copies that should use classes or COW.",
                "Check for NotificationCenter observers without removal.",
                "Audit Timer instances for proper invalidation.",
                "Review image caching strategies."
            ]
        ),

        // Migration & Modernization
        makeAdvanced(
            "UIKit to SwiftUI Migrator",
            "Comprehensive migration checklist and code templates for transitioning UIKit views to SwiftUI. Handles hosting controllers, representables, and hybrid architectures.",
            ["swiftui", "uikit", "migration"],
            tools: ["read_file", "write_file", "search_project", "generate_swiftui_view", "find_imports", "extract_swift_symbols"],
            guidance: [
                "Start migration from leaf views (no child view controllers).",
                "Use UIViewRepresentable for UIKit components without SwiftUI equivalents.",
                "Convert UITableView/UICollectionView to List/LazyVGrid.",
                "Replace UINavigationController with NavigationStack.",
                "Migrate delegates to Combine publishers or async streams.",
                "Keep hybrid architecture stable during incremental migration."
            ]
        ),
        makeAdvanced(
            "Swift 6 Migration Assistant",
            "Prepares codebases for strict concurrency checking and Swift 6. Adds Sendable conformances, fixes actor isolation issues, and modernizes patterns.",
            ["swift6", "concurrency", "migration"],
            tools: ["search_project", "read_file", "write_file", "extract_swift_symbols", "find_imports"],
            guidance: [
                "Enable strict concurrency checking incrementally per module.",
                "Add @Sendable annotations to closure parameters.",
                "Convert class types crossing boundaries to actors or Sendable structs.",
                "Replace DispatchQueue with structured concurrency.",
                "Audit global variables for potential data races.",
                "Use @preconcurrency import for third-party modules not yet updated."
            ]
        ),

        // Security & Data
        makeAdvanced(
            "Secure Storage Advisor",
            "Implements Keychain access, data-protection classes, and secure enclave patterns. Audits for sensitive data stored insecurely.",
            ["security", "keychain", "encryption"],
            tools: ["search_project", "read_file", "write_file", "generate_service"],
            guidance: [
                "Never store tokens or secrets in UserDefaults.",
                "Use Keychain with appropriate access control flags.",
                "Apply correct data protection classes to files.",
                "Implement biometric authentication for sensitive operations.",
                "Encrypt data at rest for offline-capable features.",
                "Audit network calls for certificate pinning."
            ]
        ),
        makeAdvanced(
            "Data Model Normalizer",
            "Improves Codable conformance, persistence schema evolution, and data validation. Handles migration strategies for Core Data and SwiftData.",
            ["data", "models", "codable", "persistence"],
            tools: ["read_file", "write_file", "generate_model", "generate_struct", "extract_swift_symbols"],
            guidance: [
                "Use CodingKeys for API field name mapping.",
                "Implement custom Decodable init for complex transformations.",
                "Design versioned schemas with backward compatibility.",
                "Add validation logic in model initializers.",
                "Use enums with associated values for polymorphic data.",
                "Implement Equatable and Hashable properly."
            ]
        ),

        // API & Networking
        makeAdvanced(
            "API Contract Reviewer",
            "Ensures REST/GraphQL schema and client code stay perfectly aligned. Validates request/response types, error handling, and pagination patterns.",
            ["api", "contracts", "networking"],
            tools: ["read_file", "write_file", "search_project", "generate_model", "generate_async_function", "validate_json"],
            guidance: [
                "Verify every API endpoint has a matching request/response model.",
                "Check error response parsing covers all documented error codes.",
                "Validate pagination cursor handling for list endpoints.",
                "Ensure authentication headers are consistently applied.",
                "Test timeout and retry logic for all network calls.",
                "Document expected response shapes inline."
            ]
        ),
        makeAdvanced(
            "Network Resilience Designer",
            "Builds comprehensive retry, caching, and offline-first strategy playbooks. Implements exponential backoff, request deduplication, and cache invalidation.",
            ["network", "resilience", "offline"],
            tools: ["read_file", "write_file", "generate_service", "generate_protocol", "search_project"],
            guidance: [
                "Implement exponential backoff with jitter for retries.",
                "Design cache layers: memory → disk → network.",
                "Add request deduplication for concurrent identical calls.",
                "Implement offline queue for write operations.",
                "Use ETags and Last-Modified for cache validation.",
                "Build circuit breaker pattern for failing endpoints."
            ]
        ),
        makeAdvanced(
            "GraphQL Client Architect",
            "Designs type-safe GraphQL query builders, fragment composition, and subscription handling for iOS apps.",
            ["graphql", "networking", "codegen"],
            tools: ["read_file", "write_file", "generate_struct", "generate_protocol", "generate_enum"],
            guidance: [
                "Generate Swift types from GraphQL schema.",
                "Use fragments for reusable field selections.",
                "Implement normalized caching for query results.",
                "Handle subscription lifecycle with proper cleanup.",
                "Design query batching for related data fetches.",
                "Build type-safe variable builders."
            ]
        ),

        // DevOps & CI/CD
        makeAdvanced(
            "Build Optimization Specialist",
            "Improves compile-time performance, CI throughput, and incremental build speeds. Analyzes type-checking bottlenecks and suggests fixes.",
            ["build", "ci", "optimization"],
            tools: ["read_file", "search_project", "count_lines", "extract_swift_symbols", "analyze_complexity", "list_directory"],
            guidance: [
                "Identify files with excessive type inference complexity.",
                "Suggest explicit type annotations for slow-compiling expressions.",
                "Recommend module splits to improve incremental builds.",
                "Optimize CI pipeline stages for parallelism.",
                "Cache SwiftPM dependencies in CI.",
                "Profile build times per target and file."
            ]
        ),
        makeAdvanced(
            "Release Checklist Expert",
            "Comprehensive pre-flight and post-release production checklists. Covers App Store submission, TestFlight distribution, and rollback planning.",
            ["release", "ops", "appstore"],
            tools: ["search_project", "read_file", "find_todos", "list_directory"],
            guidance: [
                "Verify all TODO/FIXME items are resolved.",
                "Check version number and build number increments.",
                "Ensure release notes are updated.",
                "Validate all API endpoints point to production.",
                "Confirm analytics events are properly tagged.",
                "Test deep links and universal links.",
                "Verify push notification certificates are valid.",
                "Run full regression test suite."
            ]
        ),
        makeAdvanced(
            "CI/CD Pipeline Designer",
            "Designs GitHub Actions, Xcode Cloud, and Fastlane workflows for automated testing, building, signing, and deployment.",
            ["ci", "cd", "automation", "github-actions"],
            tools: ["read_file", "write_file", "create_file", "list_directory", "search_project"],
            guidance: [
                "Design pipeline stages: lint → test → build → deploy.",
                "Cache dependencies and derived data between runs.",
                "Use matrix builds for multiple OS/device combinations.",
                "Implement automatic version bumping.",
                "Set up code signing with match or manual provisioning.",
                "Add Slack/Discord notifications for build status."
            ]
        ),

        // Code Quality & Style
        makeAdvanced(
            "Code Style Enforcer",
            "Enforces consistent Swift formatting, naming conventions, and linting rules. Integrates SwiftLint and SwiftFormat configurations.",
            ["style", "lint", "formatting"],
            tools: ["read_file", "write_file", "search_project", "create_file"],
            guidance: [
                "Define consistent indentation (spaces vs tabs, width).",
                "Enforce naming conventions: camelCase variables, PascalCase types.",
                "Configure SwiftLint rules for the project.",
                "Set maximum line length and function complexity limits.",
                "Standardize import ordering (system → third-party → local).",
                "Define documentation requirements for public APIs."
            ]
        ),
        makeAdvanced(
            "Error Handling Architect",
            "Designs typed error hierarchies, recovery strategies, and user-facing error presentation. Eliminates force-unwraps and unhandled optionals.",
            ["errors", "architecture", "safety"],
            tools: ["search_project", "read_file", "write_file", "generate_enum", "generate_protocol", "extract_swift_symbols"],
            guidance: [
                "Define domain-specific error enums with associated values.",
                "Implement error recovery suggestions for user-facing errors.",
                "Replace force-unwraps with proper optional handling.",
                "Use Result type for operations with known error types.",
                "Design error logging and reporting infrastructure.",
                "Create user-friendly error messages separate from technical details."
            ]
        ),

        // Documentation & Communication
        makeAdvanced(
            "Documentation Composer",
            "Writes DocC documentation, markdown implementation guides, and API reference documentation. Generates sample code and tutorials.",
            ["docs", "docc", "documentation"],
            tools: ["read_file", "write_file", "extract_swift_symbols", "search_project", "create_file"],
            guidance: [
                "Add doc comments to all public types and methods.",
                "Use DocC syntax for rich documentation with code examples.",
                "Create getting-started tutorials for complex features.",
                "Document architecture decisions with ADR format.",
                "Generate API reference from extracted symbols.",
                "Include visual diagrams for complex workflows."
            ]
        ),

        // Accessibility & UX
        makeAdvanced(
            "Accessibility Enforcer",
            "Comprehensive audit for VoiceOver labels, Dynamic Type support, color contrast ratios, and assistive technology coverage.",
            ["a11y", "ios", "voiceover", "accessibility"],
            tools: ["search_project", "read_file", "write_file"],
            guidance: [
                "Verify all interactive elements have accessibility labels.",
                "Check that images have appropriate traits (button, image, etc.).",
                "Ensure Dynamic Type scales properly at all text sizes.",
                "Test color contrast meets WCAG 2.1 AA standards.",
                "Add accessibility hints for non-obvious interactions.",
                "Group related elements using accessibilityElement(children:).",
                "Support Reduce Motion preference in animations.",
                "Test with VoiceOver for logical reading order."
            ]
        ),
        makeAdvanced(
            "Dark Mode Auditor",
            "Validates dark mode support across all views. Checks for hardcoded colors, missing asset catalogs, and contrast issues in both appearances.",
            ["darkmode", "theming", "ui"],
            tools: ["search_project", "read_file", "write_file"],
            guidance: [
                "Search for hardcoded UIColor/Color values.",
                "Verify all colors use semantic system colors or asset catalogs.",
                "Check that images have dark mode variants where needed.",
                "Test contrast ratios in both light and dark appearances.",
                "Ensure materials and blur effects adapt correctly.",
                "Use preferredColorScheme for preview testing."
            ]
        ),

        // Localization & i18n
        makeAdvanced(
            "Localization Assistant",
            "Automates string extraction, manages .strings and .stringsdict files, and reviews translations for completeness and context.",
            ["localization", "strings", "i18n"],
            tools: ["search_project", "read_file", "write_file", "create_file", "list_directory"],
            guidance: [
                "Extract all user-facing strings to Localizable.strings.",
                "Use String(localized:) for new projects, NSLocalizedString for legacy.",
                "Create .stringsdict entries for pluralization rules.",
                "Add developer comments for translator context.",
                "Verify all supported languages have complete translations.",
                "Test with pseudolocalization for layout issues.",
                "Handle right-to-left languages for bidirectional support."
            ]
        ),

        // Workflow & Process
        makeAdvanced(
            "Feature Flag Operator",
            "Implements feature flag patterns for safe feature launches, A/B testing, and gradual rollouts with kill-switch capabilities.",
            ["feature-flags", "release", "ab-testing"],
            tools: ["read_file", "write_file", "generate_enum", "generate_protocol", "search_project"],
            guidance: [
                "Define feature flags as a strongly-typed enum.",
                "Implement remote configuration for dynamic flags.",
                "Add default values for offline/fallback behavior.",
                "Create analytics events tied to flag evaluations.",
                "Plan flag cleanup after full rollout.",
                "Design A/B test variant distribution logic."
            ]
        ),
        makeAdvanced(
            "Git Hygiene Mentor",
            "Enforces branching strategies, commit quality standards, PR templates, and merge conflict resolution patterns.",
            ["git", "workflow", "collaboration"],
            tools: ["search_project", "read_file", "write_file", "create_file"],
            guidance: [
                "Define branch naming: feature/, bugfix/, release/, hotfix/.",
                "Write atomic commits with clear, conventional messages.",
                "Create PR templates with checklist and screenshot sections.",
                "Set up branch protection rules for main and release branches.",
                "Implement squash merge strategy for clean history.",
                "Document conflict resolution procedures."
            ]
        ),
        makeAdvanced(
            "Dependency Hardener",
            "Comprehensive dependency review covering version pinning, license auditing, security vulnerability scanning, and update strategies.",
            ["dependencies", "security", "spm"],
            tools: ["read_file", "write_file", "search_project", "list_directory"],
            guidance: [
                "Pin all dependency versions to exact or minor ranges.",
                "Audit licenses for compatibility with your app's license.",
                "Check for known security vulnerabilities in dependencies.",
                "Evaluate dependency health: maintenance activity, issue count.",
                "Plan update strategy: automated vs. manual review.",
                "Maintain a dependency decision log with rationale."
            ]
        ),

        // Advanced Patterns
        makeAdvanced(
            "SwiftUI Animation Expert",
            "Designs complex animations including matched geometry effects, phase animators, keyframe animations, and custom transitions.",
            ["animation", "swiftui", "motion"],
            tools: ["read_file", "write_file", "generate_swiftui_view", "generate_extension"],
            guidance: [
                "Use withAnimation for state-driven animations.",
                "Implement matchedGeometryEffect for hero transitions.",
                "Design custom Transition types for reusable effects.",
                "Use PhaseAnimator for multi-step sequences.",
                "Respect Reduce Motion accessibility preference.",
                "Profile animation performance on target devices."
            ]
        ),
        makeAdvanced(
            "SwiftData Specialist",
            "Implements SwiftData models, queries, and migration strategies. Covers relationships, fetch descriptors, and CloudKit sync.",
            ["swiftdata", "persistence", "cloudkit"],
            tools: ["read_file", "write_file", "generate_model", "generate_struct", "search_project"],
            guidance: [
                "Design @Model classes with proper relationships.",
                "Use @Query with sort descriptors and predicates.",
                "Implement lightweight migration for schema changes.",
                "Configure CloudKit sync for cross-device data.",
                "Handle merge conflicts in multi-device scenarios.",
                "Build background context operations for heavy writes."
            ]
        ),
        makeAdvanced(
            "Combine & Reactive Patterns",
            "Implements reactive data flows using Combine publishers, operators, and subscribers. Bridges async/await with Combine streams.",
            ["combine", "reactive", "publishers"],
            tools: ["read_file", "write_file", "generate_extension", "search_project", "extract_swift_symbols"],
            guidance: [
                "Use @Published properties for simple state observation.",
                "Chain operators: map, filter, debounce, combineLatest.",
                "Handle errors with catch, retry, and replaceError.",
                "Cancel subscriptions properly with AnyCancellable storage.",
                "Bridge Combine publishers to async sequences when needed.",
                "Avoid deeply nested publisher chains—extract into methods."
            ]
        ),
        makeAdvanced(
            "Widget & Live Activity Builder",
            "Designs iOS widgets, Live Activities, and Dynamic Island presentations with timeline providers and intent configurations.",
            ["widgets", "live-activities", "dynamic-island"],
            tools: ["read_file", "write_file", "generate_swiftui_view", "generate_struct", "create_file"],
            guidance: [
                "Design timeline providers with appropriate refresh policies.",
                "Support multiple widget families (small, medium, large, extra large).",
                "Implement intent-based configuration for user customization.",
                "Create Live Activity layouts for Dynamic Island and Lock Screen.",
                "Handle deep links from widget taps.",
                "Optimize data fetching for widget timeline generation."
            ]
        ),
        makeAdvanced(
            "App Intents & Shortcuts Expert",
            "Implements App Intents for Siri, Shortcuts, and Spotlight integration. Covers entity queries, parameter resolution, and intent donation.",
            ["intents", "siri", "shortcuts", "spotlight"],
            tools: ["read_file", "write_file", "generate_struct", "generate_protocol", "search_project"],
            guidance: [
                "Define AppIntent types with clear parameter descriptions.",
                "Implement EntityQuery for searchable content.",
                "Design reusable parameter types with proper summaries.",
                "Donate intents for Siri suggestion relevance.",
                "Handle intent resolution for ambiguous parameters.",
                "Support Shortcuts automation with proper result types."
            ]
        ),

        // Debug & Diagnostics
        makeAdvanced(
            "Tool-Driven Bug Hunter",
            "Combines intelligent log analysis, code search, and diff tools to systematically isolate regressions and reproduce bugs.",
            ["debug", "tools", "diagnostics"],
            tools: ["search_project", "read_file", "search_in_file", "find_and_replace", "diff_content", "get_line", "extract_swift_symbols"],
            guidance: [
                "Start by reproducing the issue with minimal steps.",
                "Search for related error messages in the codebase.",
                "Use diff_content to compare working vs. broken versions.",
                "Extract symbols to understand the affected type hierarchy.",
                "Check recent changes to implicated files.",
                "Add strategic print/os_log statements for diagnosis.",
                "Binary search through commits to find the regression point."
            ]
        ),
        makeAdvanced(
            "Crash Report Analyzer",
            "Interprets crash reports, symbolicated stack traces, and exception logs. Identifies root causes and suggests fixes.",
            ["crashes", "debugging", "diagnostics"],
            tools: ["read_file", "search_project", "search_in_file", "extract_swift_symbols", "get_line"],
            guidance: [
                "Parse the crash thread's stack trace for your code frames.",
                "Identify the crashing instruction (EXC_BAD_ACCESS, etc.).",
                "Check for force-unwraps near the crash location.",
                "Look for thread safety issues if crash is intermittent.",
                "Review memory warnings preceding the crash.",
                "Add guard statements and proper error handling at crash sites."
            ]
        ),
        makeAdvanced(
            "Logging Infrastructure Builder",
            "Designs structured logging with os.Logger, log levels, privacy annotations, and remote log collection for production debugging.",
            ["logging", "debugging", "infrastructure"],
            tools: ["read_file", "write_file", "generate_service", "search_project", "create_file"],
            guidance: [
                "Use os.Logger with subsystem and category for organization.",
                "Apply appropriate log levels: debug, info, notice, error, fault.",
                "Mark sensitive data with .private in log interpolations.",
                "Design log categories aligned with feature modules.",
                "Implement remote log collection for production issues.",
                "Add performance signposts for critical operations."
            ]
        ),
    ]

    private static func makeAdvanced(
        _ name: String,
        _ summary: String,
        _ tags: [String],
        tools: [String],
        guidance: [String]
    ) -> AgentSkillBundle {
        let toolsSection = tools.map { "- `\($0)`" }.joined(separator: "\n")
        let guidanceSection = guidance.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let markdown = """
        # \(name)

        \(summary)

        ## Recommended Tools
        \(toolsSection)

        ## Workflow

        ### Phase 1: Analysis
        Gather context using read and search tools before making any changes.

        ### Phase 2: Planning
        Outline the specific changes needed based on your analysis.

        ### Phase 3: Execution
        Apply changes incrementally, validating each step.

        ### Phase 4: Validation
        Verify all changes compile and behave correctly.

        ## Guidance
        \(guidanceSection)

        ## Best Practices
        - Always gather context before modifying code.
        - Make small, reversible changes.
        - Document decisions and trade-offs.
        - Validate results after each modification.
        """

        return AgentSkillBundle(
            id: UUID(),
            source: .preset,
            markdown: markdown,
            scheme: AgentSkillScheme(
                name: name,
                version: "2.0.0",
                author: "SwiftCode",
                summary: summary,
                tags: tags,
                recommendedTools: tools,
                guidance: guidance
            )
        )
    }
}
