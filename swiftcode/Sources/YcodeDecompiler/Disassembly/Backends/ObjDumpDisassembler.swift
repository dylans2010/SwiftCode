import Foundation
import YcodeSubprocess

/// Disassembly backend built on LLVM's `llvm-objdump`.
///
/// The tool is located via `xcrun -f llvm-objdump` (Apple toolchains), then
/// `which llvm-objdump` on PATH, then the `SWIFTCODE_LLVM_OBJDUMP`
/// environment override (checked first).
///
/// Rather than disassembling the container file directly (which fails or
/// picks the wrong slice for fat Mach-O / multi-arch inputs), each
/// executable section overlapping the requested range is extracted through
/// the image's `byteProvider` and disassembled as a raw binary:
///
///   llvm-objdump -D -b binary --triple=<arch-triple>
///       --adjust-vma=<sectionVMA> --start-address=<lo> --stop-address=<hi>
///
/// This works uniformly for Mach-O, ELF and PE payloads on every
/// architecture LLVM knows (AArch64, x86/x86_64, ARM, RISC-V, PowerPC, MIPS).
/// `-D` forces linear disassembly of the whole section; bytes LLVM cannot
/// decode surface as `.byte`/`(bad)` and are classified `.invalid`.
public struct ObjDumpDisassembler: DisassemblerProvider {
    public let id = "llvm-objdump"
    public let displayName = "LLVM objdump"

    public var version: String? { Self.cache.version }

    private static let cache = ToolCache()

    public init() {}

    // MARK: - Provider contract

    public func isAvailable() async -> Bool {
        await Task.detached(priority: .utility) { Self.cache.resolve() }.value
        return Self.cache.toolPath != nil
    }

    public func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet {
        // llvm-objdump performs linear disassembly only; there is no
        // decompiler capability to advertise. An empty set still resolves via
        // EngineRegistry.resolveDisassembler (which does not filter on caps).
        _ = image
        return []
    }

