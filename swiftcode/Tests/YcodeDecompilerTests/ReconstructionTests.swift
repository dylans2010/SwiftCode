import XCTest
@testable import YcodeDecompiler
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class ReconstructionTests: XCTestCase {

    // MARK: - Utilities

    func testSanitizedCIdentifier() {
        XCTAssertEqual(ReconstructionUtilities.sanitizedCIdentifier("hello-world"), "hello_world")
        XCTAssertEqual(ReconstructionUtilities.sanitizedCIdentifier("int"), "int_")
        XCTAssertEqual(ReconstructionUtilities.sanitizedCIdentifier("9lives"), "_9lives")
        XCTAssertEqual(ReconstructionUtilities.sanitizedCIdentifier(""), "unnamed")
        XCTAssertEqual(ReconstructionUtilities.sanitizedCIdentifier("a.b/c"), "a_b_c")
    }

    func testCFunctionNameStripsSingleMachOPrefix() {
        XCTAssertEqual(ReconstructionUtilities.cFunctionName(for: "_sc_add"), "sc_add")
        XCTAssertEqual(ReconstructionUtilities.cFunctionName(for: "__objc_class"), "__objc_class")
        XCTAssertEqual(ReconstructionUtilities.cFunctionName(for: "plain"), "plain")
    }

    func testAsmSymbolName() {
        XCTAssertEqual(ReconstructionUtilities.asmSymbolName("foo", format: .machO), "_foo")
        XCTAssertEqual(ReconstructionUtilities.asmSymbolName("foo", format: .elf), "foo")
    }

    func testEscapeCString() {
        XCTAssertEqual(ReconstructionUtilities.escapeCString("a\"b\\c\nd"), "a\\\"b\\\\c\\nd")
    }

    func testByteLines() {
        let lines = ReconstructionUtilities.byteLines(Data([0x01, 0x02, 0xff]))
        XCTAssertEqual(lines, ["    .byte 0x01, 0x02, 0xff"])
    }

    func testParseHex() {
        XCTAssertEqual(ReconstructionUtilities.parseHex("0x1f"), 31)
        XCTAssertEqual(ReconstructionUtilities.parseHex("ff"), 255)
        XCTAssertNil(ReconstructionUtilities.parseHex("zz"))
        XCTAssertNil(ReconstructionUtilities.parseHex(""))
        XCTAssertEqual(ReconstructionUtilities.parseSignedHex("-0x2"), -2)
        XCTAssertEqual(ReconstructionUtilities.parseSignedHex("0xffffffffffffffff"), -1)
    }

    func testGhidraTypeToC() {
        XCTAssertEqual(ReconstructionUtilities.ghidraTypeToC("undefined8"), "uint64_t")
        XCTAssertEqual(ReconstructionUtilities.ghidraTypeToC("undefined1"), "uint8_t")
        XCTAssertEqual(ReconstructionUtilities.ghidraTypeToC("undefined"), "uint8_t")
        XCTAssertEqual(ReconstructionUtilities.ghidraTypeToC("char *"), "char *")
        XCTAssertEqual(ReconstructionUtilities.ghidraTypeToC("undefined4 *"), "uint32_t *")
        XCTAssertEqual(ReconstructionUtilities.ghidraTypeToC("int"), "int")
    }

    func testMapGhidraSignature() {
        let mapped = ReconstructionUtilities.mapGhidraSignature(
            "undefined8 FUN_00101119(int param_1, char * param_2)", functionName: "FUN_00101119")
        XCTAssertEqual(mapped?.returnType, "uint64_t")
        XCTAssertEqual(mapped?.parameters, ["int param_1", "char * param_2"])
        XCTAssertNil(ReconstructionUtilities.mapGhidraSignature("no parens here", functionName: "x"))
        let voidParams = ReconstructionUtilities.mapGhidraSignature(
            "void myfunc(void)", functionName: "myfunc")
        XCTAssertEqual(voidParams?.returnType, "void")
        XCTAssertEqual(voidParams?.parameters, [])
    }

    func testLanguageIdentification() {
        XCTAssertEqual(LanguageIdentification.identifySymbol("$s4main5hello"), .swift)
        XCTAssertEqual(LanguageIdentification.identifySymbol("OBJC_CLASS_$_Foo"), .objectiveC)
        XCTAssertEqual(LanguageIdentification.identifySymbol("_Z3foov"), .cpp)
        XCTAssertEqual(LanguageIdentification.identifySymbol("_RINvC3foo3bar"), .rust)
        XCTAssertEqual(LanguageIdentification.identifySymbol("plain_c_function"), .unknown)
    }

    // MARK: - Diagnostics

    func testParseCompilerOutput() throws {
        let root = URL(fileURLWithPath: "/proj")
        let diags = AssemblyDiagnosticParser.parseCompilerOutput(
            "/proj/Sources/reconstructed/foo.c:12:5: error: use of undeclared identifier 'bar'\n" +
            "/proj/Assembly/fallback.S:3:1: warning: something odd\n" +
            "ld: warning: some linker note\n",
            projectRoot: root)
        XCTAssertEqual(diags.count, 3)
        let first = diags[0]
        XCTAssertEqual(first.severity, .error)
        XCTAssertEqual(first.file, "Sources/reconstructed/foo.c")
        XCTAssertEqual(first.line, 12)
        XCTAssertEqual(first.column, 5)
        XCTAssertEqual(first.origin, .recoveredCode)
        XCTAssertTrue(first.message.contains("undeclared identifier"))
        XCTAssertNotNil(first.suggestion)
        XCTAssertEqual(diags[1].origin, .userCode)
    }

    func testParseLinkerOutput() {
        let diags = AssemblyDiagnosticParser.parseLinkerOutput(
            "/usr/bin/ld: /tmp/x.o: in function `main':\n/tmp/x.o: undefined reference to 'missing_fn'\n")
        XCTAssertTrue(diags.contains { $0.symbol == "missing_fn" && $0.severity == .error })
    }

    // MARK: - Equivalence

    private func makeImage(exports: [String], format: BinaryFormat = .elf,
                           architecture: BinaryArchitecture = .x86_64,
                           installName: String? = nil) -> BinaryImage {
        let identity = BinaryIdentity(sha256: "aa", originalFileName: "libfixture.so",
                                      originalLocation: "/tmp/libfixture.so", fileSize: 100,
                                      format: format, architecture: architecture)
        var image = BinaryImage(identity: identity, format: format, architecture: architecture,
                                cpuIdentifier: "x86_64", fileType: "dylib", entryPoint: nil,
                                segments: [], imports: [], exports: exports.map {
                                    BinaryExport(name: $0, address: DecompilerAddress(virtual: 0x1000),
                                                 kind: .function)
                                },
                                dependencies: [], symbols: [], strings: [], functionStarts: [],
                                isEncrypted: false, isSigned: false, entitlements: nil,
                                codeSignatureInfo: nil, buildVersion: nil, minOSVersion: nil,
                                hasDebugInfo: false, byteCount: 0,
                                byteProvider: { _, _ in Data() })
        image.installName = installName
        return image
    }

    func testEquivalenceIdentical() {
        let a = makeImage(exports: ["foo", "bar"])
        let b = makeImage(exports: ["foo", "bar"])
        let report = EquivalenceChecker.compare(original: a, rebuilt: b,
                                                buildSucceeded: true, formatValid: true)
        XCTAssertEqual(report.verdict, .compatible)
        XCTAssertTrue(report.isABICompatible)
        XCTAssertTrue(report.missingExports.isEmpty)
        XCTAssertFalse(report.behavioralEquivalence.contains("proven"))
    }

    func testEquivalenceMissingExport() {
        let a = makeImage(exports: ["foo", "bar"])
        let b = makeImage(exports: ["foo"])
        let report = EquivalenceChecker.compare(original: a, rebuilt: b,
                                                buildSucceeded: true, formatValid: true)
        XCTAssertFalse(report.isABICompatible)
        XCTAssertEqual(report.missingExports.map(\.name), ["bar"])
        XCTAssertEqual(report.verdict, .incompatible)
    }

    func testEquivalenceNeverClaimsBehavior() {
        let a = makeImage(exports: ["foo"])
        let b = makeImage(exports: ["foo"])
        let report = EquivalenceChecker.compare(original: a, rebuilt: b,
                                                buildSucceeded: true, formatValid: true)
        XCTAssertTrue(report.behavioralEquivalence.lowercased().contains("not"))
    }

    // MARK: - Build configuration

    func testBuildConfigurationInference() {
        let macho = makeImage(exports: [], format: .machO, architecture: .arm64)
        let macConfig = BuildConfiguration.inferred(from: macho, libraryName: "thing")
        XCTAssertEqual(macConfig.outputFileName, "libthing.dylib")
        XCTAssertEqual(macConfig.installName, "@rpath/libthing.dylib")
        XCTAssertTrue(macConfig.unrecoveredSettings.contains { $0.contains("installName") })
        let macCompileArgs = macConfig.compileArguments(
            source: URL(fileURLWithPath: "/x/a.c"), object: URL(fileURLWithPath: "/x/a.o"),
            projectRoot: URL(fileURLWithPath: "/x"), format: .machO)
        XCTAssertTrue(macCompileArgs.contains("-arch"))
        XCTAssertTrue(macCompileArgs.contains("arm64"))
        XCTAssertFalse(macCompileArgs.contains("-dynamiclib"))
        let macLinkArgs = macConfig.linkArguments(
            objects: [URL(fileURLWithPath: "/x/a.o")],
            output: URL(fileURLWithPath: "/x/libthing.dylib"), format: .machO)
        XCTAssertTrue(macLinkArgs.contains("-dynamiclib"))
        XCTAssertTrue(macLinkArgs.contains("-install_name"))
        XCTAssertTrue(macLinkArgs.contains("@rpath/libthing.dylib"))

        let elf = makeImage(exports: [], format: .elf, architecture: .x86_64)
        let elfConfig = BuildConfiguration.inferred(from: elf, libraryName: "thing")
        XCTAssertEqual(elfConfig.outputFileName, "libthing.so")
        let linkArgs = elfConfig.linkArguments(objects: [URL(fileURLWithPath: "/x/a.o")],
                                               output: URL(fileURLWithPath: "/x/libthing.so"),
                                               format: .elf)
        XCTAssertTrue(linkArgs.contains("-shared"))
        XCTAssertTrue(linkArgs.contains("-fPIC") || linkArgs.contains("-shared"))
    }

    // MARK: - Source mapping

    func testSourceMappingLookup() throws {
        let mapping = SourceMapping(
            entries: [
                SourceMapping.Entry(address: 0x1000, file: "Sources/a.c", line: 3,
                                    function: "foo", quality: .reconstructed),
                SourceMapping.Entry(address: 0x1040, file: "Sources/a.c", line: 9,
                                    function: "bar", quality: .partial),
            ],
            originalSHA256: "aa", originalFileName: "libx.so")
        XCTAssertEqual(mapping.entry(forAddress: 0x1000)?.function, "foo")
        XCTAssertNil(mapping.entry(forAddress: 0x1004))
        XCTAssertEqual(mapping.entry(containing: 0x1044)?.function, "bar")
        XCTAssertEqual(mapping.entry(containing: 0x1004)?.function, "foo")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SourceMapping.self, from: mapping.jsonData())
        XCTAssertEqual(decoded.entries.count, 2)
    }

    // MARK: - Reconstruction from fabricated pseudocode

    func testReconstructWithPseudocode() {
        let image = makeImage(exports: ["sc_add"], format: .elf, architecture: .x86_64)
        let fn = DecompilerFunction(address: DecompilerAddress(virtual: 0x1000),
                                    endAddress: DecompilerAddress(virtual: 0x1020),
                                    size: 0x20, name: "sc_add", kind: .exportedSymbol,
                                    source: AnalysisSource(provenance: .symbolTable))
        let result = DecompilationResult(
            functionAddress: DecompilerAddress(virtual: 0x1000), functionName: "FUN_00101000",
            pseudocode: """
                int FUN_00101000(int param_1, int param_2)
                {
                  return param_1 + param_2;
                }
                """,
            signature: "int FUN_00101000(int param_1, int param_2)",
            engineID: "ghidra")
        let source = SourceReconstructor.reconstruct(
            image: image, functions: [fn], pseudocode: [0x1000: result],
            instructions: [], decompilerAvailable: true)
        XCTAssertEqual(source.records.count, 1)
        XCTAssertEqual(source.records.first?.quality, .reconstructed)
        XCTAssertEqual(source.records.first?.recoveredName, "sc_add")
        let combined = source.files.map(\.contents).joined(separator: "\n")
        XCTAssertTrue(combined.contains("sc_add"))
        XCTAssertFalse(combined.contains("FUN_00101000"))
        XCTAssertTrue(combined.contains("param_1 + param_2"))
        XCTAssertNotNil(source.sourceMap.entry(forAddress: 0x1000))
    }

    func testReconstructWithoutDecompilerFallsBackToAssembly() {
        let image = makeImage(exports: ["sc_ret"], format: .elf, architecture: .x86_64)
        let fn = DecompilerFunction(address: DecompilerAddress(virtual: 0x1000),
                                    endAddress: DecompilerAddress(virtual: 0x1001),
                                    size: 1, name: "sc_ret", kind: .exportedSymbol,
                                    source: AnalysisSource(provenance: .symbolTable))
        let ret = Instruction(address: DecompilerAddress(virtual: 0x1000), rawBytes: Data([0xc3]),
                              size: 1, mnemonic: "ret", operandText: "",
                              source: AnalysisSource(provenance: .engine))
        let source = SourceReconstructor.reconstruct(
            image: image, functions: [fn], pseudocode: [:],
            instructions: [ret], decompilerAvailable: false)
        XCTAssertEqual(source.records.first?.quality, .partial)
        XCTAssertTrue(source.files.contains { $0.relativePath.hasPrefix("Assembly/") })
        XCTAssertTrue(source.diagnostics.contains { $0.message.lowercased().contains("decompiler") })
    }

    /// spotifyglass.dylib-style failure mode: symbol/function metadata
    /// exists but the disassembler decoded nothing and no decompiler ran.
    /// Reconstruction must keep every function unresolved and must not
    /// emit source files that pretend to contain recovered implementations.
    func testMetadataOnlyPipelineNeverClaimsRecovery() {
        let image = makeImage(exports: ["sg_a", "sg_b"], format: .machO, architecture: .arm64)
        let fns = ["sg_a", "sg_b"].enumerated().map { index, name in
            DecompilerFunction(
                address: DecompilerAddress(virtual: 0x1000 + UInt64(index) * 0x100),
                size: 0x100, name: name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .symbolTable))
        }
        let source = SourceReconstructor.reconstruct(
            image: image, functions: fns, pseudocode: [:],
            instructions: [], decompilerAvailable: false)
        XCTAssertEqual(source.records.count, 2)
        XCTAssertTrue(source.records.allSatisfy { $0.quality == .unresolved },
                      "metadata-only functions must be unresolved, got \(source.records.map(\.quality))")
        XCTAssertFalse(source.records.contains { $0.hasPseudocode || $0.hasAssemblyFallback })
        XCTAssertFalse(source.files.contains { $0.relativePath == "Sources/reconstructed.c" },
                       "no C implementations may be emitted without disassembly or pseudocode")
        XCTAssertFalse(source.files.contains { $0.relativePath.hasPrefix("Assembly/") },
                       "no assembly fallback may be emitted without decoded instructions")
        XCTAssertTrue(source.sourceMap.entries.isEmpty,
                      "source map must not claim mappings for unrecovered functions")
        XCTAssertTrue(source.diagnostics.contains {
            $0.message.contains("no disassembly")
        }, "diagnostics must report the missing disassembly honestly")
    }

    // MARK: - Project generation

    func testProjectGenerationLayout() throws {
        let image = makeImage(exports: ["sc_add"], format: .elf, architecture: .x86_64)
        let fn = DecompilerFunction(address: DecompilerAddress(virtual: 0x1000),
                                    endAddress: DecompilerAddress(virtual: 0x1020),
                                    size: 0x20, name: "sc_add", kind: .exportedSymbol,
                                    source: AnalysisSource(provenance: .symbolTable))
        let result = DecompilationResult(
            functionAddress: DecompilerAddress(virtual: 0x1000), functionName: "FUN_00101000",
            pseudocode: "int FUN_00101000(int param_1)\n{\n  return param_1;\n}\n",
            signature: "int FUN_00101000(int param_1)",
            engineID: "ghidra")
        let source = SourceReconstructor.reconstruct(
            image: image, functions: [fn], pseudocode: [0x1000: result],
            instructions: [], decompilerAvailable: true)
        let config = BuildConfiguration.inferred(from: image, libraryName: "fixture")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("recon-test-\(UUID().uuidString)")
        let project = try ReconstructedProjectGenerator.generate(
            source: source, image: image, configuration: config, at: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(project.libraryName, "fixture")
        let package = try String(contentsOf: project.packageManifestURL, encoding: .utf8)
        XCTAssertTrue(package.contains(".dynamic"))
        XCTAssertTrue(package.contains("library"))
        let manifestData = try Data(contentsOf: root.appendingPathComponent("ProjectConfiguration/manifest.json"))
        let manifest = try JSONDecoder().decode(ReconstructedProjectManifest.self, from: manifestData)
        XCTAssertEqual(manifest.originalExports, ["sc_add"])
        let mapData = try Data(contentsOf: project.sourceMapURL)
        let mapDecoder = JSONDecoder()
        mapDecoder.dateDecodingStrategy = .iso8601
        let mapping = try mapDecoder.decode(SourceMapping.self, from: mapData)
        XCTAssertFalse(mapping.entries.isEmpty)
    }

    // MARK: - End-to-end rebuild (Linux gcc fixture; macOS clang when present)

    private func run(_ path: String, _ args: [String]) throws -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, out)
    }

    private func parseObjdump(_ text: String) -> (functions: [String: UInt64], instructions: [Instruction]) {
        var functions: [String: UInt64] = [:]
        var instructions: [Instruction] = []
        var currentName: String?
        let headerPattern = try! NSRegularExpression(pattern: #"^([0-9a-f]+) <([^>]+)>:$"#)
        let insnPattern = try! NSRegularExpression(
            pattern: #"^\s+([0-9a-f]+):\t([0-9a-f ]+)\t(\S+)(?:\s+(.*))?$"#)
        for line in text.components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..., in: line)
            if let m = headerPattern.firstMatch(in: line, range: range),
               let addrRange = Range(m.range(at: 1), in: line),
               let nameRange = Range(m.range(at: 2), in: line),
               let addr = UInt64(String(line[addrRange]), radix: 16) {
                let name = String(line[nameRange])
                functions[name] = addr
                currentName = name
                continue
            }
            guard currentName != nil,
                  let m = insnPattern.firstMatch(in: line, range: range),
                  let addrRange = Range(m.range(at: 1), in: line),
                  let bytesRange = Range(m.range(at: 2), in: line),
                  let mnemonicRange = Range(m.range(at: 3), in: line),
                  let addr = UInt64(String(line[addrRange]), radix: 16) else { continue }
            let hexBytes = String(line[bytesRange]).split(separator: " ")
            var raw = Data()
            for h in hexBytes { if let b = UInt8(h, radix: 16) { raw.append(b) } }
            let mnemonic = String(line[mnemonicRange])
            var operandText = ""
            if m.range(at: 4).location != NSNotFound, let opRange = Range(m.range(at: 4), in: line) {
                operandText = String(line[opRange]).trimmingCharacters(in: .whitespaces)
            }
            instructions.append(Instruction(
                address: DecompilerAddress(virtual: addr), rawBytes: raw, size: raw.count,
                mnemonic: mnemonic, operandText: operandText,
                source: AnalysisSource(provenance: .engine)))
        }
        return (functions, instructions)
    }

    func testEndToEndRebuild() async throws {
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available")
        }
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/objdump") else {
            throw XCTSkip("objdump not available for the fixture disassembly")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let fixture = """
            int sc_add(int a, int b) { return a + b; }
            int sc_answer(void) { return 42; }
            const char *sc_greeting(void) { return "hello"; }
            """
        let fixtureURL = dir.appendingPathComponent("fixture.c")
        try fixture.write(to: fixtureURL, atomically: true, encoding: .utf8)
        let originalURL = dir.appendingPathComponent("libfixture.so")
        let (ccStatus, ccOut) = try run("/usr/bin/cc",
                                        ["-shared", "-fPIC", "-O1", "-o", originalURL.path, fixtureURL.path])
        XCTAssertEqual(ccStatus, 0, ccOut)

        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: originalURL)
        let image = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: originalURL)
        // This test parses GNU `objdump -d` output, which only matches ELF
        // fixtures; on macOS `cc -shared` produces a Mach-O dylib.
        guard image.format == .elf, image.architecture == .x86_64 else {
            throw XCTSkip("fixture is \(image.format.rawValue)/\(image.architecture.rawValue), not ELF/x86_64")
        }

        let (objStatus, objOut) = try run("/usr/bin/objdump", ["-d", "--show-raw-insn", originalURL.path])
        XCTAssertEqual(objStatus, 0)
        let (fnAddrs, allInstructions) = parseObjdump(objOut)
        let exportedNames = image.exports.map(\.name)
        XCTAssertTrue(exportedNames.contains("sc_add"))
        XCTAssertTrue(exportedNames.contains("sc_answer"))
        XCTAssertTrue(exportedNames.contains("sc_greeting"))

        var functions: [DecompilerFunction] = []
        let sortedExports = image.exports.sorted { $0.address.value < $1.address.value }
        for (index, exp) in sortedExports.enumerated() {
            guard let start = fnAddrs[exp.name] else { continue }
            let end: UInt64
            if index + 1 < sortedExports.count, let next = fnAddrs[sortedExports[index + 1].name] {
                end = next
            } else {
                end = exp.address.value + 64
            }
            functions.append(DecompilerFunction(
                address: DecompilerAddress(virtual: start),
                endAddress: DecompilerAddress(virtual: end),
                size: end - start, name: exp.name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .symbolTable)))
        }
        XCTAssertEqual(functions.count, 3)

        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: [:],
            instructions: allInstructions, decompilerAvailable: false)
        XCTAssertEqual(source.records.count, 3)
        XCTAssertTrue(source.records.allSatisfy { $0.quality == .partial })
        let asm = source.files.first { $0.relativePath.hasPrefix("Assembly/") }
        XCTAssertNotNil(asm)
        XCTAssertTrue(asm!.contents.contains("__sc_data_") || asm!.contents.contains(".byte"),
                      "assembly fallback must preserve the string reference or bytes")

        let config = BuildConfiguration.inferred(from: image, libraryName: "fixture")
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try ReconstructedProjectGenerator.generate(
            source: source, image: image, configuration: config, at: root)
        let result = try await AssembleService.assemble(
            project: project, originalImage: image, configuration: config)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))

        let rebuiltContainer = try await loader.loadContainer(at: result.outputURL)
        let rebuilt = try await loader.parseSlice(container: rebuiltContainer, sliceIndex: 0,
                                                  sourceURL: result.outputURL)
        XCTAssertEqual(rebuilt.format, .elf)
        let rebuiltExports = Set(rebuilt.exports.map(\.name))
        XCTAssertTrue(rebuiltExports.contains("sc_add"))
        XCTAssertTrue(rebuiltExports.contains("sc_answer"))
        XCTAssertTrue(rebuiltExports.contains("sc_greeting"))
        XCTAssertNotNil(result.equivalence)
        XCTAssertTrue(result.equivalence?.isABICompatible == true)

        guard let handle = dlopen(result.outputURL.path, RTLD_NOW) else {
            XCTFail("dlopen failed: \(String(cString: dlerror()))")
            return
        }
        defer { dlclose(handle) }
        typealias AddFn = @convention(c) (Int32, Int32) -> Int32
        typealias AnswerFn = @convention(c) () -> Int32
        typealias GreetingFn = @convention(c) () -> UnsafePointer<CChar>
        let add = unsafeBitCast(dlsym(handle, "sc_add"), to: AddFn.self)
        XCTAssertEqual(add(2, 3), 5)
        let answer = unsafeBitCast(dlsym(handle, "sc_answer"), to: AnswerFn.self)
        XCTAssertEqual(answer(), 42)
        let greeting = unsafeBitCast(dlsym(handle, "sc_greeting"), to: GreetingFn.self)
        XCTAssertEqual(String(cString: greeting()), "hello")
    }

    /// End-to-end Mach-O arm64 (iOS) rebuild: parse → container-mode
    /// llvm-objdump disassembly → assembly-preserving reconstruction →
    /// platform-aware clang assemble → equivalence check. Guards on the
    /// iPhoneOS SDK so it runs wherever Xcode CLT is installed.
    func testMachOArm64EndToEndRebuild() async throws {
        #if os(macOS)
        guard let clang = AssembleService.locateCompiler() else {
            throw XCTSkip("no C compiler available")
        }
        let sdk = Self.xcrunSDKPath("iphoneos")
        guard let sdk else { throw XCTSkip("iPhoneOS SDK not available") }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-macho-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let fixture = """
            int sg_add(int a, int b) { return a + b; }
            int sg_answer(void) { return 42; }
            const char *sg_greeting(void) { return "hello"; }
            """
        let fixtureURL = dir.appendingPathComponent("fixture.c")
        try fixture.write(to: fixtureURL, atomically: true, encoding: .utf8)
        let originalURL = dir.appendingPathComponent("libsg.dylib")
        let (ccStatus, ccOut) = try run(clang,
            ["-dynamiclib", "-arch", "arm64", "-isysroot", sdk,
             "-miphoneos-version-min=16.0", "-O1", "-o", originalURL.path, fixtureURL.path])
        XCTAssertEqual(ccStatus, 0, ccOut)

        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: originalURL)
        let image = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: originalURL)
        XCTAssertEqual(image.format, .machO)
        XCTAssertEqual(image.architecture, .arm64)
        XCTAssertEqual(image.targetPlatform, "ios")

        await EngineBootstrap.installDefaults()
        let registry = EngineRegistry.shared
        guard let disassembler = await registry.resolveDisassembler(for: image) else {
            throw XCTSkip("no disassembler backend available")
        }
        let exec = image.executableSections
        let lo = exec.map { $0.address.value }.min() ?? 0
        let hi = exec.map { $0.address.value + $0.size }.max() ?? 0
        let instructions = try await disassembler.disassemble(
            image: image,
            start: DecompilerAddress(virtual: lo),
            end: DecompilerAddress(virtual: hi), progress: nil)
        XCTAssertFalse(instructions.isEmpty, "container-mode disassembly produced no instructions")

        let exportedNames = image.exports.map(\.name)
        for expected in ["sg_add", "sg_answer", "sg_greeting"] {
            XCTAssertTrue(exportedNames.contains(expected)
                          || exportedNames.contains("_\(expected)"),
                          "missing export \(expected) in \(exportedNames)")
        }

        let sortedExports = image.exports.sorted { $0.address.value < $1.address.value }
        var functions: [DecompilerFunction] = []
        var usedAddrs = Set<UInt64>()
        for (index, exp) in sortedExports.enumerated() {
            let addr = exp.address.value
            guard usedAddrs.insert(addr).inserted else { continue }
            var end = addr + 64
            for other in sortedExports[(index + 1)...] {
                if other.address.value > addr { end = other.address.value; break }
            }
            let fnIns = instructions.filter { $0.address.value >= addr && $0.address.value < end }
            guard !fnIns.isEmpty else { continue }
            functions.append(DecompilerFunction(
                address: DecompilerAddress(virtual: addr),
                endAddress: DecompilerAddress(virtual: end),
                size: end - addr, name: exp.name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .symbolTable)))
        }
        XCTAssertGreaterThanOrEqual(functions.count, 3)

        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: [:],
            instructions: instructions, decompilerAvailable: false)
        XCTAssertGreaterThanOrEqual(source.records.count, 3)

        let config = BuildConfiguration.inferred(from: image, libraryName: "sg")
        XCTAssertEqual(config.platform, "ios")
        XCTAssertEqual(config.sdkName, "iphoneos")
        XCTAssertTrue(config.compileArguments(
            source: fixtureURL, object: dir.appendingPathComponent("x.o"),
            projectRoot: dir, format: .machO)
            .contains { $0.hasPrefix("-miphoneos-version-min=") },
            "iOS deployment flag missing from compile arguments")

        let root = dir.appendingPathComponent("Reconstructed")
        let project = try ReconstructedProjectGenerator.generate(
            source: source, image: image, configuration: config, at: root)
        let result = try await AssembleService.assemble(
            project: project, originalImage: image, configuration: config)
        XCTAssertTrue(result.succeeded,
                      result.diagnostics.map { $0.message }.joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))

        let rebuiltContainer = try await loader.loadContainer(at: result.outputURL)
        let rebuilt = try await loader.parseSlice(container: rebuiltContainer, sliceIndex: 0,
                                                  sourceURL: result.outputURL)
        XCTAssertEqual(rebuilt.format, .machO)
        XCTAssertEqual(rebuilt.architecture, .arm64)
        XCTAssertEqual(rebuilt.targetPlatform, "ios")
        let rebuiltExports = Set(rebuilt.exports.map { $0.name.hasPrefix("_") ? String($0.name.dropFirst()) : $0.name })
        for expected in ["sg_add", "sg_answer", "sg_greeting"] {
            XCTAssertTrue(rebuiltExports.contains(expected),
                          "rebuilt library missing export \(expected): \(rebuiltExports)")
        }
        XCTAssertNotNil(result.equivalence)
        XCTAssertEqual(result.equivalence?.missingExports.count, 0,
                       "missing exports: \((result.equivalence?.missingExports ?? []).map { $0.name })")
        #else
        throw XCTSkip("Mach-O tests require macOS")
        #endif
    }

    private static func xcrunSDKPath(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--sdk", name, "--show-sdk-path"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return path.hasPrefix("/") ? path : nil
    }
}
