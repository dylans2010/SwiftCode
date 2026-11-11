import Foundation

public struct JavaNativeBackend: AssembleBackend {
    public init() {}

    public var id: String { "java-native" }
    public var displayName: String { "Java (GraalVM Native Image)" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["java"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let found = Self.locateNativeImage() else {
            return .unavailable(
                reason: "No GraalVM native-image tool was found.",
                installGuidance: "Install a GraalVM JDK from https://www.graalvm.org/downloads/ (or sdk install java <graalvm-version>) and make sure native-image is on PATH, then try again.")
        }
        guard Self.locateJavac(nativeImagePath: found) != nil else {
            return .unavailable(
                reason: "GraalVM native-image was found, but no javac next to it or on PATH.",
                installGuidance: "Use a full GraalVM JDK installation so javac sits beside native-image, and make sure both are on PATH, then try again.")
        }
        return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found, arguments: ["--version"]))
    }

    public static func locateNativeImage() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/opt/homebrew/bin/native-image", "/usr/local/bin/native-image",
                         "~/.sdkman/candidates/java/current/bin/native-image"],
            pathNames: ["native-image"])
    }

    public static func locateJavac(nativeImagePath: String? = nil) -> String? {
        if let nativeImagePath {
            let binDir = URL(fileURLWithPath: nativeImagePath).deletingLastPathComponent()
            let sibling = binDir.appendingPathComponent("javac").path
            if FileManager.default.isExecutableFile(atPath: sibling) { return sibling }
        }
        return BackendToolDiscovery.locateOnPATH(["javac"])
    }

    public static func classesDirectory(projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent("Build/JavaNative/classes", isDirectory: true)
    }

    public static func javaSources(projectRoot: URL) -> [URL] {
        let fm = FileManager.default
        let dir = projectRoot.appendingPathComponent("Sources", isDirectory: true)
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var sources: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "java" {
            sources.append(url)
        }
        return sources.sorted { $0.path < $1.path }
    }

    public static func entryClassName(sources: [URL]) -> String? {
        var fallback: String?
        for source in sources {
            guard let text = try? String(contentsOf: source, encoding: .utf8),
                  let name = className(in: text) else { continue }
            if fallback == nil { fallback = name }
            if text.contains("@CEntryPoint") { return name }
        }
        return fallback
    }

    static func className(in text: String) -> String? {
        var packagePrefix = ""
        let pattern = #"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("package ") {
                let name = line.dropFirst("package ".count)
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
                if !name.isEmpty { packagePrefix = name + "." }
                continue
            }
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges == 2,
               let nameRange = Range(match.range(at: 1), in: line) {
                return packagePrefix + String(line[nameRange])
            }
        }
        return nil
    }

    static func libraryName(configuration: BuildConfiguration) -> String {
        var stem = configuration.outputFileName
        if let dot = stem.firstIndex(of: ".") { stem = String(stem[..<dot]) }
        if stem.isEmpty { stem = "Library" }
        return stem
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        guard let nativeImage = Self.locateNativeImage() else {
            throw DecompilerError.engineUnavailable("GraalVM native-image was not found. Install a GraalVM JDK from https://www.graalvm.org/downloads/ and make sure native-image is on PATH.")
        }
        guard let javac = Self.locateJavac(nativeImagePath: nativeImage) else {
            throw DecompilerError.engineUnavailable("No javac was found next to native-image or on PATH. Use a full GraalVM JDK installation.")
        }
        let sources = Self.javaSources(projectRoot: projectRoot)
        guard !sources.isEmpty else {
            throw DecompilerError.invalidRequest("No Java sources were found under Sources/; nothing to assemble.")
        }
        let hasEntryPoint = sources.contains { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
            return text.contains("@CEntryPoint")
        }
        let hasMain = sources.contains { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
            return text.contains("static void main(") || text.contains("static void main (")
        }
        guard hasEntryPoint || hasMain else {
            throw DecompilerError.invalidRequest("No @CEntryPoint export was found in the Java sources. Annotate each exported static method with @CEntryPoint(name = \"exported_name\") and give it an IsolateThread first parameter, or the library will have no callable exports.")
        }
        let classesDir = Self.classesDirectory(projectRoot: projectRoot)
        try FileManager.default.createDirectory(at: classesDir, withIntermediateDirectories: true)
        let output = try ProcessRunnerRegistry.shared.run(
            executable: javac,
            arguments: ["-d", classesDir.path] + sources.map(\.path),
            environment: nil, currentDirectory: nil)
        guard output.status == 0 else {
            throw DecompilerError.engineFailure("javac exited with status \(output.status):\n\(output.stderrText)\(output.stdoutText)")
        }
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        var args: [String] = []
        args.append("--shared")
        args.append("-H:Name=\(Self.libraryName(configuration: configuration))")
        args.append("-cp")
        args.append(Self.classesDirectory(projectRoot: projectRoot).path)
        if let entry = Self.entryClassName(sources: sources) {
            args.append(entry)
        }
        args.append(contentsOf: configuration.perBackendFlags["java-native"] ?? [])
        return args
    }

    public func libraryWorkingDirectory(projectRoot: URL, configuration: BuildConfiguration) -> URL? {
        configuration.outputURL(in: projectRoot).deletingLastPathComponent()
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("Error:") || line.hasPrefix("error:") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .linker, rawText: rawLine))
                continue
            }
            if line.hasPrefix("Warning:") || line.hasPrefix("warning:") {
                diagnostics.append(AssemblyDiagnostic(severity: .warning, message: line,
                                                      origin: .linker, rawText: rawLine))
                continue
            }
            if line.contains("error:") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .linker, rawText: rawLine))
            }
        }
        if !LibraryBackendSupport.anySourceContains(projectRoot: projectRoot, extensions: ["java"], marker: "@CEntryPoint") {
            diagnostics.append(AssemblyDiagnostic(
                severity: .warning,
                message: "No @CEntryPoint export was found in the Java sources. Only main() or methods annotated with @CEntryPoint are callable from native code.",
                origin: .projectConfiguration,
                suggestion: "Annotate each exported static method with @CEntryPoint(name = \"exported_name\") and give it an IsolateThread first parameter; entry-point parameters and return types must be non-object types."))
        }
        if text.contains("reflect-config") || text.contains("ReflectionConfiguration") || text.contains("closed world") {
            diagnostics.append(AssemblyDiagnostic(
                severity: .warning,
                message: "Native Image closed-world analysis could not reach something the code uses through reflection, a dynamic proxy, or JNI. Such uses fail at build time or at runtime unless they are declared explicitly.",
                origin: .projectConfiguration,
                suggestion: "Add a reflection configuration file and pass it with -H:ReflectionConfigurationFiles=<path> via the java-native per-backend flags, or rewrite the reflective access as direct calls."))
        }
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "GraalVM entry points take an IsolateThread (or Isolate) first parameter and only non-object parameter and return types. Callers must create an isolate with graal_create_isolate and pass the thread to every entry point; the header generated next to the library declares the exact C signatures.",
            origin: .projectConfiguration))
        if let warning = LibraryBackendSupport.multiArchitectureWarning(projectRoot: projectRoot) {
            diagnostics.append(warning)
        }
        return diagnostics
    }
}
