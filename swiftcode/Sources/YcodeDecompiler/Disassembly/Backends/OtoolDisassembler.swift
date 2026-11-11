import Foundation
import YcodeSubprocess

/// Disassembly backend built on Apple's `otool` (`-xjV`).
///
/// `otool` ships with the Xcode Command Line Tools and understands Mach-O
/// natively — including fat/universal containers (`-arch` selects the slice)
/// — so it is the preferred disassembler for Mach-O images on macOS. It is
/// located via `xcrun -f otool`, then `/usr/bin/otool`, `/bin/otool`, then
/// the `SWIFTCODE_OTOOL` environment override (checked first).
///
/// Invocation:
///
///   otool -arch <arch> -xjV <file>
///
/// `-x` disassembles every text section, `-j` prints the raw instruction
/// word/bytes, `-V` resolves operands symbolically (stub names, literal-pool
/// and cfstring annotations appear as `; …` comments). Output lines look
/// like:
///
///   0000000000004000\td10503ff\tsub\tsp, sp, #0x140
///   0000000000004034\t941907ea\tbl\t0x645fdc ; symbol stub for: _objc_retain
///
/// The hex word column is the instruction encoding; for AArch64 it is the
/// 32-bit instruction word (stored little-endian in the file), for other
/// targets `-j` prints the bytes in memory order. `rawBytes` is reconstructed
/// accordingly.
///
/// The full listing is produced once per (file, arch) and cached; each
/// `disassemble` call filters the cached lines to the requested virtual
/// range, so repeated per-section/per-function calls do not re-run otool.
public struct OtoolDisassembler: DisassemblerProvider {
    public let id = "otool"
    public let displayName = "otool (Apple)"

    public var version: String? { Self.cache.version }

    private static let cache = ToolCache()

    public init() {}

    // MARK: - Provider contract

    public func isAvailable() async -> Bool {
        await Task.detached(priority: .utility) { Self.cache.resolve() }.value
        return Self.cache.toolPath != nil
    }

    public func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet {
        guard image.format == .machO else { return [] }
        guard Self.otoolArch(for: image) != nil else { return [] }
        return [.disassemble]
    }

    public var supportedFormats: Set<BinaryFormat> { [.machO] }

    public var supportedArchitectures: Set<BinaryArchitecture> {
        [.arm64, .arm64_32, .x86_64, .armv7, .armv7s, .armv6, .i386]
    }

    public func disassemble(image: BinaryImage,
                            start: DecompilerAddress,
                            end: DecompilerAddress,
                            progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [Instruction] {
        await Task.detached(priority: .utility) { Self.cache.resolve() }.value
        guard let tool = Self.cache.toolPath else {
            throw DecompilerError.engineUnavailable(
                "otool not found (checked xcrun, /usr/bin, /bin, SWIFTCODE_OTOOL)")
        }
        guard image.format == .machO else {
            throw DecompilerError.unsupportedFormat("otool only supports Mach-O (got \(image.format.rawValue))")
        }
        guard start.kind == .virtual, end.kind == .virtual else {
            throw DecompilerError.invalidRequest(
                "OtoolDisassembler requires virtual addresses (got \(start.kind)/\(end.kind))")
        }
        let lo = min(start.value, end.value)
        let hi = max(start.value, end.value)
        guard hi > lo else { return [] }
        let filePath = image.identity.originalLocation
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DecompilerError.invalidRequest("binary not found: \(filePath)")
        }
        guard Self.otoolArch(for: image) != nil else {
            throw DecompilerError.unsupportedArchitecture(image.architecture)
        }

        let lines = try await Self.listing(tool: tool, image: image, filePath: filePath)
        progress?(AnalysisProgress(stage: .disassembling,
                                   message: "Disassembling \(image.identity.originalFileName) (otool)"))

        var instructions: [Instruction] = []
        for line in lines {
            guard line.address >= lo, line.address < hi else { continue }
            instructions.append(makeInstruction(line, image: image))
        }
        return instructions.sorted { $0.address.value < $1.address.value }
    }

    // MARK: - Listing acquisition & cache

    struct ListingLine: Sendable {
        var address: UInt64
        var rawBytes: Data
        var mnemonic: String
        var operandText: String
        var comment: String?
    }

