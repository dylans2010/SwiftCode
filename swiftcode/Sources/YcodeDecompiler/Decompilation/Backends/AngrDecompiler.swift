import Foundation
import YcodeSubprocess

/// Decompilation backend that drives the `angr` Python framework through a
/// bundled bridge script (`Resources/EngineScripts/AngrDecompile.py`).
///
/// Unlike `GhidraDecompiler` (which needs a full Ghidra install), this
/// backend only requires a CPython interpreter with `angr` importable. The
/// interpreter is discovered at runtime:
///
///   1. `SWIFTCODE_ANGR_PYTHON` environment override (checked first)
///   2. `~/.swiftcode-engines/angr-venv/bin/python`
///   3. `python3`, `python3.12`, `python3.13`, `python3.14` on PATH plus the
///      usual Homebrew locations — each probed with
///      `python -c "import angr; print(angr.__version__)"`.
///
/// Workflow: `AngrDecompile.py <binary> <out.json> [--arch=NAME] <addrHex>…`
/// loads the binary once with angr/cle (`auto_load_libs=False`), builds a
/// single CFGFast model, then runs angr's `Decompiler` on every requested
/// function address, writing one JSON record per line in the same schema
/// `DecompileDump.py` uses. `decompileBatch` therefore pays the CFG cost
/// once for the whole batch instead of once per function.
///
/// The angr arch hint is passed via `--arch` so fat/universal Mach-O slices
/// resolve to the same architecture `BinaryImage` describes.
public struct AngrDecompiler: DecompilerProvider {
    public let id = "angr"
    public let displayName = "angr"
    public let isPrimary = false

    public var version: String? { Self.state.version }

    private static let state = AngrState()

    public init() {}

    // MARK: - Provider contract

    public func isAvailable() async -> Bool {
        await Task.detached(priority: .utility) {
            Self.state.resolve() != nil
        }.value
    }

    public func availabilityDetail() async -> String {
        await Task.detached(priority: .utility) { () -> String in
            if Self.state.resolve() != nil { return "" }
            return "angr not found. Install it with `pip install angr` (Python 3.10–3.13) " +
                "or set SWIFTCODE_ANGR_PYTHON to a Python with angr installed."
        }.value
    }

    public func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet {
        guard Self.state.resolve() != nil else { return [] }
        guard Self.angrArch(for: image.architecture) != nil else { return [] }
        return [.decompileFunction, .decompileBatch]
    }

    public var supportedFormats: Set<BinaryFormat> { [.machO, .elf, .pe] }

    public var supportedArchitectures: Set<BinaryArchitecture> {
        [.arm64, .arm64_32, .x86_64, .armv7, .armv7s, .armv6, .i386,
         .riscv64, .mips, .powerpc, .powerpc64]
    }

