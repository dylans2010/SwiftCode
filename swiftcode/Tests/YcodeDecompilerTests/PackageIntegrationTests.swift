import XCTest
import Foundation
@testable import YcodeDecompiler
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private final class DataAccumulator: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

final class PackageIntegrationTests: XCTestCase {
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

    private func makeProject() throws -> (ReconstructedProject, BinaryImage, URL) {
        let image = makeImage(exports: ["sc_add"])
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
            .appendingPathComponent("pkgint-test-\(UUID().uuidString)")
        let project = try ReconstructedProjectGenerator.generate(
            source: source, image: image, configuration: config, at: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (project, image, root)
    }

#if canImport(Subprocess)
    func testSubprocessRunnerParity() throws {
        let oldRunner = SubprocessProcessRunner()
        let newRunner = SwiftSubprocessRunner()
        let cases: [(String, [String])] = [
            ("/bin/echo", ["hello", "world"]),
            ("/bin/sh", ["-c", "echo out; echo err >&2"]),
            ("/bin/false", []),
            ("/bin/sh", ["-c", "exit 3"]),
        ]
        for (executable, args) in cases {
            let old = try oldRunner.run(executable: executable, arguments: args,
                                        environment: nil, currentDirectory: nil)
            let new = try newRunner.run(executable: executable, arguments: args,
                                        environment: nil, currentDirectory: nil)
            XCTAssertEqual(new.status, old.status, executable)
            XCTAssertEqual(new.stdoutText, old.stdoutText, executable)
            XCTAssertEqual(new.stderrText, old.stderrText, executable)
        }
    }

    func testSubprocessRunnerStreaming() async throws {
        let runner = SwiftSubprocessRunner()
        let stdoutAccumulator = DataAccumulator()
        let stderrAccumulator = DataAccumulator()
        let code = try await runner.runStreaming(
            executable: "/bin/sh", arguments: ["-c", "echo one; echo two >&2; echo three"],
            environment: nil, currentDirectory: nil,
            onStdout: { stdoutAccumulator.append($0) }, onStderr: { stderrAccumulator.append($0) })
        XCTAssertEqual(code, 0)
        XCTAssertEqual(String(decoding: stdoutAccumulator.value, as: UTF8.self), "one\nthree\n")
        XCTAssertEqual(String(decoding: stderrAccumulator.value, as: UTF8.self), "two\n")
    }

    func testSubprocessRunnerEnvironmentMerge() throws {
        let runner = SwiftSubprocessRunner()
        let result = try runner.run(executable: "/bin/sh", arguments: ["-c", "echo $SC_TEST_MARKER"],
                                    environment: ["SC_TEST_MARKER": "merged-ok"],
                                    currentDirectory: nil)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdoutText, "merged-ok\n")
    }
#endif

#if canImport(SwiftTreeSitter)
    func testTreeSitterValidatorAcceptsValidC() throws {
        guard let language = TreeSitterSourceValidator.language(forExtension: "c") else {
            throw XCTSkip("C grammar not linked")
        }
        let valid = "int sc_add(int a, int b) { return a + b; }\n"
        let diagnostics = TreeSitterSourceValidator.validateTreeSitterSource(
            valid, language: language, relativePath: "Sources/valid.c")
        XCTAssertTrue(diagnostics.isEmpty, diagnostics.map(\.message).joined(separator: "\n"))
    }

    func testTreeSitterValidatorRejectsBrokenC() throws {
        guard let language = TreeSitterSourceValidator.language(forExtension: "c") else {
            throw XCTSkip("C grammar not linked")
        }
        let broken = "int sc_add(int a, int b) { return a + ; }\n"
        let diagnostics = TreeSitterSourceValidator.validateTreeSitterSource(
            broken, language: language, relativePath: "Sources/broken.c")
        XCTAssertFalse(diagnostics.isEmpty)
        XCTAssertTrue(diagnostics.contains { $0.severity == .error })
        XCTAssertEqual(diagnostics.first?.file, "Sources/broken.c")
        XCTAssertNotNil(diagnostics.first?.line)
    }

    func testTreeSitterValidatorAcceptsValidSwiftAndRejectsBrokenSwift() throws {
#if canImport(SwiftParser) && canImport(SwiftParserDiagnostics)
        let valid = "func sc_add(_ a: Int, _ b: Int) -> Int { a + b }\n"
        let validDiagnostics = TreeSitterSourceValidator.validateSwiftSource(
            valid, relativePath: "Sources/valid.swift")
        XCTAssertTrue(validDiagnostics.isEmpty, validDiagnostics.map(\.message).joined(separator: "\n"))
        let broken = "func sc_add(_ a: Int { return a }\n"
        let brokenDiagnostics = TreeSitterSourceValidator.validateSwiftSource(
            broken, relativePath: "Sources/broken.swift")
        XCTAssertFalse(brokenDiagnostics.isEmpty)
        XCTAssertTrue(brokenDiagnostics.contains { $0.severity == .error })
#else
        throw XCTSkip("SwiftParser not linked")
#endif
    }