    public func disassemble(image: BinaryImage,
                            start: DecompilerAddress,
                            end: DecompilerAddress,
                            progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [Instruction] {
        await Task.detached(priority: .utility) { Self.cache.resolve() }.value
        guard let tool = Self.cache.toolPath else {
            throw DecompilerError.engineUnavailable(
                "llvm-objdump not found (checked xcrun, PATH, SWIFTCODE_LLVM_OBJDUMP)")
        }
        guard let triple = Self.triple(for: image.architecture) else {
            throw DecompilerError.unsupportedArchitecture(image.architecture)
        }
        guard start.kind == .virtual, end.kind == .virtual else {
            throw DecompilerError.invalidRequest(
                "ObjDumpDisassembler requires virtual addresses (got \(start.kind)/\(end.kind))")
        }
        let lo = min(start.value, end.value)
        let hi = max(start.value, end.value)
        guard hi > lo else { return [] }

        let sections = image.executableSections.filter {
            $0.address.value < hi && ($0.address.value + $0.size) > lo
        }
        guard !sections.isEmpty else {
            throw DecompilerError.unmappedAddress(
                String(format: "0x%llx-0x%llx", lo, hi))
        }

        let fileManager = FileManager.default
        let tmpDir = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftCodeDecompiler/objdump", isDirectory: true)
        try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        var instructions: [Instruction] = []
        let toolURL = URL(fileURLWithPath: tool)

        for (index, section) in sections.enumerated() {
            try Task.checkCancellation()
            progress?(AnalysisProgress(
                stage: .disassembling,
                fraction: Double(index) / Double(sections.count),
                message: "Disassembling \(section.name)",
                itemsProcessed: index,
                itemsTotal: sections.count))

            // Whole-section extraction keeps instruction alignment; llvm-objdump
            // still limits output via --start-address/--stop-address, and the
            // parser filters by address regardless.
            guard let fileStart = image.fileOffset(forVirtualAddress: section.address.value) else {
                continue
            }
            let sectionEndVA = section.address.value + section.size
            guard sectionEndVA > section.address.value,
                  let fileEnd = image.fileOffset(forVirtualAddress: sectionEndVA - 1) else {
                continue
            }
            let length = Int(fileEnd - fileStart + 1)
            guard length > 0, fileStart + UInt64(length) <= UInt64(image.byteCount) else { continue }
            let bytes: Data
            do {
                bytes = try image.bytes(fileOffset: fileStart, length: length)
            } catch {
                continue // unreadable tail padding; skip this section
            }
            guard !bytes.isEmpty else { continue }

            let tmpFile = tmpDir.appendingPathComponent("slice-\(UUID().uuidString).bin")
            try bytes.write(to: tmpFile)
            defer { try? fileManager.removeItem(at: tmpFile) }

            let args = [
                "-D", "-b", "binary",
                "--triple=\(triple)",
                "--adjust-vma=0x\(String(section.address.value, radix: 16))",
                "--start-address=0x\(String(max(lo, section.address.value), radix: 16))",
                "--stop-address=0x\(String(min(hi, sectionEndVA), radix: 16))",
                tmpFile.path,
            ]

            do {
                for try await line in StreamingSubprocess.lines(toolURL, args) {
                    guard let parsed = Self.parseLine(line) else { continue }
                    guard parsed.address >= lo, parsed.address < hi else { continue }
                    instructions.append(makeInstruction(parsed, image: image))
                    if parsed.address >= hi { break }
                }
            } catch let error as StreamingSubprocess.ExitError {
                // llvm-objdump exits non-zero on some malformed trailing bytes;
                // tolerate it when we already recovered instructions.
                if instructions.isEmpty {
                    let tail = error.stderrTail
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let suffix = tail.isEmpty ? "" : ": \(String(tail.suffix(400)))"
                    throw DecompilerError.engineFailure(
                        "llvm-objdump exited with status \(error.status)\(suffix)")
                }
            }
        }

        return instructions.sorted { $0.address.value < $1.address.value }
    }

    // MARK: - Parsing

    private struct ParsedLine {
        var address: UInt64
        var bytes: Data
        var mnemonic: String
        var operandText: String
    }

    /// Parse one `llvm-objdump -D -b binary` line:
    /// `  <hexaddr>:\t<hex bytes>\t<mnemonic>\t<operands>`
    private static func parseLine(_ raw: String) -> ParsedLine? {
        var line = raw
        if line.hasSuffix("\r") { line.removeLast() }
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let addrText = line[..<colon].trimmingCharacters(in: .whitespaces)
        guard !addrText.isEmpty, addrText.allSatisfy(\.isHexDigit),
              let address = UInt64(addrText, radix: 16) else { return nil }

        let fields = line[line.index(after: colon)...]
            .components(separatedBy: "\t")
        var index = 0
        while index < fields.count,
              fields[index].trimmingCharacters(in: .whitespaces).isEmpty {
            index += 1
        }
        guard index + 1 < fields.count else { return nil }

        // Field `index` holds the raw-byte hex column; `index + 1` the mnemonic;
        // the remainder (joined) the operand text.
        let hexDigits = fields[index].filter(\.isHexDigit)
        var bytes = Data()
        bytes.reserveCapacity(hexDigits.count / 2)
        var nibbles = hexDigits.makeIterator()
        while let hi = nibbles.next(), let lo = nibbles.next(),
              let h = hi.hexDigitValue, let l = lo.hexDigitValue {
            bytes.append(UInt8(h * 16 + l))
        }

        let mnemonic = fields[index + 1]
            .trimmingCharacters(in: .whitespaces)
        guard !mnemonic.isEmpty else { return nil }

        let operandText = fields[(index + 2)...]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return ParsedLine(address: address, bytes: bytes,
                          mnemonic: mnemonic, operandText: operandText)
    }

    private func makeInstruction(_ parsed: ParsedLine, image: BinaryImage) -> Instruction {
        let (classification, target) = Self.classify(
            mnemonic: parsed.mnemonic, operandText: parsed.operandText)
        var operands: [InstructionOperand] = parsed.operandText.isEmpty
            ? [] : [.other(parsed.operandText)]
        if let target { operands.append(.address(target)) }
        return Instruction(
            address: DecompilerAddress(virtual: parsed.address),
            rawBytes: parsed.bytes,
            size: parsed.bytes.count,
            mnemonic: parsed.mnemonic,
            operands: operands,
            operandText: parsed.operandText,
            classification: classification,
            branchTarget: target,
            source: AnalysisSource(
                provenance: .engine,
                engineID: id,
                engineVersion: version,
                pass: "disassemble"))
    }

    // MARK: - Classification

    private static let returnMnemonics: Set<String> = [
        "ret", "retq", "retl", "retf", "retn", "retab",
    ]

    private static let callMnemonics: Set<String> = [
        "call", "callq", "calll", "lcall",
        "bl", "blr", "blraa", "blrab", "blx", "blxns",
        "jal", "jalr", "bctrl", "bcctrl", "bla", "blrl",
        "bgezal", "bltzal",
    ]

    private static let branchMnemonics: Set<String> = [
        // ARM / AArch64
        "b", "br", "bra", "bx", "bxj", "brx",
        "cbz", "cbnz", "tbz", "tbnz",
        // x86 unconditional + Jcc
        "jmp", "jmpq", "je", "jne", "jz", "jnz",
        "ja", "jae", "jb", "jbe", "jg", "jge", "jl", "jle",
        "jo", "jno", "js", "jns", "jp", "jnp",
        "jc", "jnc", "jpe", "jpo",
        "jrcxz", "jecxz", "jcxz",
        "loop", "loope", "loopne", "loopnz",
        // MIPS
        "j", "jr", "beq", "bne", "blez", "bgtz", "bltz", "bgez",
        "beqz", "bnez", "bgezal", "bltzal",
        // PowerPC
        "bc", "bcctr", "bctr", "bdnz", "bdz", "beq", "bne",
        "blt", "bgt", "ble", "bge", "bso", "bns", "bun",
    ]

    private static func classify(mnemonic: String,
                                 operandText: String) -> (Instruction.Classification, DecompilerAddress?) {
        let lower = mnemonic.lowercased()

        let isReturn = returnMnemonics.contains(lower)
            || lower.hasPrefix("ret")      // retq/retaa/retab variants
            || lower.hasPrefix("iret")
            || lower.hasPrefix("eret")
        let isCall = callMnemonics.contains(lower) || lower.hasPrefix("call")
        let isBranch = branchMnemonics.contains(lower)
            || lower.hasPrefix("b.")        // ARM condition codes: b.eq, b.ne, ...
            || lower.hasPrefix("c.b")       // AArch64 compressed branches

        // Note: there is deliberately no generic "bl" prefix rule — "blt",
        // "ble", "bgez" etc. are branches, and the exact call set above
        // already enumerates every branch-and-link mnemonic.

        let classification: Instruction.Classification
        if isReturn {
            classification = .returnInstruction
        } else if isCall {
            classification = .call
        } else if isBranch {
            classification = .branch
        } else if lower == "(bad)" || lower.hasPrefix(".byte")
                    || lower.hasPrefix(".word") || lower.hasPrefix(".short")
                    || lower.hasPrefix(".hword") || lower.hasPrefix(".inst") {
            classification = .invalid
        } else {
            classification = .normal
        }

        guard classification == .branch || classification == .call else {
            return (classification, nil)
        }
        return (classification, branchTarget(in: operandText))
    }

    /// Extract the first absolute address operand from disassembly text.
    /// Comments (`# ...`) and symbolic annotations (`<name>`) are ignored.
    private static func branchTarget(in operandText: String) -> DecompilerAddress? {
        for rawToken in operandText.split(whereSeparator: {
            $0 == " " || $0 == "\t" || $0 == "," || $0 == ";"
        }) {
            var token = String(rawToken)
            if let lt = token.firstIndex(of: "<") {
                token = String(token[..<lt])
            }
            token = token.trimmingCharacters(in: CharacterSet(charactersIn: "#$"))
            if token.hasSuffix(")") { token.removeLast() }
            guard !token.isEmpty, !token.hasPrefix("-"), !token.hasPrefix("[") else { continue }

            var value: UInt64? = nil
            if token.hasPrefix("0x") || token.hasPrefix("0X") {
                value = UInt64(token.dropFirst(2), radix: 16)
            } else if token.count >= 4,
                      token.allSatisfy(\.isHexDigit),
                      token.contains(where: { $0.isHexDigit && !$0.isNumber }) {
                // Bare hex (no 0x prefix) that contains a-f letters — avoids
                // mistaking decimal immediates for addresses.
                value = UInt64(token, radix: 16)
            }
            if let value, value != 0 {
                return DecompilerAddress(virtual: value)
            }
        }
        return nil
    }

    // MARK: - Tool location

    /// LLVM target triple per architecture, or nil when unsupported.
    static func triple(for architecture: BinaryArchitecture) -> String? {
        switch architecture {
        case .arm64: return "aarch64-linux-gnu"
        case .arm64_32: return "aarch64_32-linux-gnu"
        case .x86_64: return "x86_64-linux-gnu"
        case .armv7, .armv7s: return "armv7-linux-gnueabihf"
        case .armv6: return "armv6-linux-gnueabihf"
        case .i386: return "i386-linux-gnu"
        case .riscv64: return "riscv64-linux-gnu"
        case .powerpc: return "powerpc-linux-gnu"
        case .powerpc64: return "powerpc64-linux-gnu"
        case .mips: return "mips-linux-gnu"
        case .unknown: return nil
        }
    }

    /// Ordered candidates for the llvm-objdump executable path.
    static func locateToolPath() -> String? {
        var candidates: [String] = []

        // Explicit override first.
        if let override = ProcessInfo.processInfo.environment["SWIFTCODE_LLVM_OBJDUMP"],
           !override.isEmpty {
            candidates.append(override)
        }

        // Apple toolchain lookup.
        for xcrun in ["/usr/bin/xcrun", "/bin/xcrun"]
        where FileManager.default.isExecutableFile(atPath: xcrun) {
            if let out = try? Subprocess.run(xcrun, ["-f", "llvm-objdump"],
                                             captureStderr: false),
               out.status == 0 {
                let path = out.stdoutText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty { candidates.append(path) }
            }
        }

        // PATH lookup via `which`.
        for which in ["/usr/bin/which", "/bin/which"]
        where FileManager.default.isExecutableFile(atPath: which) {
            if let out = try? Subprocess.run(which, ["llvm-objdump"],
                                             captureStderr: false),
               out.status == 0 {
                if let first = out.stdoutText
                    .split(separator: "\n")
                    .map({ $0.trimmingCharacters(in: .whitespaces) })
                    .first(where: { !$0.isEmpty }) {
                    candidates.append(first)
                }
            }
            break
        }

        let fm = FileManager.default
        for candidate in candidates {
            if fm.isExecutableFile(atPath: candidate) { return candidate }
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

            let path = ObjDumpDisassembler.locateToolPath()
            var ver: String? = nil
            if let path,
               let out = try? Subprocess.run(path, ["--version"], captureStderr: false),
               out.status == 0 {
                ver = Self.parseVersion(out.stdoutText)
            }

            lock.lock()
            toolPath = path
            version = ver
            didResolve = true
            lock.unlock()
        }

        private static func parseVersion(_ text: String) -> String? {
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if let versionLine = lines.first(where: { $0.localizedCaseInsensitiveContains("version") }) {
                return versionLine
            }
            return lines.first
        }
    }
}
