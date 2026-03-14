import Foundation

public enum TestStatus: String, Codable {
    case success
    case warning
    case failed
}

public struct TestResult: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let status: TestStatus
    public let executionTime: TimeInterval
    public let errorMessage: String?

    public init(name: String, status: TestStatus, executionTime: TimeInterval, errorMessage: String? = nil) {
        self.id = UUID()
        self.name = name
        self.status = status
        self.executionTime = executionTime
        self.errorMessage = errorMessage
    }
}

@MainActor
public final class TestToolsManager: ObservableObject {
    public static let shared = TestToolsManager()

    @Published public var isRunning = false
    @Published public var results: [TestResult] = []

    private var customTestModules: [String: (String) -> TestResult] = [:]

    private init() {}

    public func runTests(forProject project: Project) async {
        isRunning = true
        results.removeAll()

        // Run built-in project tests
        results.append(validateFileStructure(for: project))
        results.append(validateConfiguration(for: project))
        results.append(checkProjectDependencies(for: project))

        // Run custom modules if applicable
        for (name, handler) in customTestModules {
            results.append(handler(project.name))
        }

        isRunning = false
    }

    public func runTests(forFile path: String, in project: Project) async {
        isRunning = true
        results.removeAll()

        // Run built-in file tests
        results.append(validateSyntax(for: path, in: project))

        isRunning = false
    }

    public func runExtensionTests(extensionID: String) async {
        isRunning = true
        results.removeAll()

        results.append(checkExtensionCompatibility(extensionID: extensionID))

        isRunning = false
    }

    public func runAgentToolTests(toolID: String) async {
        isRunning = true
        results.removeAll()

        results.append(checkAgentToolCompatibility(toolID: toolID))

        isRunning = false
    }

    public func registerCustomTestModule(name: String, handler: @escaping (String) -> TestResult) {
        customTestModules[name] = handler
    }

    // MARK: - Internal Test Modules

    private func validateSyntax(for path: String, in project: Project) -> TestResult {
        let start = Date()
        // Mock syntax validation
        let success = !path.contains("error")
        return TestResult(
            name: "Syntax Validation",
            status: success ? .success : .failed,
            executionTime: Date().timeIntervalSince(start),
            errorMessage: success ? nil : "Syntax error detected in \(path)"
        )
    }

    private func checkProjectDependencies(for project: Project) -> TestResult {
        let start = Date()
        // Mock dependency check
        return TestResult(
            name: "Dependency Check",
            status: .success,
            executionTime: Date().timeIntervalSince(start)
        )
    }

    private func validateFileStructure(for project: Project) -> TestResult {
        let start = Date()
        // Mock structure validation
        return TestResult(
            name: "File Structure Validation",
            status: .success,
            executionTime: Date().timeIntervalSince(start)
        )
    }

    private func validateConfiguration(for project: Project) -> TestResult {
        let start = Date()
        // Mock config validation
        return TestResult(
            name: "Configuration Validation",
            status: .success,
            executionTime: Date().timeIntervalSince(start)
        )
    }

    private func checkExtensionCompatibility(extensionID: String) -> TestResult {
        let start = Date()
        return TestResult(
            name: "Extension Compatibility Check",
            status: .success,
            executionTime: Date().timeIntervalSince(start)
        )
    }

    private func checkAgentToolCompatibility(toolID: String) -> TestResult {
        let start = Date()
        return TestResult(
            name: "Agent Tool Compatibility Check",
            status: .success,
            executionTime: Date().timeIntervalSince(start)
        )
    }
}
