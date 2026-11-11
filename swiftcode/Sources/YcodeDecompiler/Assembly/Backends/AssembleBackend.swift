import Foundation

public enum BackendKind: String, Sendable, Codable {
    case native
    case runtimeEmbedded
}

public enum BackendBuildMode: Sendable {
    case object
    case library
}

public enum BackendAvailability: Sendable {
    case available(toolPath: String, version: String?)
    case unavailable(reason: String, installGuidance: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    public var toolPath: String? {
        if case .available(let path, _) = self { return path }
        return nil
    }

    public var version: String? {
        if case .available(_, let version) = self { return version }
        return nil
    }
}

public protocol AssembleBackend: Sendable {
    var id: String { get }
    var displayName: String { get }
    var kind: BackendKind { get }
    var buildMode: BackendBuildMode { get }
    var sourceExtensions: Set<String> { get }
    var discoveryRoots: [String] { get }
    var handlesMultipleArchitectures: Bool { get }
    func availability(configuration: BuildConfiguration) -> BackendAvailability
    func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String]
    func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String]
    func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String]
    func libraryWorkingDirectory(projectRoot: URL, configuration: BuildConfiguration) -> URL?
    func libraryEnvironment(configuration: BuildConfiguration) -> [String: String]
    func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic]
    func postCompileDiagnostics(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> [AssemblyDiagnostic]
    func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws
}

public extension AssembleBackend {
    var discoveryRoots: [String] { ["Sources", "Assembly"] }
    var handlesMultipleArchitectures: Bool { false }
    func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] { [] }
    func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] { [] }
    func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] { [] }
    func libraryWorkingDirectory(projectRoot: URL, configuration: BuildConfiguration) -> URL? { nil }
    func libraryEnvironment(configuration: BuildConfiguration) -> [String: String] { [:] }
    func postCompileDiagnostics(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> [AssemblyDiagnostic] { [] }
    func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {}
}