    func testTreeSitterValidatorEndToEnd() async throws {
        let (project, _, root) = try makeProject()
        let brokenC = root.appendingPathComponent("Sources/reconstructed.c")
        try "int sc_add(int a, int b) { return a + ; }\n".write(to: brokenC, atomically: true, encoding: .utf8)
        let validSwift = root.appendingPathComponent("Sources/extra.swift")
        try "func sc_extra() -> Int { 7 }\n".write(to: validSwift, atomically: true, encoding: .utf8)
        let config = BuildConfiguration.inferred(from: makeImage(exports: ["sc_add"]), libraryName: "fixture")
        let validator = TreeSitterSourceValidator()
        let diagnostics = try await validator.validate(project: project, configuration: config)
        let errors = diagnostics.filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty, "broken C must fail validation")
        XCTAssertTrue(errors.contains { $0.file == "Sources/reconstructed.c" })
        XCTAssertFalse(errors.contains { $0.file == "Sources/extra.swift" },
                       "valid Swift must not produce errors")
    }
#endif

#if canImport(CQuickJS)
    func testQuickJSEvaluatesJavaScript() throws {
        let engine = QuickJSEngine()
        XCTAssertEqual(try engine.evaluate(source: "1 + 2"), 3)
        XCTAssertEqual(try engine.evaluate(source: "function sc_answer() { return 42; } sc_answer()"), 42)
        XCTAssertEqual(try engine.evaluate(source: "let x = 6; x * 7"), 42)
        XCTAssertThrowsError(try engine.evaluate(source: "this is not valid javascript !!!"))
        XCTAssertThrowsError(try engine.evaluate(source: "\"a string\""))
    }

    func testQuickJSEngineShimCode() {
        let engine = QuickJSEngine()
        XCTAssertTrue(engine.cIncludeLines.contains("#include <quickjs.h>"))
        XCTAssertTrue(engine.contextSetupCode().contains("JS_NewRuntime"))
        XCTAssertTrue(engine.evaluateSource(scriptVariable: "sc_script", lengthVariable: "sc_script_len").contains("JS_Eval"))
        XCTAssertTrue(engine.callFunctionCode(functionName: "sc_add", arity: 2).contains("JS_Call"))
    }

    private func packageRoot() -> URL {
        var candidate = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Sources/CQuickJS/quickjs.c").path) {
            let parent = candidate.deletingLastPathComponent()
            guard parent != candidate else { break }
            candidate = parent
        }
        return candidate
    }

    func testQuickJSBackendEndToEnd() async throws {
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available")
        }
        BackendRegistry.register(QuickJSBackend())
        let swiftcodeDir = packageRoot()
        let vendored = swiftcodeDir.appendingPathComponent("Sources/CQuickJS")
        guard FileManager.default.fileExists(atPath: vendored.appendingPathComponent("quickjs.c").path) else {
            throw XCTSkip("vendored QuickJS sources not found at \(vendored.path)")
        }
        setenv("SWIFTCODE_QUICKJS_SOURCES", vendored.path, 1)
        defer { unsetenv("SWIFTCODE_QUICKJS_SOURCES") }
        let (project, image, root) = try makeProject()
        let fm = FileManager.default
        try? fm.removeItem(at: root.appendingPathComponent("Sources"))
        try? fm.removeItem(at: root.appendingPathComponent("Assembly"))
        try fm.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        let script = """
            function sc_add(a, b) { return a + b; }
            function sc_answer() { return 42; }
            """
        try script.write(to: root.appendingPathComponent("Sources/sc_js.js"), atomically: true, encoding: .utf8)
        var config = BuildConfiguration.inferred(from: image, libraryName: "fixture")
        config.exportedSymbols = ["sc_add", "sc_answer"]
        let result = try await AssembleService.assemble(
            project: project, originalImage: image, configuration: config,
            selectedBackendID: "javascript-quickjs")
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(fm.fileExists(atPath: result.outputURL.path))
        guard let handle = dlopen(result.outputURL.path, RTLD_NOW) else {
            XCTFail("dlopen failed: \(String(cString: dlerror()))")
            return
        }
        defer { dlclose(handle) }
        typealias AddFn = @convention(c) (Int32, Int32) -> Int32
        typealias AnswerFn = @convention(c) () -> Int32
        let add = unsafeBitCast(dlsym(handle, "sc_add"), to: AddFn.self)
        XCTAssertEqual(add(2, 3), 5)
        let answer = unsafeBitCast(dlsym(handle, "sc_answer"), to: AnswerFn.self)
        XCTAssertEqual(answer(), 42)
    }

    func testJavaScriptExtensionStillResolvesToJavaScriptCoreAfterQuickJSRegistration() {
        BackendRegistry.register(QuickJSBackend())
        XCTAssertEqual(BackendRegistry.backend(forExtension: "js")?.id, "javascript")
        XCTAssertEqual(BackendRegistry.backend(id: "javascript-quickjs")?.id, "javascript-quickjs")
    }

    func testVendoredQuickJSSourcesMatchResourcesCopy() throws {
        let swiftcodeDir = packageRoot()
        let targetCopy = swiftcodeDir.appendingPathComponent("Sources/CQuickJS")
        let resourceCandidates = [
            swiftcodeDir.appendingPathComponent("Sources/YcodeDecompiler/Resources/QuickJS"),
            swiftcodeDir.appendingPathComponent("Sources/CQuickJSResources"),
        ]
        guard let resourceCopy = resourceCandidates.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("quickjs.c").path)
        }) else {
            throw XCTSkip("no bundled QuickJS resource copy found to compare against")
        }
        for fileName in QuickJSBackend.vendoredFileNames {
            let targetData = try Data(contentsOf: targetCopy.appendingPathComponent(fileName))
            let resourceData = try Data(contentsOf: resourceCopy.appendingPathComponent(fileName))
            XCTAssertEqual(targetData, resourceData, "\(fileName) differs between the C target copy and the bundled resource copy")
        }
    }