    /// Run `otool -xjV` once per (file, arch) and cache the parsed lines.
    /// Bounded to a few entries; entries are dropped oldest-first.
    private static func listing(tool: String, image: BinaryImage,
                                filePath: String) async throws -> [ListingLine] {
        let archName = otoolArch(for: image)
        let key = "\(filePath)|\(archName ?? "default")"
        if let cached = ListingCache.shared.get(key) { return cached }

        var args = ["-xjV"]
        if let archName { args += ["-arch", archName] }
        args.append(filePath)

        let toolURL = URL(fileURLWithPath: tool)
        var lines: [ListingLine] = []
        var sawInstruction = false
        do {
            for try await raw in StreamingSubprocess.lines(toolURL, args) {
                guard let parsed = parseLine(raw, image: image) else { continue }
                sawInstruction = true
                lines.append(parsed)
            }
        } catch let error as StreamingSubprocess.ExitError {
            // `-arch` can fail on unusual slices; retry once without it when
            // the file is thin (otool ignores arch selection for thin files
            // only if the slice matches, so the retry covers subtype drift
            // such as arm64 vs arm64e).
            if archName != nil {
                let retried = try await runAndParse(tool: toolURL, args: ["-xjV", filePath],
                                                    image: image)
                ListingCache.shared.put(key: key, value: retried)
                return retried
            }
            let tail = error.stderrTail.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = tail.isEmpty ? "" : ": \(String(tail.suffix(400)))"
            throw DecompilerError.engineFailure("otool exited with status \(error.status)\(suffix)")
        } catch is CancellationError {
            throw DecompilerError.engineCancelled("otool")
        }
        guard sawInstruction || !lines.isEmpty else {
            throw DecompilerError.engineFailure("otool produced no disassembly for \(filePath)")
        }
        ListingCache.shared.put(key: key, value: lines)
        return lines
    }

    private static func runAndParse(tool: URL, args: [String],
                                    image: BinaryImage) async throws -> [ListingLine] {
        var lines: [ListingLine] = []
        do {
            for try await raw in StreamingSubprocess.lines(tool, args) {
                if let parsed = parseLine(raw, image: image) { lines.append(parsed) }
            }
        } catch let error as StreamingSubprocess.ExitError {
            let tail = error.stderrTail.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = tail.isEmpty ? "" : ": \(String(tail.suffix(400)))"
            throw DecompilerError.engineFailure("otool exited with status \(error.status)\(suffix)")
        }
        return lines
    }

    // MARK: - Line parsing

    /// Parse `ADDR\tHEX\tMNEMONIC\tOPERANDS` produced by `otool -jV`.
    /// Returns nil for headers, section banners and blank lines.
    static func parseLine(_ raw: String, image: BinaryImage) -> ListingLine? {
        var line = raw
        if line.hasSuffix("\r") { line.removeLast() }
        let fields = line.components(separatedBy: "\t")
        guard fields.count >= 3 else { return nil }
        let addrText = fields[0].trimmingCharacters(in: .whitespaces)
        guard addrText.count >= 8, addrText.allSatisfy(\.isHexDigit),
              let address = UInt64(addrText, radix: 16) else { return nil }
        let hexDigits = fields[1].filter(\.isHexDigit)
        guard !hexDigits.isEmpty else { return nil }
        let mnemonic = fields[2].trimmingCharacters(in: .whitespaces)
        guard !mnemonic.isEmpty, mnemonic != "section" else { return nil }

        let operandRaw = fields.count > 3 ? fields[3...].joined(separator: " ") : ""
        var operandText = operandRaw.trimmingCharacters(in: .whitespaces)
        var comment: String?
        if let semi = operandText.firstIndex(of: ";") {
            comment = String(operandText[operandText.index(after: semi)...])
                .trimmingCharacters(in: .whitespaces)
            operandText = String(operandText[..<semi])
                .trimmingCharacters(in: .whitespaces)
        }

        let rawBytes = decodeBytes(hexDigits: hexDigits, image: image)
        guard !rawBytes.isEmpty else { return nil }
        return ListingLine(address: address, rawBytes: rawBytes,
                           mnemonic: mnemonic, operandText: operandText,
                           comment: comment)
    }

    /// `-j` output is the instruction encoding. AArch64 prints the 32-bit
    /// instruction word (big-endian hex of the value, stored LE in the
    /// file); other targets print bytes in memory order.
    private static func decodeBytes(hexDigits: String, image: BinaryImage) -> Data {
        switch image.architecture {
        case .arm64, .arm64_32:
            guard hexDigits.count == 8, let word = UInt32(hexDigits, radix: 16) else {
                // Unexpected width: fall back to raw byte pairs.
                return bytePairs(hexDigits)
            }
            var bytes = Data()
            bytes.reserveCapacity(4)
            for shift in stride(from: 0, through: 24, by: 8) {
                bytes.append(UInt8((word >> UInt32(shift)) & 0xff))
            }
            return bytes
        default:
            return bytePairs(hexDigits)
        }
    }

    private static func bytePairs(_ hexDigits: String) -> Data {
        var bytes = Data()
        bytes.reserveCapacity(hexDigits.count / 2)
        var nibbles = hexDigits.makeIterator()
        while let hi = nibbles.next(), let lo = nibbles.next(),
              let h = hi.hexDigitValue, let l = lo.hexDigitValue {
            bytes.append(UInt8(h * 16 + l))
        }
        return bytes
    }

