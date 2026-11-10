import Foundation
import YcodeSubprocess

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

    public init(sourcePath: String, objectPath: String, sourceHash: String, flagsHash: String) {
        self.sourcePath = sourcePath
        self.objectPath = objectPath
        self.sourceHash = sourceHash
        self.flagsHash = flagsHash
    }
}

public enum AssembleService {
    public static let sourceExtensions: Set<String> = ["c", "m", "mm", "cpp", "cc", "cxx", "s", "S"]

    public static func discoverSources(in projectRoot: URL) -> [URL] {
        let fm = FileManager.default
        var sources: [URL] = []
        for subdir in ["Sources", "Assembly"] {
            let dir = projectRoot.appendingPathComponent(subdir, isDirectory: true)
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator {
                if sourceExtensions.contains(url.pathExtension) {
                    sources.append(url)
                }
            }
        }
        return sources.sorted { $0.path < $1.path }
    }

    public static func locateCompiler(preferredPath: String? = nil) -> String? {
        let fm = FileManager.default
        if let preferredPath, fm.isExecutableFile(atPath: preferredPath) {
            return preferredPath
        }
        if let xcrun = locateViaXcrun() { return xcrun }
        for candidate in ["/usr/bin/clang", "/usr/local/bin/clang", "/opt/homebrew/bin/clang",
                          "/usr/bin/cc", "/usr/bin/gcc", "/usr/local/bin/gcc"] {
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for dir in pathDirs {
            for tool in ["clang", "cc", "gcc"] {
                let candidate = (dir as NSString).appendingPathComponent(tool)
                if fm.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    public static func locateViaXcrun() -> String? {
        for xcrun in ["/usr/bin/xcrun", "/bin/xcrun"] {
            guard FileManager.default.isExecutableFile(atPath: xcrun) else { continue }
            guard let out = try? Subprocess.run(xcrun, ["-f", "clang"], captureStderr: false),
                  out.status == 0 else { continue }
            let path = out.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
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
                                progress: (@Sendable (AnalysisProgress) -> Void)? = nil) async throws -> AssemblyResult {
        let started = Date()
        let fm = FileManager.default
        let projectRoot = project.rootURL
        let format = originalImage.format
        guard let compiler = locateCompiler(preferredPath: configuration.compilerPath) else {
            throw DecompilerError.engineUnavailable(compilerGuidance(format: format))
        }
        let sources = discoverSources(in: projectRoot)
        guard !sources.isEmpty else {
            throw DecompilerError.invalidRequest("No source files found in \(projectRoot.path); nothing to assemble.")
        }
        let objectsDir = projectRoot.appendingPathComponent("Build/Objects", isDirectory: true)
        try fm.createDirectory(at: objectsDir, withIntermediateDirectories: true)
        let outputURL = configuration.outputURL(in: projectRoot)
        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let manifestURL = objectsDir.appendingPathComponent("manifest.json")
        var manifest = loadObjectManifest(at: manifestURL)
        var diagnostics: [AssemblyDiagnostic] = []
        var compiled: [String] = []
        var reused: [String] = []
        var objects: [URL] = []
        let flagsHash = CacheManager.fnv1a64(configuration.compilerFlags.joined(separator: " ")
            + configuration.optimizationLevel + configuration.symbolVisibility)

        for (index, source) in sources.enumerated() {
            try Task.checkCancellation()
            progress?(AnalysisProgress(stage: .building,
                                       fraction: Double(index) / Double(sources.count),
                                       message: "Compiling \(source.lastPathComponent)",
                                       itemsProcessed: index, itemsTotal: sources.count))
            let relative = source.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            let objectName = relative.replacingOccurrences(of: "/", with: "_") + ".o"
            let objectURL = objectsDir.appendingPathComponent(objectName)
            let sourceHash = (try? fnv1a64(Data(contentsOf: source))) ?? ""
            if let entry = manifest[relative], entry.sourceHash == sourceHash,
               entry.flagsHash == flagsHash, fm.fileExists(atPath: objectURL.path) {
                reused.append(relative)
                objects.append(objectURL)
                continue
            }
            let args = configuration.compileArguments(source: source, object: objectURL,
                                                      projectRoot: projectRoot, format: format)
            let output = try Subprocess.run(compiler, args, captureStderr: true)
            if output.status != 0 {
                diagnostics.append(contentsOf: AssemblyDiagnosticParser.parseCompilerOutput(
                    output.stderrText + "\n" + output.stdoutText, projectRoot: projectRoot))
                if diagnostics.allSatisfy({ $0.severity != .error }) {
                    diagnostics.append(AssemblyDiagnostic(
                        severity: .error, message: "Compiler exited with status \(output.status) for \(relative).",
                        file: relative, origin: .projectConfiguration,
                        rawText: output.stderrText))
                }
                let result = try await finishFailure(project: project, originalImage: originalImage,
                                                     outputURL: outputURL, diagnostics: diagnostics,
                                                     compiled: compiled, reused: reused,
                                                     started: started, compiler: compiler)
                return result
            }
            let newDiagnostics = AssemblyDiagnosticParser.parseCompilerOutput(
                output.stderrText + "\n" + output.stdoutText, projectRoot: projectRoot)
            diagnostics.append(contentsOf: newDiagnostics)
            manifest[relative] = ObjectManifestEntry(sourcePath: relative, objectPath: objectName,
                                                     sourceHash: sourceHash, flagsHash: flagsHash)
            compiled.append(relative)
            objects.append(objectURL)
        }
        saveObjectManifest(manifest, at: manifestURL)
        try Task.checkCancellation()
        progress?(AnalysisProgress(stage: .linking, message: "Linking \(configuration.outputFileName)"))

        preserveLastGood(outputURL: outputURL, projectRoot: projectRoot)
        let linkArgs = configuration.linkArguments(objects: objects, output: outputURL, format: format)
        let linkOutput = try Subprocess.run(compiler, linkArgs, captureStderr: true)
        if linkOutput.status != 0 {
            diagnostics.append(contentsOf: AssemblyDiagnosticParser.parseLinkerOutput(
                linkOutput.stderrText + "\n" + linkOutput.stdoutText))
            if diagnostics.allSatisfy({ $0.severity != .error }) {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .error, message: "Linker exited with status \(linkOutput.status).",
                    origin: .linker, rawText: linkOutput.stderrText))
            }
            return try await finishFailure(project: project, originalImage: originalImage,
                                           outputURL: outputURL, diagnostics: diagnostics,
                                           compiled: compiled, reused: reused,
                                           started: started, compiler: compiler)
        }
        diagnostics.append(contentsOf: AssemblyDiagnosticParser.parseLinkerOutput(linkOutput.stderrText))

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

    private static func finishFailure(project: ReconstructedProject, originalImage: BinaryImage,
                                      outputURL: URL, diagnostics: [AssemblyDiagnostic],
                                      compiled: [String], reused: [String], started: Date,
                                      compiler: String) async throws -> AssemblyResult {
        let reportURL = try writeBuildReport(project: project, configuration: project.configuration,
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
            let output = try Subprocess.run(codesign, ["--force", "--sign", signIdentity, outputURL.path],
                                            captureStderr: true)
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
