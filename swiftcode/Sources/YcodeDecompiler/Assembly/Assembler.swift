import Foundation

public struct AssemblyResult: Sendable {
    public var succeeded: Bool
    public var outputURL: URL
    public var diagnostics: [AssemblyDiagnostic]
    public var equivalence: EquivalenceReport?
    public var filesCompiled: [String]
    public var filesReused: [String]
    public var duration: TimeInterval
    public var compilerPath: String
    public var reportURL: URL?

    public init(succeeded: Bool, outputURL: URL, diagnostics: [AssemblyDiagnostic] = [],
                equivalence: EquivalenceReport? = nil, filesCompiled: [String] = [],
                filesReused: [String] = [], duration: TimeInterval = 0,
                compilerPath: String = "", reportURL: URL? = nil) {
        self.succeeded = succeeded
        self.outputURL = outputURL
        self.diagnostics = diagnostics
        self.equivalence = equivalence
        self.filesCompiled = filesCompiled
        self.filesReused = filesReused
        self.duration = duration
        self.compilerPath = compilerPath
        self.reportURL = reportURL
    }

    public var errors: [AssemblyDiagnostic] { diagnostics.filter { $0.severity == .error } }
    public var warnings: [AssemblyDiagnostic] { diagnostics.filter { $0.severity == .warning } }
}

public struct ObjectManifestEntry: Sendable, Codable {
    public var sourcePath: String
    public var objectPath: String
    public var sourceHash: String
    public var flagsHash: String
    public var backendID: String = ""

    public init(sourcePath: String, objectPath: String, sourceHash: String, flagsHash: String, backendID: String = "") {
        self.sourcePath = sourcePath
        self.objectPath = objectPath
        self.sourceHash = sourceHash
        self.flagsHash = flagsHash
        self.backendID = backendID
    }
}

public struct BackendSourceGroup: Sendable {
    public var backend: any AssembleBackend
    public var sources: [URL]

    public init(backend: any AssembleBackend, sources: [URL]) {
        self.backend = backend
        self.sources = sources
    }
}

public enum AssembleService {
    public static var sourceExtensions: Set<String> { BackendRegistry.allSourceExtensions() }

    public static func discoverSources(in projectRoot: URL) -> [URL] {
        let fm = FileManager.default
        let extensions = BackendRegistry.allSourceExtensions()
        var sources: [URL] = []
        for subdir in BackendRegistry.allDiscoveryRoots() {
            let dir = projectRoot.appendingPathComponent(subdir, isDirectory: true)
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator {
                if extensions.contains(url.pathExtension) {
                    sources.append(url)
                }
            }
        }
        return sources.sorted { $0.path < $1.path }
    }

    public static func groupSources(_ sources: [URL], selectedBackend: (any AssembleBackend)?) throws -> [BackendSourceGroup] {
        var groups: [String: BackendSourceGroup] = [:]
        var order: [String] = []
        for source in sources {
            let backend: any AssembleBackend
            if let selectedBackend {
                backend = selectedBackend
            } else if let resolved = BackendRegistry.backend(forExtension: source.pathExtension) {
                backend = resolved
            } else {
                throw DecompilerError.invalidRequest("No Assemble backend is registered for .\(source.pathExtension) files (\(source.lastPathComponent)). Registered extensions: \(BackendRegistry.allSourceExtensions().sorted().joined(separator: ", ")).")
            }
            if groups[backend.id] == nil {
                groups[backend.id] = BackendSourceGroup(backend: backend, sources: [])
                order.append(backend.id)
            }
            groups[backend.id]?.sources.append(source)
        }
        return order.compactMap { groups[$0] }
    }

    public static func locateCompiler(preferredPath: String? = nil) -> String? {
        let fm = FileManager.default
        if let preferredPath, fm.isExecutableFile(atPath: preferredPath) {
            return preferredPath
        }
        return ClangBackend.locateCompiler()
    }

    public static func locateViaXcrun() -> String? {
        BackendToolDiscovery.locateViaXcrun(tool: "clang")
    }

    public static func compilerGuidance(format: BinaryFormat) -> String {
        switch format {
        case .machO:
            return "No C compiler was found. Install Xcode or the Xcode Command Line Tools (xcode-select --install) and try again."
        default:
            return "No C compiler was found. Install clang or gcc and try again."
        }
    }