    public func decompile(_ request: DecompilationRequest,
                          progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> DecompilationResult {
        var results = try await runBatch([request], progress: progress)
        return results.removeFirst()
    }

    /// Batch decompilation through a single angr process: one project load
    /// and one CFGFast pass cover every requested function.
    public func decompileBatch(_ requests: [DecompilationRequest],
                               progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DecompilationResult] {
        guard !requests.isEmpty else { return [] }
        return try await runBatch(requests, progress: progress)
    }

    // MARK: - Internals

    private func runBatch(_ requests: [DecompilationRequest],
                          progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DecompilationResult] {
        guard let python = Self.state.resolve() else {
            throw DecompilerError.engineUnavailable(await availabilityDetail())
        }
        guard let first = requests.first else { return [] }
        guard FileManager.default.fileExists(atPath: first.imagePath) else {
            throw DecompilerError.invalidRequest("binary not found: \(first.imagePath)")
        }
        let script = try scriptURL()

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("angr-decompile-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outURL) }

        var args = [script.path, first.imagePath, outURL.path]
        if let arch = Self.angrArch(for: first.architecture) {
            args.append("--arch=\(arch)")
        }
        // "0xADDR" or "0xADDR:0xEND" — the end bound lets the bridge script
        // run a region-limited CFGFast per function when the whole-binary
        // CFG does not finish in time.
        args.append(contentsOf: requests.map { request in
            var arg = request.functionAddress.hexString
            if let end = request.options["endAddress"], !end.isEmpty {
                arg += ":" + end
            }
            return arg
        })

        progress?(AnalysisProgress(
            stage: .decompiling,
            message: "Decompiling \(requests.count) function(s) with angr"))

        let pythonURL = URL(fileURLWithPath: python)
        // CFGFast on multi-megabyte binaries can run for a very long time.
        // Bound the batch so the pipeline cannot hang forever; the bridge
        // script streams records as they are produced, so whatever completed
        // before the deadline is still returned.
        let timeout = Self.batchTimeout
        var timedOut = false
        let consumer = Task {
            for try await _ in StreamingSubprocess.lines(pythonURL, args) { }
        }
        let watchdog = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            consumer.cancel()
        }
        do {
            try await consumer.value
        } catch is CancellationError {
            timedOut = true
        } catch let error as StreamingSubprocess.ExitError {
            if error.wasInterrupted || timedOut {
                timedOut = true
            } else {
                let tail = error.stderrTail.trimmingCharacters(in: .whitespacesAndNewlines)
                let suffix = tail.isEmpty ? "" : ": \(String(tail.suffix(600)))"
                watchdog.cancel()
                throw DecompilerError.engineFailure(
                    "angr exited with status \(error.status)\(suffix)")
            }
        } catch {
            watchdog.cancel()
            throw error
        }
        watchdog.cancel()

        var results = try parseResults(outURL: outURL, requests: requests)
        if timedOut {
            let note = "angr batch timed out after \(Int(timeout))s; " +
                "only functions decompiled before the deadline have pseudocode."
            results = results.map { result in
                var r = result
                r.warnings.append(note)
                return r
            }
        }
        return results
    }

    /// Wall-clock limit for one angr batch. `SWIFTCODE_ANGR_TIMEOUT_SECONDS`
    /// overrides it; non-positive values disable the limit.
    static var batchTimeout: TimeInterval {
        if let raw = ProcessInfo.processInfo.environment["SWIFTCODE_ANGR_TIMEOUT_SECONDS"],
           let value = TimeInterval(raw), value > 0 {
            return value
        }
        return 20 * 60
    }

    // MARK: - Output parsing

    /// Records are keyed by entry-point address; requests may repeat an
    /// address, so each request consumes one matching record in order.
    private func parseResults(outURL: URL, requests: [DecompilationRequest]) throws -> [DecompilationResult] {
        guard let data = try? Data(contentsOf: outURL), !data.isEmpty else {
            throw DecompilerError.engineFailure(
                "angr produced no decompilation output")
        }
        let text = String(decoding: data, as: UTF8.self)
        var recordsByAddress: [UInt64: [[String: Any]]] = [:]
        var order: [UInt64] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }
            guard let addrText = object["address"] as? String,
                  let addr = Self.parseAddress(addrText) else { continue }
            if recordsByAddress[addr] == nil { order.append(addr) }
            recordsByAddress[addr, default: []].append(object)
        }