#endif

    func testLanguageServerDefinitions() {
        let swift = LanguageServerDefinitions.definition(for: .swift)
        XCTAssertEqual(swift?.binaryNames, ["sourcekit-lsp"])
        XCTAssertTrue(swift?.installGuidance.contains("Xcode") == true)
        let rust = LanguageServerDefinitions.definition(for: .rust)
        XCTAssertEqual(rust?.binaryNames, ["rust-analyzer"])
        let js = LanguageServerDefinitions.definition(languageID: "javascript")
        XCTAssertEqual(js?.binaryNames, ["typescript-language-server"])
        XCTAssertEqual(js?.arguments, ["--stdio"])
        let python = LanguageServerDefinitions.definition(languageID: "python")
        XCTAssertEqual(python?.arguments, ["--stdio"])
        XCTAssertNil(LanguageServerDefinitions.definition(for: .assembly))
        XCTAssertNil(LanguageServerDefinitions.definition(languageID: "unknown-language"))
        XCTAssertFalse(LanguageServerDefinitions.all.isEmpty)
    }

    func testLanguageServerMissingBinaryGuidance() {
        let definition = LanguageServerDefinition(
            languageID: "test-lang", displayName: "test-server",
            binaryNames: ["definitely-not-a-real-binary-xyz"],
            installGuidance: "Install it from the test store.")
        XCTAssertNil(LanguageServerDefinitions.locateBinary(for: definition))
        let message = LanguageServerDefinitions.missingBinaryMessage(for: definition)
        XCTAssertTrue(message.contains("definitely-not-a-real-binary-xyz"))
        XCTAssertTrue(message.contains("Install it from the test store."))
    }

    func testLanguageServerManagerMissingBinary() async {
        let manager = LanguageServerManager(maxRestarts: 0)
        let definition = LanguageServerDefinition(
            languageID: "test-lang", displayName: "test-server",
            binaryNames: ["definitely-not-a-real-binary-xyz"],
            installGuidance: "Install it from the test store.")
        let status = await manager.startServer(for: definition)
        if case .unavailable(let guidance) = status {
            XCTAssertTrue(guidance.contains("Install it from the test store."))
        } else {
            XCTFail("expected unavailable status, got \(status)")
        }
        let testLangStatus = await manager.status(for: "test-lang")
        XCTAssertEqual(testLangStatus.isRunning, false)
    }

    func testLanguageServerManagerLifecycleAndCrashRecovery() async throws {
        let manager = LanguageServerManager(maxRestarts: 2, restartBaseDelaySeconds: 0.01)
        let cat = LanguageServerDefinition(
            languageID: "test-cat", displayName: "cat",
            binaryNames: ["/bin/cat"], arguments: [],
            installGuidance: "cat is a standard system tool.")
        let started = await manager.startServer(for: cat)
        guard case .running = started else {
            throw XCTSkip("could not start /bin/cat as a test server")
        }
        let catStatus = await manager.status(for: "test-cat")
        XCTAssertTrue(catStatus.isRunning)
        await manager.stopServer(languageID: "test-cat")
        try await Task.sleep(nanoseconds: 500_000_000)
        if case .stopped = await manager.status(for: "test-cat") {
        } else {
            XCTFail("expected stopped status after terminate, got \(await manager.status(for: "test-cat"))")
        }
        let failing = LanguageServerDefinition(
            languageID: "test-false", displayName: "false",
            binaryNames: ["/bin/false"], arguments: [],
            installGuidance: "false is a standard system tool.")
        let failedStatus = await manager.startServer(for: failing)
        guard case .running = failedStatus else {
            throw XCTSkip("could not start /bin/false as a test server")
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let info = await manager.info(for: "test-false")
        XCTAssertEqual(info?.restarts, 2)
        if case .failed(let reason, _) = await manager.status(for: "test-false") {
            XCTAssertTrue(reason.contains("false"))
        } else {
            XCTFail("expected failed status after crash recovery exhausted, got \(await manager.status(for: "test-false"))")
        }
    }
}