    public static func assemble(project: ReconstructedProject, originalImage: BinaryImage,
                                configuration: BuildConfiguration,
                                selectedBackendID: String? = nil,
                                initialDiagnostics: [AssemblyDiagnostic] = [],
                                progress: (@Sendable (AnalysisProgress) -> Void)? = nil) async throws -> AssemblyResult {
        let started = Date()
        let fm = FileManager.default
        let projectRoot = project.rootURL
        let format = originalImage.format
        var diagnostics = initialDiagnostics
        let selectedBackend = try resolveSelectedBackend(selectedBackendID)
        let sources = discoverSources(in: projectRoot)
        guard !sources.isEmpty else {
            throw DecompilerError.invalidRequest("No source files found in \(projectRoot.path); nothing to assemble.")
        }
        let grouped = try groupSources(sources, selectedBackend: selectedBackend)
        let objectsDir = projectRoot.appendingPathComponent("Build/Objects", isDirectory: true)
        try fm.createDirectory(at: objectsDir, withIntermediateDirectories: true)
        let outputURL = configuration.outputURL(in: projectRoot)
        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let manifestURL = objectsDir.appendingPathComponent("manifest.json")
        var manifest = loadObjectManifest(at: manifestURL)
        if diagnostics.contains(where: { $0.severity == .error }) {
            return try await finishFailure(project: project, originalImage: originalImage,
                                           configuration: configuration, outputURL: outputURL,
                                           diagnostics: diagnostics, compiled: [], reused: [],
                                           started: started, compiler: "")
        }
        var toolPaths: [String: String] = [:]
        for group in grouped {
            switch group.backend.availability(configuration: configuration) {
            case .available(let path, _):
                toolPaths[group.backend.id] = path
            case .unavailable(let reason, let guidance):
                throw DecompilerError.engineUnavailable("\(group.backend.displayName) is unavailable: \(reason) \(guidance)")
            }
        }
        var compiled: [String] = []
        var reused: [String] = []
        var objects: [URL] = []
        var allSources: [URL] = []
        var libraryBuilt = false
        var libraryToolPath = ""
        var globalIndex = 0
        let totalSources = sources.count
        for group in grouped {
            let backend = group.backend
            let groupSources = group.sources
            try backend.prepareProject(projectRoot: projectRoot, configuration: configuration)
            if backend.buildMode == .library {
                guard grouped.count == 1 else {
                    throw DecompilerError.invalidRequest("\(backend.displayName) builds a complete library in a single step and cannot be combined with sources for another language in one Assemble run. Keep the project to one library backend per Assemble run.")
                }
                try Task.checkCancellation()
                progress?(AnalysisProgress(stage: .building, fraction: 0,
                                           message: "Building \(configuration.outputFileName) with \(backend.displayName)",
                                           itemsProcessed: 0, itemsTotal: totalSources))
                preserveLastGood(outputURL: outputURL, projectRoot: projectRoot)
                let toolPath = toolPaths[backend.id] ?? ""
                let args = backend.libraryArguments(sources: groupSources, output: outputURL,
                                                    projectRoot: projectRoot, configuration: configuration)
                let output = try ProcessRunnerRegistry.shared.run(
                    executable: toolPath, arguments: args,
                    environment: backend.libraryEnvironment(configuration: configuration),
                    currentDirectory: backend.libraryWorkingDirectory(projectRoot: projectRoot, configuration: configuration))
                if output.status != 0 {
                    diagnostics.append(contentsOf: backend.parseDiagnostics(
                        output.stderrText + "\n" + output.stdoutText, projectRoot: projectRoot))
                    if diagnostics.allSatisfy({ $0.severity != .error }) {
                        diagnostics.append(AssemblyDiagnostic(
                            severity: .error, message: "\(backend.displayName) exited with status \(output.status).",
                            origin: .projectConfiguration, rawText: output.stderrText))
                    }
                    return try await finishFailure(project: project, originalImage: originalImage,
                                                   configuration: configuration, outputURL: outputURL,
                                                   diagnostics: diagnostics, compiled: compiled, reused: reused,
                                                   started: started, compiler: toolPath)
                }
                diagnostics.append(contentsOf: backend.parseDiagnostics(
                    output.stderrText + "\n" + output.stdoutText, projectRoot: projectRoot))
                compiled.append(contentsOf: groupSources.map { relativePath(of: $0, projectRoot: projectRoot) })
                allSources.append(contentsOf: groupSources)
                libraryBuilt = true
                libraryToolPath = toolPath
                continue
            }
            let flagsHash = CacheManager.fnv1a64([
                backend.id,
                toolPaths[backend.id] ?? "",
                configuration.architectures.map(\.rawValue).joined(separator: ","),
                configuration.deploymentTarget ?? "",
                configuration.sdk ?? "",
                configuration.compilerFlags.joined(separator: " "),
                configuration.optimizationLevel,
                configuration.symbolVisibility,
                (configuration.perBackendFlags[backend.id] ?? []).joined(separator: " ")
            ].joined(separator: "\n"))
            for source in groupSources {
                try Task.checkCancellation()
                progress?(AnalysisProgress(stage: .building,
                                           fraction: Double(globalIndex) / Double(totalSources),
                                           message: "Compiling \(source.lastPathComponent)",
                                           itemsProcessed: globalIndex, itemsTotal: totalSources))
                let relative = relativePath(of: source, projectRoot: projectRoot)
                let objectName = relative.replacingOccurrences(of: "/", with: "_") + ".o"
                let objectURL = objectsDir.appendingPathComponent(objectName)
                let sourceHash = (try? fnv1a64(Data(contentsOf: source))) ?? ""
                if let entry = manifest[relative], entry.sourceHash == sourceHash,
                   entry.flagsHash == flagsHash, entry.backendID == backend.id,
                   fm.fileExists(atPath: objectURL.path) {
                    reused.append(relative)
                    objects.append(objectURL)
                    globalIndex += 1
                    continue
                }
                let args = backend.compileArguments(source: source, object: objectURL,
                                                    projectRoot: projectRoot, configuration: configuration)
                let toolPath = toolPaths[backend.id] ?? ""
                let output = try ProcessRunnerRegistry.shared.run(
                    executable: toolPath, arguments: args, environment: nil, currentDirectory: nil)
                if output.status != 0 {
                    diagnostics.append(contentsOf: backend.parseDiagnostics(
                        output.stderrText + "\n" + output.stdoutText, projectRoot: projectRoot))
                    if diagnostics.allSatisfy({ $0.severity != .error }) {
                        diagnostics.append(AssemblyDiagnostic(
                            severity: .error, message: "Compiler exited with status \(output.status) for \(relative).",
                            file: relative, origin: .projectConfiguration,
                            rawText: output.stderrText))
                    }
                    return try await finishFailure(project: project, originalImage: originalImage,
                                                   configuration: configuration, outputURL: outputURL,
                                                   diagnostics: diagnostics, compiled: compiled, reused: reused,
                                                   started: started, compiler: toolPath)
                }
                diagnostics.append(contentsOf: backend.parseDiagnostics(
                    output.stderrText + "\n" + output.stdoutText, projectRoot: projectRoot))
                manifest[relative] = ObjectManifestEntry(sourcePath: relative, objectPath: objectName,
                                                         sourceHash: sourceHash, flagsHash: flagsHash,
                                                         backendID: backend.id)
                compiled.append(relative)
                objects.append(objectURL)
                globalIndex += 1
            }
            diagnostics.append(contentsOf: backend.postCompileDiagnostics(
                sources: groupSources, projectRoot: projectRoot, configuration: configuration))
            allSources.append(contentsOf: groupSources)
        }
        saveObjectManifest(manifest, at: manifestURL)
        var compiler: String
        if !libraryBuilt {
            try Task.checkCancellation()
            progress?(AnalysisProgress(stage: .linking, message: "Linking \(configuration.outputFileName)"))
            preserveLastGood(outputURL: outputURL, projectRoot: projectRoot)
            let linkBackend = resolveLinkBackend(grouped: grouped, selectedBackend: selectedBackend)
            let linkToolPath = toolPaths[linkBackend.id] ?? ""
            compiler = linkToolPath
            let linkArgs = linkBackend.linkArguments(objects: objects, sources: allSources,
                                                     output: outputURL, configuration: configuration)
            let linkOutput = try ProcessRunnerRegistry.shared.run(
                executable: linkToolPath, arguments: linkArgs, environment: nil, currentDirectory: nil)
            if linkOutput.status != 0 {
                diagnostics.append(contentsOf: AssemblyDiagnosticParser.parseLinkerOutput(
                    linkOutput.stderrText + "\n" + linkOutput.stdoutText))
                if diagnostics.allSatisfy({ $0.severity != .error }) {
                    diagnostics.append(AssemblyDiagnostic(
                        severity: .error, message: "Linker exited with status \(linkOutput.status).",
                        origin: .linker, rawText: linkOutput.stderrText))
                }
                return try await finishFailure(project: project, originalImage: originalImage,
                                               configuration: configuration, outputURL: outputURL,
                                               diagnostics: diagnostics, compiled: compiled, reused: reused,
                                               started: started, compiler: compiler)
            }
            diagnostics.append(contentsOf: AssemblyDiagnosticParser.parseLinkerOutput(linkOutput.stderrText))
            if configuration.architectures.count > 1 && !linkBackend.handlesMultipleArchitectures {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    message: "\(linkBackend.displayName) builds one architecture per invocation, so the output covers \(configuration.architectures.first?.displayName ?? "a single architecture") only; the configured architectures (\(configuration.architectures.map(\.displayName).joined(separator: ", "))) were not all built. Build once per architecture and combine with lipo for a universal library.",
                    origin: .projectConfiguration))
            }
        } else {
            compiler = libraryToolPath
        }
        if format == .machO {
            await codeSign(outputURL: outputURL, identity: configuration.codeSignIdentity,
                           diagnostics: &diagnostics)
        }
        try Task.checkCancellation()
        progress?(AnalysisProgress(stage: .linking, message: "Validating \(configuration.outputFileName)"))
        var formatValid = false
        var rebuiltImage: BinaryImage?
        do {
            let loader = BinaryLoader()
            let container = try await loader.loadContainer(at: outputURL)
            rebuiltImage = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: outputURL)
            formatValid = true
        } catch {
            diagnostics.append(AssemblyDiagnostic(
                severity: .error,
                message: "The linked output could not be parsed as a valid \(format.displayName) binary: \(error.localizedDescription)",
                origin: .linker, rawText: ""))
        }
        let equivalence: EquivalenceReport?
        if let rebuiltImage {
            let compared = EquivalenceChecker.compare(original: originalImage, rebuilt: rebuiltImage,
                                                      buildSucceeded: true, formatValid: formatValid)
            equivalence = compared
            if !compared.missingExports.isEmpty {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    message: "Rebuilt library is missing \(compared.missingExports.count) export(s) from the original: \(compared.missingExports.map(\.name).joined(separator: ", ")).",
                    origin: .linker))
            }
        } else {
            equivalence = EquivalenceReport(buildSucceeded: true, formatValid: false,
                                            verdict: .unknown, formatMatches: false,
                                            architectureMatches: false, installNameMatches: false)
        }
        let succeeded = diagnostics.allSatisfy { $0.severity != .error } && formatValid
        let reportURL = try writeBuildReport(project: project, configuration: configuration,
                                             result: AssemblyResult(
                                                succeeded: succeeded, outputURL: outputURL,
                                                diagnostics: diagnostics, equivalence: equivalence,
                                                filesCompiled: compiled, filesReused: reused,
                                                duration: Date().timeIntervalSince(started),
                                                compilerPath: compiler),
                                             originalImage: originalImage)
        return AssemblyResult(succeeded: succeeded, outputURL: outputURL, diagnostics: diagnostics,
                              equivalence: equivalence, filesCompiled: compiled, filesReused: reused,
                              duration: Date().timeIntervalSince(started), compilerPath: compiler,
                              reportURL: reportURL)
    }

    private static func resolveSelectedBackend(_ id: String?) throws -> (any AssembleBackend)? {
        guard let id else { return nil }
        guard let backend = BackendRegistry.backend(id: id) else {
            throw DecompilerError.invalidRequest("Unknown Assemble backend '\(id)'. Registered backends: \(BackendRegistry.allBackends().map(\.id).sorted().joined(separator: ", ")).")
        }
        return backend
    }

    private static func resolveLinkBackend(grouped: [BackendSourceGroup], selectedBackend: (any AssembleBackend)?) -> any AssembleBackend {
        if let selectedBackend, selectedBackend.buildMode == .object {
            return selectedBackend
        }
        if let nonClang = grouped.first(where: { $0.backend.buildMode == .object && !($0.backend is ClangBackend) }) {
            return nonClang.backend
        }
        return ClangBackend()
    }

    private static func relativePath(of url: URL, projectRoot: URL) -> String {
        url.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
    }

    private static func finishFailure(project: ReconstructedProject, originalImage: BinaryImage,
                                      configuration: BuildConfiguration,
                                      outputURL: URL, diagnostics: [AssemblyDiagnostic],
                                      compiled: [String], reused: [String], started: Date,
                                      compiler: String) async throws -> AssemblyResult {
        let reportURL = try writeBuildReport(project: project, configuration: configuration,
                                             result: AssemblyResult(
                                                succeeded: false, outputURL: outputURL,
                                                diagnostics: diagnostics, equivalence: nil,
                                                filesCompiled: compiled, filesReused: reused,
                                                duration: Date().timeIntervalSince(started),
                                                compilerPath: compiler),
                                             originalImage: originalImage)
        return AssemblyResult(succeeded: false, outputURL: outputURL, diagnostics: diagnostics,
                              equivalence: nil, filesCompiled: compiled, filesReused: reused,
                              duration: Date().timeIntervalSince(started), compilerPath: compiler,
                              reportURL: reportURL)
    }

    private static func preserveLastGood(outputURL: URL, projectRoot: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: outputURL.path) else { return }
        let lastGoodDir = projectRoot.appendingPathComponent("Build/LastGood", isDirectory: true)
        try? fm.createDirectory(at: lastGoodDir, withIntermediateDirectories: true)
        let dest = lastGoodDir.appendingPathComponent(outputURL.lastPathComponent)
        try? fm.removeItem(at: dest)
        try? fm.copyItem(at: outputURL, to: dest)
    }

    private static func codeSign(outputURL: URL, identity: String?,
                                 diagnostics: inout [AssemblyDiagnostic]) async {
        let signIdentity = identity ?? "-"
        let codesign = "/usr/bin/codesign"
        guard FileManager.default.isExecutableFile(atPath: codesign) else { return }
        do {
            let output = try ProcessRunnerRegistry.shared.run(
                executable: codesign, arguments: ["--force", "--sign", signIdentity, outputURL.path],
                environment: nil, currentDirectory: nil)
            if output.status != 0 {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    message: "Ad-hoc code signing failed (\(output.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))); the library is still usable for local testing.",
                    origin: .projectConfiguration, rawText: output.stderrText))
            }
        } catch {
            diagnostics.append(AssemblyDiagnostic(
                severity: .warning,
                message: "Code signing could not run: \(error.localizedDescription)",
                origin: .projectConfiguration, rawText: ""))
        }
    }

    private static func fnv1a64(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16, uppercase: false)
    }

    private static func loadObjectManifest(at url: URL) -> [String: ObjectManifestEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ObjectManifestEntry].self, from: data) else {
            return [:]
        }
        var out: [String: ObjectManifestEntry] = [:]
        for entry in entries { out[entry.sourcePath] = entry }
        return out
    }

    private static func saveObjectManifest(_ manifest: [String: ObjectManifestEntry], at url: URL) {
        let entries = manifest.values.sorted { $0.sourcePath < $1.sourcePath }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url)
    }

    private static func writeBuildReport(project: ReconstructedProject,
                                         configuration: BuildConfiguration,
                                         result: AssemblyResult,
                                         originalImage: BinaryImage) throws -> URL {
        let reportURL = project.rootURL.appendingPathComponent("Build/build-report.md")
        var lines: [String] = []
        lines.append("# Build Report — \(project.libraryName)")
        lines.append("")
        lines.append("Date: \(Date())")
        lines.append("Compiler: \(result.compilerPath)")
        lines.append("Output: \(result.outputURL.path)")
        lines.append("Result: \(result.succeeded ? "succeeded" : "failed")")
        lines.append("Duration: \(String(format: "%.2f", result.duration))s")
        lines.append("Files compiled: \(result.filesCompiled.count) (\(result.filesCompiled.joined(separator: ", ")))")
        lines.append("Files reused (incremental): \(result.filesReused.count)")
        lines.append("")
        if let equivalence = result.equivalence {
            lines.append("## Equivalence vs original")
            lines.append("")
            lines.append("Verdict: \(equivalence.verdict.rawValue)")
            lines.append("Format valid: \(equivalence.formatValid)")
            lines.append("Format matches: \(equivalence.formatMatches)")
            lines.append("Architecture matches: \(equivalence.architectureMatches)")
            lines.append("Install name matches: \(equivalence.installNameMatches)")
            lines.append("ABI compatible (no missing exports): \(equivalence.isABICompatible)")
            if !equivalence.exportDifferences.isEmpty {
                lines.append("Export differences:")
                for diff in equivalence.exportDifferences {
                    lines.append("- \(diff.kind.rawValue): \(diff.name) — \(diff.detail)")
                }
            }
            for note in equivalence.notes {
                lines.append("- \(note)")
            }
            lines.append("")
            lines.append("Behavioral equivalence: \(equivalence.behavioralEquivalence)")
            lines.append("")
        }
        lines.append("## Diagnostics")
        if result.diagnostics.isEmpty {
            lines.append("None.")
        } else {
            for diag in result.diagnostics {
                lines.append("- [\(diag.severity.rawValue)] \(diag.displayLocation) \(diag.message)")
                if let suggestion = diag.suggestion {
                    lines.append("  Suggestion: \(suggestion)")
                }
            }
        }
        try lines.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }
}
