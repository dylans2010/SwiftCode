import Foundation
import YcodeSubprocess

/// Decompilation backend that drives Ghidra's `analyzeHeadless`.
///
/// Workflow per binary:
///  1. `ensureImported` runs `analyzeHeadless <projDir> <name> -import <file>`
///     once; Ghidra's built-in auto-analysis populates functions, symbols and
///     data. A marker file records success so later requests skip the import.
///  2. `decompile` runs `analyzeHeadless <projDir> <name> -process <program>
///     -noanalysis -postScript DecompileDump.py <out.json> <addrHex>`.
///     `-noanalysis` reuses the imported analysis; the Jython script decompiles
///     only the requested function and emits JSON lines that are mapped onto
///     `DecompilationResult`.
///
/// Projects live under `NSTemporaryDirectory()/SwiftCodeDecompiler/
/// ghidra-projects/<fnv1a(imagePath)>` and entries older than 7 days are
/// pruned opportunistically.
///
/// Known limitation: Ghidra imports a fat/universal Mach-O as multiple
/// programs. The `-process <programName>` call targets the program named
/// after the file; if that fails the backend retries with `-process` (all
/// programs) and the script's address filter still selects the right
/// function.
public struct GhidraDecompiler: DecompilerProvider {
    public let id = "ghidra"
    public let displayName = "Ghidra"
    public let isPrimary = true

    public var version: String? { Self.state.version }

    private static let state = GhidraState()

    public init() {}

    // MARK: - Provider contract

    public func isAvailable() async -> Bool {
        await Task.detached(priority: .utility) {
            Self.state.ghidraHome() != nil && Self.state.checkJava()
        }.value
    }

    public func availabilityDetail() async -> String {
        await Task.detached(priority: .utility) { () -> String in
            if Self.state.ghidraHome() == nil {
                return "Ghidra not found. Set SWIFTCODE_GHIDRA_HOME or " +
                    "GHIDRA_INSTALL_DIR to your Ghidra installation " +
                    "(also checked ~/ghidra*, /opt, /usr/local, /Applications)."
            }
            if !Self.state.checkJava() {
                return "Java runtime not found on PATH (Ghidra requires Java 21+)."
            }
            return ""
        }.value
    }

    public func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet {
        _ = image
        guard Self.state.ghidraHome() != nil else { return [] }
        return [
            .decompileFunction, .decompileBatch, .functionDiscovery,
            .typeRecovery, .crossReferences, .controlFlowGraph, .callGraph,
        ]
    }

