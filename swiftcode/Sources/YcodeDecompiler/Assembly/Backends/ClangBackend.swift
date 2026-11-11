import Foundation

public struct ClangBackend: AssembleBackend {
    public init() {}

    public var id: String { "clang" }
    public var displayName: String { "Clang (C, C++, Objective-C)" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { ["c", "m", "mm", "cpp", "cc", "cxx", "s", "S"] }
    public var handlesMultipleArchitectures: Bool { true }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        if let preferred = configuration.compilerPath {
            if FileManager.default.isExecutableFile(atPath: preferred) {
                return .available(toolPath: preferred, version: BackendToolDiscovery.toolVersion(preferred))
            }
            return .unavailable(
                reason: "The configured compiler path \(preferred) does not exist or is not executable.",
                installGuidance: Self.installGuidance(format: configuration.format))
        }
        if let found = Self.locateCompiler() {
            return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found))
        }
        return .unavailable(reason: "No C compiler was found.", installGuidance: Self.installGuidance(format: configuration.format))
    }

    public static func locateCompiler() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: "clang",
            fixedPaths: ["/usr/bin/clang", "/usr/local/bin/clang", "/opt/homebrew/bin/clang",
                         "/usr/bin/cc", "/usr/bin/gcc", "/usr/local/bin/gcc"],
            pathNames: ["clang", "cc", "gcc"])
    }

    public static func installGuidance(format: BinaryFormat) -> String {
        switch format {
        case .machO:
            return "Install Xcode or the Xcode Command Line Tools (xcode-select --install) and try again."
        default:
            return "Install clang or gcc and try again."
        }
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        var args = configuration.compileArguments(source: source, object: object, projectRoot: projectRoot, format: configuration.format)
        args.append(contentsOf: configuration.perBackendFlags["clang"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] {
        var args = configuration.linkArguments(objects: objects, output: output, format: configuration.format)
        let extensions = Set(sources.map(\.pathExtension))
        let hasCpp = extensions.contains { ["cpp", "cc", "cxx", "mm"].contains($0) }
        let hasObjC = extensions.contains { ["m", "mm"].contains($0) }
        if configuration.format == .machO {
            if hasCpp { args.append("-lc++") }
            if hasObjC { args.append("-lobjc") }
        } else if hasCpp {
            args.append("-lstdc++")
        }
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        AssemblyDiagnosticParser.parseCompilerOutput(text, projectRoot: projectRoot)
    }
}
