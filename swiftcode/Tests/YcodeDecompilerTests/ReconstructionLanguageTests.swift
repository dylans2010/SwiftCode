import XCTest
@testable import YcodeDecompiler
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class ReconstructionLanguageTests: XCTestCase {

    private func makeImage(exports: [(name: String, address: UInt64)], symbols: [String],
                           format: BinaryFormat = .elf,
                           architecture: BinaryArchitecture = .x86_64) -> BinaryImage {
        let identity = BinaryIdentity(sha256: "aa", originalFileName: "libfixture.so",
                                      originalLocation: "/tmp/libfixture.so", fileSize: 100,
                                      format: format, architecture: architecture)
        let textSection = BinarySectionInfo(name: "__text", segment: "__TEXT",
                                            address: DecompilerAddress(virtual: 0x1000), size: 0x100,
                                            fileOffset: 0, flags: 0, isExecutable: true,
                                            isWritable: false, containsStrings: false)
        let textSegment = BinarySegmentInfo(name: "__TEXT", vmAddress: 0x1000, vmSize: 0x100,
                                            fileOffset: 0, fileSize: 0x100, maxProtection: 5,
                                            initialProtection: 5, sections: [textSection])
        let image = BinaryImage(identity: identity, format: format, architecture: architecture,
                                cpuIdentifier: "x86_64", fileType: "dylib", entryPoint: nil,
                                segments: [textSegment], imports: [], exports: exports.map {
                                    BinaryExport(name: $0.name,
                                                 address: DecompilerAddress(virtual: $0.address),
                                                 kind: .function)
                                },
                                dependencies: [], symbols: symbols.map {
                                    BinarySymbol(name: $0, kind: .global,
                                                 source: AnalysisSource(provenance: .symbolTable))
                                },
                                strings: [], functionStarts: [],
                                isEncrypted: false, isSigned: false, entitlements: nil,
                                codeSignatureInfo: nil, buildVersion: nil, minOSVersion: nil,
                                hasDebugInfo: false, byteCount: 0,
                                byteProvider: { _, _ in Data() })
        return image
    }

    private func makeFunction(name: String, address: UInt64) -> DecompilerFunction {
        DecompilerFunction(address: DecompilerAddress(virtual: address),
                           endAddress: DecompilerAddress(virtual: address + 0x20),
                           size: 0x20, name: name, kind: .exportedSymbol,
                           source: AnalysisSource(provenance: .symbolTable))
    }

    private func makePseudocode(address: UInt64, functionName: String,
                                signature: String, body: String) -> DecompilationResult {
        DecompilationResult(
            functionAddress: DecompilerAddress(virtual: address), functionName: functionName,
            pseudocode: "\(signature)\n{\n\(body)\n}\n",
            signature: signature, engineID: "ghidra")
    }

    private func fixtureSource(languageSymbol: String?) -> ReconstructedSource {
        let symbols = languageSymbol.map { [$0] } ?? []
        let image = makeImage(exports: [("sc_add", 0x1000), ("sc_answer", 0x1020),
                                        ("sc_greeting", 0x1040)], symbols: symbols)
        let functions = [makeFunction(name: "sc_add", address: 0x1000),
                         makeFunction(name: "sc_answer", address: 0x1020),
                         makeFunction(name: "sc_greeting", address: 0x1040)]
        let pseudocode: [UInt64: DecompilationResult] = [
            0x1000: makePseudocode(address: 0x1000, functionName: "FUN_00101000",
                                   signature: "int FUN_00101000(int param_1, int param_2)",
                                   body: "  return param_1 + param_2;"),
            0x1020: makePseudocode(address: 0x1020, functionName: "FUN_00101020",
                                   signature: "int FUN_00101020(void)",
                                   body: "  return 42;"),
            0x1040: makePseudocode(address: 0x1040, functionName: "FUN_00101040",
                                   signature: "char *FUN_00101040(void)",
                                   body: "  return \"hello\";"),
        ]
        return SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: pseudocode,
            instructions: [], decompilerAvailable: true)
    }

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

    func testInterfaceEmitterRegistry() {
        XCTAssertNotNil(InterfaceEmitterRegistry.emitter(for: .swift))
        XCTAssertNotNil(InterfaceEmitterRegistry.emitter(for: .rust))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .c))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .cpp))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .objectiveC))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .go))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .java))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .csharp))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .kotlin))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .assembly))
        XCTAssertNil(InterfaceEmitterRegistry.emitter(for: .unknown))
        XCTAssertEqual(InterfaceEmitterRegistry.emitter(for: .swift)?.language, .swift)
        XCTAssertEqual(InterfaceEmitterRegistry.emitter(for: .rust)?.language, .rust)
    }

    func testSwiftEmitterShimsMatchRecoveredNames() {
        let source = fixtureSource(languageSymbol: "$s7fixture6sc_add")
        XCTAssertEqual(source.language, .swift)
        guard let file = source.files.first(where: { $0.relativePath == "Sources/fixture.swift" }) else {
            XCTFail("no Swift interface file was emitted")
            return
        }
        XCTAssertEqual(file.language, .swift)
        XCTAssertEqual(file.quality, .reconstructed)
        XCTAssertTrue(file.contents.contains("@_silgen_name(\"sc_add\")"))
        XCTAssertTrue(file.contents.contains("@_cdecl(\"sc_add_swift\")"))
        XCTAssertTrue(file.contents.contains("public func sc_add(_ param_1: CInt, _ param_2: CInt) -> CInt"))
        XCTAssertTrue(file.contents.contains("__sc_c_sc_add(param_1, param_2)"))
        XCTAssertTrue(file.contents.contains("@_silgen_name(\"sc_answer\")"))
        XCTAssertTrue(file.contents.contains("@_cdecl(\"sc_answer_swift\")"))
        XCTAssertTrue(file.contents.contains("public func sc_answer() -> CInt"))
        XCTAssertTrue(file.contents.contains("@_silgen_name(\"sc_greeting\")"))
        XCTAssertTrue(file.contents.contains("@_cdecl(\"sc_greeting_swift\")"))
        XCTAssertTrue(file.contents.contains("UnsafeMutablePointer<CChar>"))
        XCTAssertFalse(file.contents.contains("FUN_00101000"))
        XCTAssertFalse(file.contents.contains("FUN_00101020"))
        XCTAssertFalse(file.contents.contains("FUN_00101040"))
        XCTAssertFalse(file.contents.contains("sc_missing"))
        let cEntry = source.sourceMap.entry(forAddress: 0x1000)
        XCTAssertEqual(cEntry?.function, "sc_add")
        XCTAssertEqual(cEntry?.file, "Sources/reconstructed.c")
        XCTAssertEqual(cEntry?.language, .c)
        let swiftEntry = source.sourceMap.entries.first {
            $0.address == 0x1000 && $0.file == "Sources/fixture.swift"
        }
        XCTAssertEqual(swiftEntry?.function, "sc_add_swift")
        XCTAssertEqual(swiftEntry?.language, .swift)
        XCTAssertNotNil(swiftEntry?.line)
        XCTAssertTrue(source.diagnostics.allSatisfy { !$0.message.contains("sc_add") })
    }

    func testRustEmitterExternBlockMatchesRecoveredNames() {
        let source = fixtureSource(languageSymbol: "_RNvC7fixture6sc_add")
        XCTAssertEqual(source.language, .rust)
        guard let file = source.files.first(where: { $0.relativePath == "Sources/fixture.rs" }) else {
            XCTFail("no Rust interface file was emitted")
            return
        }
        XCTAssertEqual(file.language, .rust)
        XCTAssertEqual(file.quality, .reconstructed)
        XCTAssertTrue(file.contents.contains("extern \"C\" {"))
        XCTAssertTrue(file.contents.contains("fn sc_add(param_1: core::ffi::c_int, param_2: core::ffi::c_int) -> core::ffi::c_int;"))
        XCTAssertTrue(file.contents.contains("fn sc_answer() -> core::ffi::c_int;"))
        XCTAssertTrue(file.contents.contains("fn sc_greeting() -> *mut core::ffi::c_char;"))
        XCTAssertTrue(file.contents.contains("#[no_mangle]"))
        XCTAssertTrue(file.contents.contains("pub extern \"C\" fn sc_add_rs(param_1: core::ffi::c_int, param_2: core::ffi::c_int) -> core::ffi::c_int {"))
        XCTAssertTrue(file.contents.contains("unsafe { sc_add(param_1, param_2) }"))
        XCTAssertTrue(file.contents.contains("pub extern \"C\" fn sc_answer_rs() -> core::ffi::c_int {"))
        XCTAssertTrue(file.contents.contains("pub extern \"C\" fn sc_greeting_rs() -> *mut core::ffi::c_char {"))
        XCTAssertFalse(file.contents.contains("FUN_00101000"))
        XCTAssertFalse(file.contents.contains("FUN_00101020"))
        XCTAssertFalse(file.contents.contains("FUN_00101040"))
        XCTAssertFalse(file.contents.contains("sc_missing"))
        let rustEntry = source.sourceMap.entries.first {
            $0.address == 0x1000 && $0.file == "Sources/fixture.rs"
        }
        XCTAssertEqual(rustEntry?.function, "sc_add_rs")
        XCTAssertEqual(rustEntry?.language, .rust)
    }

    func testUnresolvedFunctionGetsNoShim() {
        let image = makeImage(exports: [("sc_add", 0x1000), ("sc_missing", 0x1020)],
                              symbols: ["$s7fixture6sc_add"])
        let functions = [makeFunction(name: "sc_add", address: 0x1000),
                         makeFunction(name: "sc_missing", address: 0x1020)]
        let pseudocode: [UInt64: DecompilationResult] = [
            0x1000: makePseudocode(address: 0x1000, functionName: "FUN_00101000",
                                   signature: "int FUN_00101000(int param_1, int param_2)",
                                   body: "  return param_1 + param_2;"),
        ]
        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: pseudocode,
            instructions: [], decompilerAvailable: true)
        XCTAssertEqual(source.records.first { $0.recoveredName == "sc_missing" }?.quality, .unresolved)
        guard let file = source.files.first(where: { $0.relativePath == "Sources/fixture.swift" }) else {
            XCTFail("no Swift interface file was emitted")
            return
        }
        XCTAssertTrue(file.contents.contains("sc_add_swift"))
        XCTAssertFalse(file.contents.contains("sc_missing_swift"))
        XCTAssertFalse(file.contents.contains("@_cdecl(\"sc_missing"))
        XCTAssertTrue(file.contents.contains("sc_missing"))
        XCTAssertTrue(source.diagnostics.contains {
            $0.message.contains("sc_missing") && $0.message.contains("no Swift interface shim")
        })
    }

    func testNoEmitterForCAndGo() {
        let cSource = fixtureSource(languageSymbol: nil)
        XCTAssertEqual(cSource.language, .c)
        XCTAssertFalse(cSource.files.contains { $0.relativePath.hasSuffix(".swift") })
        XCTAssertFalse(cSource.files.contains { $0.relativePath.hasSuffix(".rs") })
        let goSource = fixtureSource(languageSymbol: "runtime.main")
        XCTAssertEqual(goSource.language, .go)
        XCTAssertFalse(goSource.files.contains { $0.relativePath.hasSuffix(".swift") })
        XCTAssertFalse(goSource.files.contains { $0.relativePath.hasSuffix(".rs") })
    }

    func testVoidAndPointerParameters() {
        let image = makeImage(exports: [("sc_void", 0x1000), ("sc_write", 0x1020)],
                              symbols: ["$s7fixture6sc_add"])
        let functions = [makeFunction(name: "sc_void", address: 0x1000),
                         makeFunction(name: "sc_write", address: 0x1020)]
        let pseudocode: [UInt64: DecompilationResult] = [
            0x1000: makePseudocode(address: 0x1000, functionName: "FUN_00101000",
                                   signature: "void FUN_00101000(int param_1)",
                                   body: "  (void)param_1;"),
            0x1020: makePseudocode(address: 0x1020, functionName: "FUN_00101020",
                                   signature: "void FUN_00101020(char *param_1)",
                                   body: "  (void)param_1;"),
        ]
        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: pseudocode,
            instructions: [], decompilerAvailable: true)
        guard let swiftFile = source.files.first(where: { $0.relativePath == "Sources/fixture.swift" }) else {
            XCTFail("no Swift interface file was emitted")
            return
        }
        XCTAssertTrue(swiftFile.contents.contains("public func sc_void(_ param_1: CInt) {"))
        XCTAssertFalse(swiftFile.contents.contains("-> Void"))
        XCTAssertTrue(swiftFile.contents.contains("UnsafeMutablePointer<CChar>"))

        let rustImage = makeImage(exports: [("sc_void", 0x1000), ("sc_write", 0x1020)],
                                  symbols: ["_RNvC7fixture6sc_add"])
        let rustSource = SourceReconstructor.reconstruct(
            image: rustImage, functions: functions, pseudocode: pseudocode,
            instructions: [], decompilerAvailable: true)
        guard let rustFile = rustSource.files.first(where: { $0.relativePath == "Sources/fixture.rs" }) else {
            XCTFail("no Rust interface file was emitted")
            return
        }
        XCTAssertTrue(rustFile.contents.contains("fn sc_void(param_1: core::ffi::c_int);"))
        XCTAssertTrue(rustFile.contents.contains("fn sc_write(param_1: *mut core::ffi::c_char);"))
        XCTAssertTrue(rustFile.contents.contains("pub extern \"C\" fn sc_write_rs(param_1: *mut core::ffi::c_char) {"))
    }

    func testSourceMapLanguageRoundTrip() throws {
        let mapping = SourceMapping(
            entries: [
                SourceMapping.Entry(address: 0x1000, file: "Sources/a.c", line: 3,
                                    function: "foo", quality: .reconstructed, language: .c),
                SourceMapping.Entry(address: 0x1040, file: "Sources/a.swift", line: 9,
                                    function: "foo_swift", quality: .reconstructed, language: .swift),
                SourceMapping.Entry(address: 0x1080, file: "Assembly/original_text.s", line: 1,
                                    function: "bar", quality: .partial, language: .assembly),
            ],
            originalSHA256: "aa", originalFileName: "libx.so")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SourceMapping.self, from: mapping.jsonData())
        XCTAssertEqual(decoded.entries.count, 3)
        XCTAssertEqual(decoded.entry(forAddress: 0x1000)?.language, .c)
        XCTAssertEqual(decoded.entry(forAddress: 0x1040)?.language, .swift)
        XCTAssertEqual(decoded.entry(forAddress: 0x1080)?.language, .assembly)
        XCTAssertEqual(decoded.entry(containing: 0x1044)?.function, "foo_swift")
        let oldJSON = """
            {"entries": [{"address": 4096, "file": "Sources/a.c", "line": 3, "function": "foo", "quality": "reconstructed"}],
             "generatedAt": "2026-11-10T00:00:00Z", "originalSHA256": "aa", "originalFileName": "libx.so"}
            """
        let oldDecoded = try decoder.decode(SourceMapping.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(oldDecoded.entries.count, 1)
        XCTAssertNil(oldDecoded.entry(forAddress: 0x1000)?.language)
        XCTAssertEqual(oldDecoded.entry(forAddress: 0x1000)?.function, "foo")
    }

    func testCCoreByteIdentical() {
        let cSource = fixtureSource(languageSymbol: nil)
        let swiftSource = fixtureSource(languageSymbol: "$s7fixture6sc_add")
        for relativePath in ["Sources/reconstructed.c", "Headers/fixture.h"] {
            let cFile = cSource.files.first { $0.relativePath == relativePath }
            let swiftFile = swiftSource.files.first { $0.relativePath == relativePath }
            XCTAssertNotNil(cFile, relativePath)
            XCTAssertNotNil(swiftFile, relativePath)
            XCTAssertEqual(cFile?.contents, swiftFile?.contents, relativePath)
        }
        XCTAssertNil(cSource.files.first { $0.relativePath == "Sources/fixture.swift" })
        XCTAssertNotNil(swiftSource.files.first { $0.relativePath == "Sources/fixture.swift" })
    }

    func testSwiftEndToEndRebuild() async throws {
        let backend = SwiftBackend()
        let config = BuildConfiguration(outputFileName: "libfixture.so",
                                        architectures: [.x86_64], format: .elf)
        guard case .available = backend.availability(configuration: config) else {
            throw XCTSkip("swiftc not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lang-swift-e2e-\(UUID().uuidString)")
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
        var image = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: originalURL)
        XCTAssertEqual(image.format, .elf)
        image.symbols.append(BinarySymbol(name: "$s7fixture6sc_add", kind: .global,
                                          source: AnalysisSource(provenance: .symbolTable)))

        let sortedExports = image.exports.sorted { $0.address.value < $1.address.value }
        XCTAssertEqual(Set(sortedExports.map(\.name)), ["sc_add", "sc_answer", "sc_greeting"])
        var functions: [DecompilerFunction] = []
        var pseudocode: [UInt64: DecompilationResult] = [:]
        for (index, exp) in sortedExports.enumerated() {
            let start = exp.address.value
            let end: UInt64
            if index + 1 < sortedExports.count {
                end = sortedExports[index + 1].address.value
            } else {
                end = start + 64
            }
            functions.append(DecompilerFunction(
                address: DecompilerAddress(virtual: start),
                endAddress: DecompilerAddress(virtual: end),
                size: end - start, name: exp.name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .symbolTable)))
            let hex = String(start, radix: 16, uppercase: true)
            let padded = String(repeating: "0", count: max(0, 8 - hex.count)) + hex
            let functionName = "FUN_\(padded)"
            switch exp.name {
            case "sc_add":
                pseudocode[start] = DecompilationResult(
                    functionAddress: DecompilerAddress(virtual: start), functionName: functionName,
                    pseudocode: "int \(functionName)(int param_1, int param_2)\n{\n  return param_1 + param_2;\n}\n",
                    signature: "int \(functionName)(int param_1, int param_2)", engineID: "ghidra")
            case "sc_answer":
                pseudocode[start] = DecompilationResult(
                    functionAddress: DecompilerAddress(virtual: start), functionName: functionName,
                    pseudocode: "int \(functionName)(void)\n{\n  return 42;\n}\n",
                    signature: "int \(functionName)(void)", engineID: "ghidra")
            case "sc_greeting":
                pseudocode[start] = DecompilationResult(
                    functionAddress: DecompilerAddress(virtual: start), functionName: functionName,
                    pseudocode: "char *\(functionName)(void)\n{\n  return \"hello\";\n}\n",
                    signature: "char *\(functionName)(void)", engineID: "ghidra")
            default:
                break
            }
        }
        XCTAssertEqual(pseudocode.count, 3)

        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: pseudocode,
            instructions: [], decompilerAvailable: true)
        XCTAssertEqual(source.language, .swift)
        XCTAssertNotNil(source.files.first { $0.relativePath == "Sources/fixture.swift" })

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
        let rebuiltExports = Set(rebuilt.exports.map(\.name))
        XCTAssertTrue(rebuiltExports.contains("sc_add"))
        XCTAssertTrue(rebuiltExports.contains("sc_answer"))
        XCTAssertTrue(rebuiltExports.contains("sc_greeting"))
        XCTAssertTrue(rebuiltExports.contains("sc_add_swift"))
        XCTAssertTrue(rebuiltExports.contains("sc_answer_swift"))
        XCTAssertTrue(rebuiltExports.contains("sc_greeting_swift"))
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
        let addSwift = unsafeBitCast(dlsym(handle, "sc_add_swift"), to: AddFn.self)
        XCTAssertEqual(addSwift(2, 3), 5)
        let answerSwift = unsafeBitCast(dlsym(handle, "sc_answer_swift"), to: AnswerFn.self)
        XCTAssertEqual(answerSwift(), 42)
        let greetingSwift = unsafeBitCast(dlsym(handle, "sc_greeting_swift"), to: GreetingFn.self)
        XCTAssertEqual(String(cString: greetingSwift()), "hello")
    }

    func testRustEndToEndRebuild() async throws {
        let backend = RustBackend()
        let config = BuildConfiguration(outputFileName: "libfixture.so",
                                        architectures: [.x86_64], format: .elf)
        guard case .available = backend.availability(configuration: config) else {
            throw XCTSkip("rustc not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lang-rust-e2e-\(UUID().uuidString)")
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
        var image = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: originalURL)
        image.symbols.append(BinarySymbol(name: "_RNvC7fixture6sc_add", kind: .global,
                                          source: AnalysisSource(provenance: .symbolTable)))
        let sortedExports = image.exports.sorted { $0.address.value < $1.address.value }
        var functions: [DecompilerFunction] = []
        var pseudocode: [UInt64: DecompilationResult] = [:]
        for (index, exp) in sortedExports.enumerated() {
            let start = exp.address.value
            let end: UInt64
            if index + 1 < sortedExports.count {
                end = sortedExports[index + 1].address.value
            } else {
                end = start + 64
            }
            functions.append(DecompilerFunction(
                address: DecompilerAddress(virtual: start),
                endAddress: DecompilerAddress(virtual: end),
                size: end - start, name: exp.name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .symbolTable)))
            let hex = String(start, radix: 16, uppercase: true)
            let padded = String(repeating: "0", count: max(0, 8 - hex.count)) + hex
            let functionName = "FUN_\(padded)"
            switch exp.name {
            case "sc_add":
                pseudocode[start] = DecompilationResult(
                    functionAddress: DecompilerAddress(virtual: start), functionName: functionName,
                    pseudocode: "int \(functionName)(int param_1, int param_2)\n{\n  return param_1 + param_2;\n}\n",
                    signature: "int \(functionName)(int param_1, int param_2)", engineID: "ghidra")
            case "sc_answer":
                pseudocode[start] = DecompilationResult(
                    functionAddress: DecompilerAddress(virtual: start), functionName: functionName,
                    pseudocode: "int \(functionName)(void)\n{\n  return 42;\n}\n",
                    signature: "int \(functionName)(void)", engineID: "ghidra")
            case "sc_greeting":
                pseudocode[start] = DecompilationResult(
                    functionAddress: DecompilerAddress(virtual: start), functionName: functionName,
                    pseudocode: "char *\(functionName)(void)\n{\n  return \"hello\";\n}\n",
                    signature: "char *\(functionName)(void)", engineID: "ghidra")
            default:
                break
            }
        }
        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: pseudocode,
            instructions: [], decompilerAvailable: true)
        XCTAssertEqual(source.language, .rust)
        guard let rsFile = source.files.first(where: { $0.relativePath == "Sources/fixture.rs" }) else {
            XCTFail("no Rust interface file was emitted")
            return
        }

        let root = dir.appendingPathComponent("RustOnly")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("Sources", isDirectory: true),
                               withIntermediateDirectories: true)
        try rsFile.contents.write(to: root.appendingPathComponent("Sources/fixture.rs"),
                                  atomically: true, encoding: .utf8)
        let manifest = ReconstructedProjectManifest(
            libraryName: "fixture", originalFileName: "libfixture.so",
            originalSHA256: "aa", originalFormat: "elf", originalArchitecture: "x86_64",
            language: "rust", decompilerAvailable: false, files: ["Sources/fixture.rs"])
        let emptySource = ReconstructedSource(
            libraryName: "fixture", language: .rust, records: [], files: [], diagnostics: [],
            sourceMap: SourceMapping(), exportedNames: ["sc_add_rs", "sc_answer_rs", "sc_greeting_rs"],
            unresolvedImports: [], enginesUsed: [], decompilerAvailable: false)
        let project = ReconstructedProject(rootURL: root, libraryName: "fixture", source: emptySource,
                                           configuration: config, manifest: manifest)
        let result = try await AssembleService.assemble(
            project: project, originalImage: image, configuration: config)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))

        let rebuiltContainer = try await loader.loadContainer(at: result.outputURL)
        let rebuilt = try await loader.parseSlice(container: rebuiltContainer, sliceIndex: 0,
                                                  sourceURL: result.outputURL)
        let rebuiltExports = Set(rebuilt.exports.map(\.name))
        XCTAssertTrue(rebuiltExports.contains("sc_add_rs"))
        XCTAssertTrue(rebuiltExports.contains("sc_answer_rs"))
        XCTAssertTrue(rebuiltExports.contains("sc_greeting_rs"))

        guard let coreHandle = dlopen(originalURL.path, RTLD_NOW | RTLD_GLOBAL) else {
            XCTFail("dlopen of C core failed: \(String(cString: dlerror()))")
            return
        }
        defer { dlclose(coreHandle) }
        guard let handle = dlopen(result.outputURL.path, RTLD_NOW) else {
            XCTFail("dlopen failed: \(String(cString: dlerror()))")
            return
        }
        defer { dlclose(handle) }
        typealias AddFn = @convention(c) (Int32, Int32) -> Int32
        typealias AnswerFn = @convention(c) () -> Int32
        typealias GreetingFn = @convention(c) () -> UnsafePointer<CChar>
        let addRs = unsafeBitCast(dlsym(handle, "sc_add_rs"), to: AddFn.self)
        XCTAssertEqual(addRs(2, 3), 5)
        let answerRs = unsafeBitCast(dlsym(handle, "sc_answer_rs"), to: AnswerFn.self)
        XCTAssertEqual(answerRs(), 42)
        let greetingRs = unsafeBitCast(dlsym(handle, "sc_greeting_rs"), to: GreetingFn.self)
        XCTAssertEqual(String(cString: greetingRs()), "hello")
    }
}