        var consumed: [UInt64: Int] = [:]
        var results: [DecompilationResult] = []
        results.reserveCapacity(requests.count)
        for request in requests {
            let key = request.functionAddress.value
            let bucket = recordsByAddress[key] ?? []
            let index = consumed[key] ?? 0
            consumed[key] = index + 1
            let rec = index < bucket.count ? bucket[index] : nil
            results.append(makeResult(rec, request: request))
        }
        return results
    }

    private func makeResult(_ rec: [String: Any]?,
                            request: DecompilationRequest) -> DecompilationResult {
        let fallbackName = request.functionName
            ?? "sub_\(request.functionAddress.hexString)"
        guard let rec else {
            return DecompilationResult(
                functionAddress: request.functionAddress,
                functionName: fallbackName,
                pseudocode: "",
                warnings: ["angr produced no record for this address."],
                engineID: id, engineVersion: version)
        }
        if let error = rec["error"] as? String {
            return DecompilationResult(
                functionAddress: request.functionAddress,
                functionName: (rec["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName,
                pseudocode: "",
                signature: rec["signature"] as? String,
                warnings: [error],
                engineID: id, engineVersion: version)
        }
        let code = (rec["cCode"] as? String) ?? ""
        let warnings = (rec["warnings"] as? [Any])?.compactMap { $0 as? String } ?? []
        let parameters = (rec["parameters"] as? [Any])?.compactMap { $0 as? String } ?? []
        let localVariables = (rec["localVariables"] as? [Any])?.compactMap { $0 as? String } ?? []
        let name = (rec["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
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
            engineVersion: version)
    }

    private static func parseAddress(_ text: String) -> UInt64? {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("0x") || t.hasPrefix("0X") { t = String(t.dropFirst(2)) }
        return UInt64(t, radix: 16)
    }

    // MARK: - angr architecture names (archinfo/cle)

    static func angrArch(for architecture: BinaryArchitecture) -> String? {
        switch architecture {
        case .arm64: return "AARCH64"
        case .arm64_32: return "AARCH64"
        case .x86_64: return "AMD64"
        case .armv7, .armv7s, .armv6: return "ARM"
        case .i386: return "X86"
        case .riscv64: return "RISCV64"
        case .mips: return "MIPS32"
        case .powerpc: return "PPC32"
        case .powerpc64: return "PPC64"
        case .unknown: return nil
        }
    }

    // MARK: - Script location

    private func scriptURL() throws -> URL {
        var candidates: [URL] = []
        if let moduleResources = Bundle.module.resourceURL {
            candidates.append(moduleResources.appendingPathComponent(
                "EngineScripts/AngrDecompile.py"))
            candidates.append(moduleResources.appendingPathComponent(
                "Resources/EngineScripts/AngrDecompile.py"))
        }
        if let mainResources = Bundle.main.resourceURL {
            candidates.append(mainResources.appendingPathComponent(
                "EngineScripts/AngrDecompile.py"))
            candidates.append(mainResources.appendingPathComponent(
                "Resources/EngineScripts/AngrDecompile.py"))
            candidates.append(mainResources.appendingPathComponent(
                "YcodeDecompiler/EngineScripts/AngrDecompile.py"))
            candidates.append(mainResources.appendingPathComponent("AngrDecompile.py"))
        }
        let sourceFile = URL(fileURLWithPath: #filePath)
        let decompilerRoot = sourceFile
            .deletingLastPathComponent() // Backends
            .deletingLastPathComponent() // Decompilation
            .deletingLastPathComponent() // YcodeDecompiler
        candidates.append(decompilerRoot.appendingPathComponent(
            "Resources/EngineScripts/AngrDecompile.py"))

        for candidate in candidates
        where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw DecompilerError.engineUnavailable(
            "angr bridge script AngrDecompile.py not found in any bundle resource location")
    }

    // MARK: - Python interpreter discovery

    /// Ordered candidates for a Python that can `import angr`.
    static func pythonCandidates() -> [String] {
        var candidates: [String] = []
        if let override = ProcessInfo.processInfo.environment["SWIFTCODE_ANGR_PYTHON"],
           !override.isEmpty {
            candidates.append(override)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(
            ".swiftcode-engines/angr-venv/bin/python").path)

        // PATH-style names resolved through `which`.
        for which in ["/usr/bin/which", "/bin/which"]
        where FileManager.default.isExecutableFile(atPath: which) {
            for name in ["python3", "python3.12", "python3.13", "python3.14"] {
                if let out = try? Subprocess.run(which, [name], captureStderr: false),
                   out.status == 0,
                   let first = out.stdoutText.split(separator: "\n")
                       .map({ $0.trimmingCharacters(in: .whitespaces) })
                       .first(where: { !$0.isEmpty }) {
                    candidates.append(first)
                }
            }
            break
        }
        // Well-known absolute locations.
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/python3.12", "/opt/homebrew/bin/python3.13",
            "/opt/homebrew/bin/python3.14", "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3", "/usr/bin/python3",
        ])
        return candidates
    }

    /// Probe `python -c "import angr; print(angr.__version__)"`.
    static func probe(_ path: String) -> (ok: Bool, version: String?) {
        guard FileManager.default.isExecutableFile(atPath: path) else { return (false, nil) }
        guard let out = try? Subprocess.run(
            path, ["-c", "import angr; print(angr.__version__)"],
            captureStderr: false),
              out.status == 0 else { return (false, nil) }
        let version = out.stdoutText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty })
        return (true, version)
    }

    /// Thread-safe cache for interpreter discovery.
    private final class AngrState: @unchecked Sendable {
        private let lock = NSLock()
        private var resolved: String??
        private(set) var version: String?

        /// Returns the python path that can import angr, or nil.
        func resolve() -> String? {
            lock.lock()
            if let cached = resolved { lock.unlock(); return cached }
            lock.unlock()

            var found: String?
            for candidate in AngrDecompiler.pythonCandidates() {
                let probe = AngrDecompiler.probe(candidate)
                if probe.ok {
                    found = candidate
                    version = probe.version
                    break
                }
            }
            lock.lock()
            resolved = .some(found)
            lock.unlock()
            return found
        }
    }
}
