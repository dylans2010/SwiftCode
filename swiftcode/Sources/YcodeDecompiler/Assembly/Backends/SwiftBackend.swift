import Foundation

public struct SwiftBackend: AssembleBackend {
    public init() {}

    public var id: String { "swift" }
    public var displayName: String { "Swift" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { ["swift"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        if let found = Self.locateSwiftc() {
            return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found))
        }
        return .unavailable(
            reason: "No Swift compiler was found.",
            installGuidance: "Install Xcode or the Xcode Command Line Tools (xcode-select --install) on macOS, or install Swift from https://www.swift.org/install/ on Linux, and try again.")
    }

    public static func locateSwiftc() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: "swiftc",
            fixedPaths: ["/usr/bin/swiftc", "/usr/local/bin/swiftc", "/opt/homebrew/bin/swiftc"],
            pathNames: ["swiftc"])
    }

    public static func moduleName(configuration: BuildConfiguration) -> String {
        var stem = configuration.outputFileName
        if stem.hasPrefix("lib") { stem = String(stem.dropFirst(3)) }
        if let dot = stem.firstIndex(of: ".") { stem = String(stem[..<dot]) }
        var name = String(stem.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "_" })
        if name.isEmpty { name = "Library" }
        if name.first?.isNumber == true { name = "_" + name }
        return name
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        var args: [String] = []
        args.append("-c")
        args.append(source.path)
        args.append("-o")
        args.append(object.path)
        args.append(Self.optimizationFlag(configuration.optimizationLevel))
        if configuration.debugSymbols { args.append("-g") }
        args.append("-module-name")
        args.append(Self.moduleName(configuration: configuration))
        args.append("-I")
        args.append(projectRoot.appendingPathComponent("Headers").path)
        for path in configuration.headerSearchPaths {
            args.append("-I")
            args.append(path)
        }
        for define in configuration.definitions {
            args.append("-D")
            args.append(define)
        }
        args.append(contentsOf: configuration.perBackendFlags["swift"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] {
        var args: [String] = []
        args.append("-emit-library")
        args.append(contentsOf: objects.map(\.path))
        args.append("-o")
        args.append(output.path)
        args.append("-module-name")
        args.append(Self.moduleName(configuration: configuration))
        if configuration.format == .machO {
            if configuration.architectures.count == 1, let target = configuration.deploymentTarget {
                args.append("-target")
                args.append("\(configuration.architectures[0].clangName)-apple-macosx\(target)")
            }
            if let sdk = configuration.sdk {
                args.append("-sdk")
                args.append(sdk)
            }
            if let installName = configuration.installName {
                args.append("-Xlinker")
                args.append("-install_name")
                args.append("-Xlinker")
                args.append(installName)
            }
            for runpath in configuration.runpaths {
                args.append("-Xlinker")
                args.append("-rpath")
                args.append("-Xlinker")
                args.append(runpath)
            }
            for framework in configuration.frameworks {
                args.append("-framework")
                args.append(framework)
            }
        }
#if !os(macOS)
        if let libDir = Self.swiftLibraryDirectory() {
            args.append("-Xlinker")
            args.append("-rpath")
            args.append("-Xlinker")
            args.append(libDir)
        }
#endif
        for path in configuration.librarySearchPaths {
            args.append("-L")
            args.append(path)
        }
        for library in configuration.linkedLibraries {
            args.append("-l\(library)")
        }
        args.append(contentsOf: configuration.linkerFlags)
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        AssemblyDiagnosticParser.parseCompilerOutput(text, projectRoot: projectRoot)
    }

    public func postCompileDiagnostics(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> [AssemblyDiagnostic] {
        let hasCdecl = sources.contains { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
            return text.contains("@_cdecl")
        }
        if hasCdecl { return [] }
        return [AssemblyDiagnostic(
            severity: .warning,
            message: "No @_cdecl export was found in the Swift sources. Swift functions are not callable through dlsym without @_cdecl(\"name\"); annotate each exported function, for example @_cdecl(\"sc_add\").",
            origin: .projectConfiguration,
            suggestion: "Add @_cdecl(\"exported_name\") to every function the library must export.")]
    }

    private static func optimizationFlag(_ level: String) -> String {
        switch level {
        case "0": return "-Onone"
        case "s", "z": return "-Osize"
        default: return "-O"
        }
    }

    private static func swiftLibraryDirectory() -> String? {
        guard let swiftc = locateSwiftc() else { return nil }
        let binDir = URL(fileURLWithPath: swiftc).deletingLastPathComponent()
        let libDir = binDir.deletingLastPathComponent()
            .appendingPathComponent("lib/swift", isDirectory: true)
#if os(macOS)
        let platformDir = libDir.appendingPathComponent("macosx", isDirectory: true)
#else
        let platformDir = libDir.appendingPathComponent("linux", isDirectory: true)
#endif
        guard FileManager.default.fileExists(atPath: platformDir.path) else { return nil }
        return platformDir.path
    }
}