    public func decompile(_ request: DecompilationRequest,
                          progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> DecompilationResult {
        var imported: [String: ProjectPaths] = [:]
        return try await decompileSingle(request, progress: progress, imported: &imported)
    }

    /// Batch decompilation. Each request still gets its own headless
    /// `-process` invocation (with `-noanalysis`, so only the decompiler runs);
    /// the expensive `-import` + auto-analysis step is shared per image via
    /// the `imported` cache. A single dump-all run would be faster for very
    /// large batches but is not implemented.
    public func decompileBatch(_ requests: [DecompilationRequest],
                               progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DecompilationResult] {
        var results: [DecompilationResult] = []
        results.reserveCapacity(requests.count)
        var imported: [String: ProjectPaths] = [:]
        for (index, request) in requests.enumerated() {
            try Task.checkCancellation()
            let fraction = requests.isEmpty ? nil : Double(index) / Double(requests.count)
            progress?(AnalysisProgress(
                stage: .decompiling,
                fraction: fraction,
                message: "Decompiling \(request.functionName ?? request.functionAddress.hexString)",
                itemsProcessed: index,
                itemsTotal: requests.count))
            results.append(try await decompileSingle(request, progress: nil, imported: &imported))
        }
        return results
    }

    // MARK: - Internals

    private struct ProjectPaths: Sendable {
        var dir: URL
        var projectName: String
        var programName: String
        var scriptDir: URL
    }

    private func decompileSingle(_ request: DecompilationRequest,
                                 progress: (@Sendable (AnalysisProgress) -> Void)?,
                                 imported: inout [String: ProjectPaths]) async throws -> DecompilationResult {
        guard await isAvailable() else {
            throw DecompilerError.engineUnavailable(await availabilityDetail())
        }
        let paths: ProjectPaths
        if let cached = imported[request.imagePath] {
            paths = cached
        } else {
            let p = try projectPaths(for: request.imagePath)
            try await ensureImported(imagePath: request.imagePath, paths: p, progress: progress)
            imported[request.imagePath] = p
            paths = p
        }

        let outURL = paths.dir.appendingPathComponent("decompile-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outURL) }

        let addrArg = request.functionAddress.hexString
        let scriptArgs = ["-scriptPath", paths.scriptDir.path,
                          "-postScript", "DecompileDump.py",
                          outURL.path, addrArg]
        var args = [paths.dir.path, paths.projectName,
                    "-process", paths.programName, "-noanalysis"] + scriptArgs
        progress?(AnalysisProgress(stage: .decompiling,
                                   message: "Decompiling \(request.functionName ?? request.functionAddress.hexString) with Ghidra"))
        do {
            try await runHeadless(args: args)
        } catch let error as DecompilerError {
            // Retry across all programs in the project: fat Mach-O imports can
            // produce program names that differ from the plain file name.
            guard case .engineFailure = error else { throw error }
            args = [paths.dir.path, paths.projectName,
                    "-process", "-noanalysis"] + scriptArgs
            try await runHeadless(args: args)
        }

        return try parseResult(outURL: outURL, request: request)
    }

    // MARK: - Ghidra project management

    private func projectPaths(for imagePath: String) throws -> ProjectPaths {
        // FNV-1a 64-bit — stable, dependency-free hash for the project dir.
        var hash: UInt64 = 14695981039346656037
        for byte in imagePath.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        let hex = String(hash, radix: 16)
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftCodeDecompiler/ghidra-projects", isDirectory: true)
        let script = try scriptURL()
        return ProjectPaths(
            dir: base.appendingPathComponent("proj-\(hex)", isDirectory: true),
            projectName: "swiftcode-\(hex)",
            programName: URL(fileURLWithPath: imagePath).lastPathComponent,
            scriptDir: script.deletingLastPathComponent())
    }

    private func ensureImported(imagePath: String,
                                paths: ProjectPaths,
                                progress: (@Sendable (AnalysisProgress) -> Void)?) async throws {
        let fm = FileManager.default
        let marker = paths.dir.appendingPathComponent(".swiftcode-imported")
        let gpr = paths.dir.appendingPathComponent("\(paths.projectName).gpr")
        if fm.fileExists(atPath: marker.path), fm.fileExists(atPath: gpr.path) {
            return
        }
        // Stale/partial project: start clean so `-import` cannot conflict.
        if fm.fileExists(atPath: paths.dir.path) {
            try? fm.removeItem(at: paths.dir)
        }
        try fm.createDirectory(at: paths.dir, withIntermediateDirectories: true)
        Self.pruneOldProjects(in: paths.dir.deletingLastPathComponent())

        guard fm.fileExists(atPath: imagePath) else {
            throw DecompilerError.invalidRequest("binary not found: \(imagePath)")
        }
        progress?(AnalysisProgress(
            stage: .importing,
            message: "Importing \(URL(fileURLWithPath: imagePath).lastPathComponent) into Ghidra"))

        // -import runs Ghidra's full auto-analysis pipeline.
        let args = [paths.dir.path, paths.projectName,
                    "-import", imagePath,
                    "-scriptPath", paths.scriptDir.path]
        try await runHeadless(args: args)
        try Data().write(to: marker)
    }

    /// Delete project dirs older than 7 days. Cheap, best-effort.
    private static func pruneOldProjects(in base: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: base, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            try? fm.removeItem(at: entry)
        }
    }

    // MARK: - Headless invocation

    private func runHeadless(args: [String]) async throws {
        guard let home = Self.state.ghidraHome() else {
            throw DecompilerError.engineUnavailable(await availabilityDetail())
        }
        let executable = home.appendingPathComponent("support/analyzeHeadless")
        let stream = StreamingSubprocess.lines(executable, args)
        do {
            // Drain stdout; all real output goes to files.
            for try await _ in stream { }
        } catch let error as StreamingSubprocess.ExitError {
            if error.wasInterrupted {
                throw DecompilerError.engineCancelled("analyzeHeadless")
            }
            let tail = error.stderrTail
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = tail.isEmpty ? "" : ": \(String(tail.suffix(600)))"
            throw DecompilerError.engineFailure(
                "analyzeHeadless exited with status \(error.status)\(suffix)")
        } catch is CancellationError {
            throw DecompilerError.engineCancelled("analyzeHeadless")
        }
    }

    // MARK: - Output parsing

    private func parseResult(outURL: URL, request: DecompilationRequest) throws -> DecompilationResult {
        guard let data = try? Data(contentsOf: outURL), !data.isEmpty else {
            throw DecompilerError.engineFailure(
                "Ghidra produced no decompilation output for \(request.functionAddress.hexString)")
        }
        let text = String(decoding: data, as: UTF8.self)
        var record: [String: Any]?
        var lastError: String?
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }
            if let error = object["error"] as? String {
                lastError = error
                continue
            }
            record = object
        }
        guard let rec = record else {
            throw DecompilerError.engineFailure(
                "Ghidra: \(lastError ?? "no result for function at \(request.functionAddress.hexString)")")
        }
        let name = (rec["name"] as? String)
            ?? request.functionName
            ?? "sub_\(request.functionAddress.hexString)"
        let code = (rec["cCode"] as? String) ?? ""
        let warnings = (rec["warnings"] as? [Any])?.compactMap { $0 as? String } ?? []
        let parameters = (rec["parameters"] as? [Any])?.compactMap { $0 as? String } ?? []
        let localVariables = (rec["localVariables"] as? [Any])?.compactMap { $0 as? String } ?? []
        return DecompilationResult(
            functionAddress: request.functionAddress,
            functionName: name,
            pseudocode: code,
            signature: rec["signature"] as? String,
            parameters: parameters,
            returnType: (rec["returnType"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            localVariables: localVariables,
            warnings: warnings,
            engineID: id,
            engineVersion: version,
            rawBackendOutput: text.count > 1_048_576 ? nil : text)
    }

    // MARK: - Script location

    private func scriptURL() throws -> URL {
        var candidates: [URL] = []
        if let moduleResources = Bundle.module.resourceURL {
            candidates.append(moduleResources.appendingPathComponent(
                "EngineScripts/DecompileDump.py"))
            candidates.append(moduleResources.appendingPathComponent(
                "Resources/EngineScripts/DecompileDump.py"))
        }
        if let mainResources = Bundle.main.resourceURL {
            candidates.append(mainResources.appendingPathComponent(
                "EngineScripts/DecompileDump.py"))
            candidates.append(mainResources.appendingPathComponent(
                "Resources/EngineScripts/DecompileDump.py"))
            candidates.append(mainResources.appendingPathComponent(
                "YcodeDecompiler/EngineScripts/DecompileDump.py"))
        }
        // Source-relative fallback for unbundled development trees:
        // …/Decompilation/Backends/<file> → …/YcodeDecompiler/Resources/…
        let sourceFile = URL(fileURLWithPath: #filePath)
        let decompilerRoot = sourceFile
            .deletingLastPathComponent() // Backends
            .deletingLastPathComponent() // Decompilation
            .deletingLastPathComponent() // YcodeDecompiler
        candidates.append(decompilerRoot.appendingPathComponent(
            "Resources/EngineScripts/DecompileDump.py"))

        for candidate in candidates
        where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw DecompilerError.engineUnavailable(
            "Ghidra bridge script DecompileDump.py not found in any bundle resource location")
    }

    // MARK: - Ghidra installation discovery

    /// Locate a Ghidra install root (the directory containing
    /// `support/analyzeHeadless`).
    static func locateGhidraHome() -> URL? {
        let fm = FileManager.default

        func isInstallRoot(_ url: URL) -> Bool {
            fm.fileExists(atPath: url.appendingPathComponent("support/analyzeHeadless").path)
        }

        /// Newest `ghidra*` child directory that is a valid install root.
        func newestGhidraChild(of dir: URL) -> URL? {
            guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return nil }
            for name in items.filter({ $0.lowercased().hasPrefix("ghidra") }).sorted(by: >) {
                let candidate = dir.appendingPathComponent(name, isDirectory: true)
                if isInstallRoot(candidate) { return candidate }
            }
            return nil
        }

        let env = ProcessInfo.processInfo.environment
        for key in ["SWIFTCODE_GHIDRA_HOME", "GHIDRA_INSTALL_DIR"] {
            guard let raw = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            let url = URL(fileURLWithPath: raw)
            if isInstallRoot(url) { return url }
            if let child = newestGhidraChild(of: url) { return child }
        }

        var bundleDirs: [URL] = []
        if let moduleResources = Bundle.module.resourceURL {
            bundleDirs.append(moduleResources.appendingPathComponent("Engines/ghidra", isDirectory: true))
        }
        if let mainResources = Bundle.main.resourceURL {
            bundleDirs.append(mainResources.appendingPathComponent("Engines/ghidra", isDirectory: true))
        }
        let sourceFile = URL(fileURLWithPath: #filePath)
        let decompilerRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        bundleDirs.append(decompilerRoot.appendingPathComponent("Resources/Engines/ghidra", isDirectory: true))
        for dir in bundleDirs where isInstallRoot(dir) { return dir }

        let home = fm.homeDirectoryForCurrentUser
        let roots = [
            home,
            URL(fileURLWithPath: "/opt", isDirectory: true),
            URL(fileURLWithPath: "/usr/local", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true),
        ]
        for root in roots {
            if let found = newestGhidraChild(of: root) { return found }
        }
        return nil
    }

    /// Read `application.version` from Ghidra's application.properties, if present.
    static func readVersion(home: URL) -> String? {
        for relative in ["Ghidra/application.properties", "application.properties"] {
            let url = home.appendingPathComponent(relative)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: .newlines) {
                guard line.hasPrefix("application.version") else { continue }
                if let value = line.split(separator: "=", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespaces),
                   !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    // MARK: - Cached engine state

    /// Thread-safe cache for install discovery, Java detection and version.
    private final class GhidraState: @unchecked Sendable {
        private let lock = NSLock()
        private var home: URL??
        private var javaOK: Bool?
        private(set) var version: String?

        func ghidraHome() -> URL? {
            lock.lock()
            if let cached = home { lock.unlock(); return cached }
            lock.unlock()

            let found = GhidraDecompiler.locateGhidraHome()
            let ver = found.flatMap { GhidraDecompiler.readVersion(home: $0) }
            lock.lock()
            home = .some(found)
            version = ver
            lock.unlock()
            return found
        }

        /// `java -version` via /usr/bin/env so PATH is honored.
        func checkJava() -> Bool {
            lock.lock()
            if let cached = javaOK { lock.unlock(); return cached }
            lock.unlock()

            let ok = (try? Subprocess.run("/usr/bin/env", ["java", "-version"],
                                          captureStderr: false))?.status == 0
            lock.lock()
            javaOK = ok
            lock.unlock()
            return ok
        }
    }
}
