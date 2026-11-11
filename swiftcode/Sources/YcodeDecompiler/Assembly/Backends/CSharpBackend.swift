import Foundation

public struct CSharpBackend: AssembleBackend {
    public init() {}

    public var id: String { "csharp" }
    public var displayName: String { "C# (NativeAOT)" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["cs"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let found = Self.locateDotnet() else {
            return .unavailable(
                reason: "No .NET SDK was found.",
                installGuidance: "Install the .NET SDK 8 or newer from https://dot.net/download (or brew install dotnet-sdk) and make sure dotnet is on PATH, then try again.")
        }
        let version = BackendToolDiscovery.toolVersion(found, arguments: ["--version"])
        if let version, let major = Self.sdkMajorVersion(version), major < 8 {
            return .unavailable(
                reason: ".NET SDK \(version) is too old; NativeAOT shared libraries need SDK 8 or newer.",
                installGuidance: "Install the .NET SDK 8 or newer from https://dot.net/download.")
        }
        if ClangBackend.locateCompiler() == nil {
            return .unavailable(
                reason: "NativeAOT publishing links native code, which needs a C compiler.",
                installGuidance: "Install Xcode or the Xcode Command Line Tools (xcode-select --install) on macOS, or install clang on Linux, and try again.")
        }
        return .available(toolPath: found, version: version)
    }

    public static func locateDotnet() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/local/share/dotnet/dotnet", "/opt/homebrew/bin/dotnet", "~/.dotnet/dotnet"],
            pathNames: ["dotnet"])
    }

    public static func sdkMajorVersion(_ version: String) -> Int? {
        let first = version.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".").first
        guard let first, let major = Int(first) else { return nil }
        return major
    }

    public static func targetFramework(sdkVersions: [String]) -> String {
        let majors = sdkVersions.compactMap { sdkMajorVersion($0) }
        guard let newest = majors.max(), newest >= 8 else { return "net8.0" }
        return "net\(newest).0"
    }

    public static func runtimeIdentifier(configuration: BuildConfiguration) -> String {
        switch configuration.architectures.first ?? .arm64 {
        case .x86_64: return "osx-x64"
        default: return "osx-arm64"
        }
    }

    public static func assemblyName(configuration: BuildConfiguration) -> String {
        var stem = configuration.outputFileName
        if let dot = stem.firstIndex(of: ".") { stem = String(stem[..<dot]) }
        if stem.isEmpty { stem = "Library" }
        return stem
    }

    public static func projectDirectory(projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent("Build/CSharp", isDirectory: true)
    }

    public static func csprojURL(projectRoot: URL, configuration: BuildConfiguration) -> URL {
        projectDirectory(projectRoot: projectRoot)
            .appendingPathComponent("\(SwiftBackend.moduleName(configuration: configuration)).csproj")
    }

    public static func csprojContents(configuration: BuildConfiguration, targetFramework: String) -> String {
        """
        <Project Sdk="Microsoft.NET.Sdk">
          <PropertyGroup>
            <TargetFramework>\(targetFramework)</TargetFramework>
            <OutputType>Library</OutputType>
            <AssemblyName>\(assemblyName(configuration: configuration))</AssemblyName>
            <PublishAot>true</PublishAot>
            <NativeLib>Shared</NativeLib>
            <ImplicitUsings>enable</ImplicitUsings>
            <Nullable>disable</Nullable>
          </PropertyGroup>
          <ItemGroup>
            <Compile Include="../../Sources/**/*.cs" />
          </ItemGroup>
        </Project>
        """
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        let fm = FileManager.default
        let dir = Self.projectDirectory(projectRoot: projectRoot)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let framework = Self.detectedTargetFramework()
        let contents = Self.csprojContents(configuration: configuration, targetFramework: framework)
        try contents.write(to: Self.csprojURL(projectRoot: projectRoot, configuration: configuration),
                           atomically: true, encoding: .utf8)
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        var args: [String] = []
        args.append("publish")
        args.append(Self.csprojURL(projectRoot: projectRoot, configuration: configuration).path)
        args.append("-c")
        args.append("Release")
        args.append("-r")
        args.append(Self.runtimeIdentifier(configuration: configuration))
        args.append("-o")
        args.append(output.deletingLastPathComponent().path)
        args.append(contentsOf: configuration.perBackendFlags["csharp"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics = Self.parseDotnetOutput(text, projectRoot: projectRoot)
        if !LibraryBackendSupport.anySourceContains(projectRoot: projectRoot, extensions: ["cs"], marker: "UnmanagedCallersOnly") {
            diagnostics.append(AssemblyDiagnostic(
                severity: .warning,
                message: "No [UnmanagedCallersOnly] export was found in the C# sources. NativeAOT shared libraries only export methods annotated with [UnmanagedCallersOnly]; without one the library has no callable exports.",
                origin: .projectConfiguration,
                suggestion: "Annotate each exported static method, for example [UnmanagedCallersOnly(EntryPoint = \"sc_add\")] public static int ScAdd(int a, int b) => a + b;"))
        }
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "NativeAOT shared libraries do not support dlclose unload: once loaded, the library stays loaded for the lifetime of the host process, and a second Assemble of the same library cannot be reloaded in the same process.",
            origin: .projectConfiguration))
        if let warning = LibraryBackendSupport.multiArchitectureWarning(projectRoot: projectRoot) {
            diagnostics.append(warning)
        }
        return diagnostics
    }

    static func parseDotnetOutput(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        let pattern = #"^(.+?)\((\d+),(\d+)\):\s+(error|warning)\s+([A-Z]+\d+):\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return diagnostics }
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges == 7,
               let fileRange = Range(match.range(at: 1), in: line),
               let lineRange = Range(match.range(at: 2), in: line),
               let colRange = Range(match.range(at: 3), in: line),
               let sevRange = Range(match.range(at: 4), in: line),
               let codeRange = Range(match.range(at: 5), in: line),
               let msgRange = Range(match.range(at: 6), in: line) {
                var file = String(line[fileRange])
                if file.hasPrefix(projectRoot.path) {
                    file = String(file.dropFirst(projectRoot.path.count + 1))
                }
                diagnostics.append(AssemblyDiagnostic(
                    severity: line[sevRange] == "error" ? .error : .warning,
                    message: "\(line[codeRange]): \(line[msgRange])",
                    file: file,
                    line: Int(line[lineRange]),
                    column: Int(line[colRange]),
                    origin: .userCode,
                    rawText: rawLine))
                continue
            }
            if line.contains("error") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .linker, rawText: rawLine))
            }
        }
        return diagnostics
    }

    private static func detectedTargetFramework() -> String {
        guard let dotnet = locateDotnet(),
              let output = try? ProcessRunnerRegistry.shared.run(
                executable: dotnet, arguments: ["--list-sdks"], environment: nil, currentDirectory: nil),
              output.status == 0 else { return "net8.0" }
        let versions = output.stdoutText.components(separatedBy: "\n").compactMap { line -> String? in
            line.split(separator: " ").first.map(String.init)
        }
        return targetFramework(sdkVersions: versions)
    }
}