    // MARK: - Instruction construction

    private func makeInstruction(_ line: ListingLine, image: BinaryImage) -> Instruction {
        let (classification, target) = ObjDumpDisassembler.classify(
            mnemonic: line.mnemonic, operandText: line.operandText)
        var operands: [InstructionOperand] = line.operandText.isEmpty
            ? [] : [.other(line.operandText)]
        if let target { operands.append(.address(target)) }
        var comment = line.comment
        if comment == nil, let semi = line.operandText.firstIndex(of: ";") {
            comment = String(line.operandText[line.operandText.index(after: semi)...])
                .trimmingCharacters(in: .whitespaces)
        }
        return Instruction(
            address: DecompilerAddress(virtual: line.address),
            rawBytes: line.rawBytes,
            size: line.rawBytes.count,
            mnemonic: line.mnemonic,
            operands: operands,
            operandText: line.operandText,
            comment: comment,
            classification: classification,
            branchTarget: target,
            source: AnalysisSource(
                provenance: .engine,
                engineID: id,
                engineVersion: version,
                pass: "disassemble"))
    }

    // MARK: - Architecture mapping

    /// otool `-arch` name for the image's architecture, or nil when otool
    /// cannot disassemble it. arm64e slices still select via "arm64" on
    /// current toolchains; the no-`-arch` retry covers the rest.
    static func otoolArch(for image: BinaryImage) -> String? {
        switch image.architecture {
        case .arm64: return "arm64"
        case .arm64_32: return "arm64_32"
        case .x86_64: return "x86_64"
        case .armv7: return "armv7"
        case .armv7s: return "armv7s"
        case .armv6: return "armv6"
        case .i386: return "i386"
        case .riscv64, .powerpc, .powerpc64, .mips, .unknown: return nil
        }
    }

    // MARK: - Tool location

    static func locateToolPath() -> String? {
        var candidates: [String] = []
        if let override = ProcessInfo.processInfo.environment["SWIFTCODE_OTOOL"],
           !override.isEmpty {
            candidates.append(override)
        }
        for xcrun in ["/usr/bin/xcrun", "/bin/xcrun"]
        where FileManager.default.isExecutableFile(atPath: xcrun) {
            if let out = try? Subprocess.run(xcrun, ["-f", "otool"],
                                             captureStderr: false),
               out.status == 0 {
                let path = out.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty { candidates.append(path) }
            }
        }
        candidates.append(contentsOf: ["/usr/bin/otool", "/bin/otool"])
        for which in ["/usr/bin/which", "/bin/which"]
        where FileManager.default.isExecutableFile(atPath: which) {
            if let out = try? Subprocess.run(which, ["otool"], captureStderr: false),
               out.status == 0,
               let first = out.stdoutText.split(separator: "\n")
                   .map({ $0.trimmingCharacters(in: .whitespaces) })
                   .first(where: { !$0.isEmpty }) {
                candidates.append(first)
            }
            break
        }
        let fm = FileManager.default
        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    /// Lazily resolved, thread-safe cache for tool path and version.
    private final class ToolCache: @unchecked Sendable {
        private let lock = NSLock()
        private var didResolve = false
        private(set) var toolPath: String?
        private(set) var version: String?

        func resolve() {
            lock.lock()
            if didResolve { lock.unlock(); return }
            lock.unlock()

            let path = OtoolDisassembler.locateToolPath()
            var ver: String? = nil
            if let path,
               let out = try? Subprocess.run(path, ["--version"], captureStderr: true),
               out.status == 0 {
                // otool prints its version banner on stderr.
                let text = out.stdoutText.isEmpty ? out.stderrText : out.stdoutText
                ver = OtoolDisassembler.parseVersion(text)
            }
            lock.lock()
            toolPath = path
            version = ver
            didResolve = true
            lock.unlock()
        }
    }

    static func parseVersion(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let versionLine = lines.first(where: { $0.localizedCaseInsensitiveContains("version") }) {
            return versionLine
        }
        return lines.first
    }

    /// Small LRU-ish cache of parsed otool listings keyed by file+arch.
    private final class ListingCache: @unchecked Sendable {
        static let shared = ListingCache()
        private let lock = NSLock()
        private var entries: [String: [ListingLine]] = [:]
        private var order: [String] = []
        private let capacity = 3

        func get(_ key: String) -> [ListingLine]? {
            lock.lock()
            defer { lock.unlock() }
            return entries[key]
        }

        func put(key: String, value: [ListingLine]) {
            lock.lock()
            defer { lock.unlock() }
            if entries[key] == nil { order.append(key) }
            entries[key] = value
            while order.count > capacity {
                let oldest = order.removeFirst()
                entries.removeValue(forKey: oldest)
            }
        }
    }
}
