import XCTest
@testable import YcodeDecompiler
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class BackendEmbeddedTests: XCTestCase {

    private func config(library: String = "fixture", exportedSymbols: [String] = ["sc_add", "sc_answer"]) -> BuildConfiguration {
        BuildConfiguration(outputFileName: "lib\(library).so", architectures: [.x86_64],
                           exportedSymbols: exportedSymbols, format: .elf)
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

    private func buildIntFixture(in dir: URL) async throws -> BinaryImage {
        let fixture = "int sc_add(int a, int b) { return a + b; }\nint sc_answer(void) { return 42; }\n"
        let fixtureURL = dir.appendingPathComponent("fixture.c")
        try fixture.write(to: fixtureURL, atomically: true, encoding: .utf8)
        let originalURL = dir.appendingPathComponent("libfixture.so")
        let (ccStatus, ccOut) = try run("/usr/bin/cc", ["-shared", "-fPIC", "-O1", "-o", originalURL.path, fixtureURL.path])
        XCTAssertEqual(ccStatus, 0, ccOut)
        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: originalURL)
        let image = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: originalURL)
        // These e2e tests configure ELF/x86_64 output; `cc -shared` produces
        // Mach-O on macOS, which the backends under test cannot exercise.
        guard image.format == .elf else {
            throw XCTSkip("fixture is \(image.format.rawValue), not ELF")
        }
        return image
    }

    private func syntheticProject(root: URL, libraryName: String, files: [(String, String)],
                                  configuration: BuildConfiguration) throws -> ReconstructedProject {
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("Headers", isDirectory: true),
                               withIntermediateDirectories: true)
        for (relativePath, contents) in files {
            let url = root.appendingPathComponent(relativePath)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        let manifest = ReconstructedProjectManifest(
            libraryName: libraryName, originalFileName: "libfixture.so",
            originalSHA256: "aa", originalFormat: "elf", originalArchitecture: "x86_64",
            language: "c", decompilerAvailable: false, files: files.map(\.0))
        let source = ReconstructedSource(
            libraryName: libraryName, language: .c, records: [], files: [], diagnostics: [],
            sourceMap: SourceMapping(), exportedNames: configuration.exportedSymbols,
            unresolvedImports: [], enginesUsed: [], decompilerAvailable: false)
        return ReconstructedProject(rootURL: root, libraryName: libraryName, source: source,
                                    configuration: configuration, manifest: manifest)
    }

    private func checkIntLibrary(_ url: URL) async throws {
        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: url)
        let rebuilt = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: url)
        let exports = Set(rebuilt.exports.map(\.name))
        XCTAssertTrue(exports.contains("sc_add"))
        XCTAssertTrue(exports.contains("sc_answer"))
        guard let handle = dlopen(url.path, RTLD_NOW) else {
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

    private func tempDir(prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    func testEmbeddedRegistration() {
        EmbeddedBackends.registerAll()
        XCTAssertEqual(BackendRegistry.backend(id: "javascript")?.kind, .runtimeEmbedded)
        XCTAssertEqual(BackendRegistry.backend(id: "java-jvm")?.kind, .runtimeEmbedded)
        XCTAssertEqual(BackendRegistry.backend(id: "python")?.kind, .runtimeEmbedded)
        XCTAssertEqual(BackendRegistry.backend(id: "lua")?.kind, .runtimeEmbedded)
        for id in ["javascript", "java-jvm", "python", "lua"] {
            XCTAssertEqual(BackendRegistry.backend(id: id)?.buildMode, .object, id)
        }
        XCTAssertEqual(BackendRegistry.backend(forExtension: "py")?.id, "python")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "js")?.id, "javascript")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "lua")?.id, "lua")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "java")?.id, "java-native")
    }

    func testShimSupportByteArray() {
        let text = RuntimeShimSupport.cByteArray(variableName: "sc_test_script", data: Data("AB".utf8))
        XCTAssertTrue(text.contains("static const unsigned char sc_test_script[]"))
        XCTAssertTrue(text.contains("0x41,"))
        XCTAssertTrue(text.contains("0x42,"))
        XCTAssertTrue(text.contains("0x00"))
        XCTAssertTrue(text.contains("static const unsigned long sc_test_script_len = 2;"))
        let empty = RuntimeShimSupport.cByteArray(variableName: "sc_empty", data: Data())
        XCTAssertTrue(empty.contains("static const unsigned long sc_empty_len = 0;"))
    }

    func testShimSupportCIdentifier() {
        XCTAssertEqual(RuntimeShimSupport.cIdentifier("foo-bar.baz"), "foo_bar_baz")
        XCTAssertEqual(RuntimeShimSupport.cIdentifier("9lives"), "_9lives")
        XCTAssertEqual(RuntimeShimSupport.cIdentifier(""), "_")
        XCTAssertEqual(RuntimeShimSupport.cIdentifier("sc_add"), "sc_add")
    }

    func testShimSupportCStringLiteral() {
        XCTAssertEqual(RuntimeShimSupport.cStringLiteral("a\"b\\c"), "\"a\\\"b\\\\c\"")
        XCTAssertEqual(RuntimeShimSupport.cStringLiteral("/plain/path"), "\"/plain/path\"")
    }

    func testShimSupportDefinitions() {
        let python = "def sc_add(a, b):\n    return a + b\ndef sc_answer():\n    return 42\n"
        let pyDefs = RuntimeShimSupport.definitions(in: python, pattern: PythonBackend.definitionPatterns[0])
        XCTAssertEqual(pyDefs["sc_add"], 2)
        XCTAssertEqual(pyDefs["sc_answer"], 0)
        let js = "function sc_add(a, b) { return a + b; }\nconst sc_answer = () => 42;\n"
        var jsDefs: [String: Int] = [:]
        for pattern in JavaScriptBackend.definitionPatterns {
            for (name, arity) in RuntimeShimSupport.definitions(in: js, pattern: pattern) { jsDefs[name] = arity }
        }
        XCTAssertEqual(jsDefs["sc_add"], 2)
        XCTAssertEqual(jsDefs["sc_answer"], 0)
        let lua = "function sc_add(a, b)\n  return a + b\nend\n"
        let luaDefs = RuntimeShimSupport.definitions(in: lua, pattern: LuaBackend.definitionPatterns[0])
        XCTAssertEqual(luaDefs["sc_add"], 2)
        let java = "public class Foo {\n    public static long sc_add(long a, long b) { return a + b; }\n    public static long sc_answer() { return 42; }\n}\n"
        let javaDefs = RuntimeShimSupport.definitions(in: java, pattern: JavaJVMBackend.definitionPatterns[0])
        XCTAssertEqual(javaDefs["sc_add"], 2)
        XCTAssertEqual(javaDefs["sc_answer"], 0)
        XCTAssertEqual(JavaJVMBackend.jniClassName(in: java, fallback: "Foo"), "Foo")
        XCTAssertEqual(JavaJVMBackend.jniClassName(in: "package com.example;\n" + java, fallback: "Foo"), "com/example/Foo")
        XCTAssertEqual(JavaJVMBackend.jniSignature(arity: 0), "()J")
        XCTAssertEqual(JavaJVMBackend.jniSignature(arity: 2), "(JJ)J")
    }

    func testWriteIfChanged() throws {
        let dir = try tempDir(prefix: "shim-write")
        let url = dir.appendingPathComponent("out.txt")
        XCTAssertTrue(try RuntimeShimSupport.writeIfChanged("hello", to: url))
        XCTAssertFalse(try RuntimeShimSupport.writeIfChanged("hello", to: url))
        XCTAssertTrue(try RuntimeShimSupport.writeIfChanged("hello2", to: url))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "hello2")
    }

    func testPythonShimGeneration() throws {
        let cfg = config()
        let dir = try tempDir(prefix: "py-shim")
        let root = dir.appendingPathComponent("Reconstructed")
        let script = "def sc_add(a, b):\n    return a + b\n\ndef sc_answer():\n    return 42\n\ndef sc_unused(a):\n    return a\n"
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.py", script)], configuration: cfg)
        try PythonBackend().prepareProject(projectRoot: root, configuration: cfg)
        let shimURL = root.appendingPathComponent("Build/python/fixture_shim.c")
        XCTAssertTrue(FileManager.default.fileExists(atPath: shimURL.path))
        let shim = try String(contentsOf: shimURL, encoding: .utf8)
        XCTAssertTrue(shim.contains("PyConfig_InitPythonConfig"))
        XCTAssertTrue(shim.contains("Py_InitializeFromConfig"))
        XCTAssertTrue(shim.contains("Py_CompileString"))
        XCTAssertTrue(shim.contains("long sc_add(long arg0, long arg1)"))
        XCTAssertTrue(shim.contains("long sc_answer(void)"))
        XCTAssertFalse(shim.contains("long sc_unused"))
        XCTAssertTrue(shim.contains("sc_python_script"))
        let bundleURL = root.appendingPathComponent("Build/python/fixture.py")
        XCTAssertEqual(try String(contentsOf: bundleURL, encoding: .utf8), script)
        XCTAssertTrue(shim.contains("PyGILState_Ensure"))
        let diagnostics = PythonBackend().postCompileDiagnostics(
            sources: [root.appendingPathComponent("Sources/fixture.py")], projectRoot: root, configuration: cfg)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("not compiled to native code") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("libpython") })
        _ = project
    }

    func testPythonCompileAndLinkFlags() throws {
        guard PythonBackend.locatePythonConfig() != nil else {
            throw XCTSkip("python3-config not available")
        }
        let backend = PythonBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/fixture.py")
        let object = URL(fileURLWithPath: "/x/fixture.o")
        let compile = backend.compileArguments(source: source, object: object, projectRoot: root, configuration: cfg)
        XCTAssertTrue(compile.contains("/x/Build/python/fixture_shim.c"))
        XCTAssertTrue(compile.contains { $0.hasPrefix("-I") && $0.contains("python3") })
        let link = backend.linkArguments(objects: [object], sources: [source],
                                         output: URL(fileURLWithPath: "/x/libfixture.so"), configuration: cfg)
        XCTAssertTrue(link.contains { $0.hasPrefix("-lpython") })
    }

    func testJavaScriptShimGeneration() throws {
        let cfg = config()
        let dir = try tempDir(prefix: "js-shim")
        let root = dir.appendingPathComponent("Reconstructed")
        let script = "function sc_add(a, b) { return a + b; }\nfunction sc_answer() { return 42; }\nfunction sc_unused(a) { return a; }\n"
        _ = try syntheticProject(root: root, libraryName: "fixture",
                                 files: [("Sources/fixture.js", script)], configuration: cfg)
        try JavaScriptBackend().prepareProject(projectRoot: root, configuration: cfg)
        let shimURL = root.appendingPathComponent("Build/javascript/fixture_shim.c")
        XCTAssertTrue(FileManager.default.fileExists(atPath: shimURL.path))
        let shim = try String(contentsOf: shimURL, encoding: .utf8)
        XCTAssertTrue(shim.contains("JSEvaluateScript"))
        XCTAssertTrue(shim.contains("JSGlobalContextCreate"))
        XCTAssertTrue(shim.contains("long sc_add(long arg0, long arg1)"))
        XCTAssertTrue(shim.contains("long sc_answer(void)"))
        XCTAssertFalse(shim.contains("long sc_unused"))
        XCTAssertTrue(shim.contains("sc_native_log"))
        XCTAssertTrue(shim.contains("sc_javascript_script"))
        let bundleURL = root.appendingPathComponent("Build/javascript/fixture.js")
        XCTAssertEqual(try String(contentsOf: bundleURL, encoding: .utf8), script)
        let diagnostics = JavaScriptBackend().postCompileDiagnostics(
            sources: [root.appendingPathComponent("Sources/fixture.js")], projectRoot: root, configuration: cfg)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("not compiled to native code") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("Node.js") })
    }

    func testJavaScriptCompileAndLinkFlags() {
        let backend = JavaScriptBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/fixture.js")
        let object = URL(fileURLWithPath: "/x/fixture.o")
        let compile = backend.compileArguments(source: source, object: object, projectRoot: root, configuration: cfg)
        XCTAssertTrue(compile.contains("/x/Build/javascript/fixture_shim.c"))
        let link = backend.linkArguments(objects: [object], sources: [source],
                                         output: URL(fileURLWithPath: "/x/libfixture.so"), configuration: cfg)
        XCTAssertTrue(link.contains("-framework"))
        XCTAssertTrue(link.contains("JavaScriptCore"))
    }

    func testTypeScriptRejected() throws {
        let cfg = config()
        let dir = try tempDir(prefix: "ts-reject")
        let root = dir.appendingPathComponent("Reconstructed")
        _ = try syntheticProject(root: root, libraryName: "fixture",
                                 files: [("Sources/fixture.ts", "function sc_add(a: number, b: number): number { return a + b; }\n")],
                                 configuration: cfg)
        XCTAssertThrowsError(try JavaScriptBackend().prepareProject(projectRoot: root, configuration: cfg)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Transpile") || error.localizedDescription.contains("transpil"),
                          error.localizedDescription)
            XCTAssertTrue(error.localizedDescription.contains("TypeScript"), error.localizedDescription)
        }
    }

    func testLuaShimGeneration() throws {
        let cfg = config()
        let dir = try tempDir(prefix: "lua-shim")
        let root = dir.appendingPathComponent("Reconstructed")
        let script = "function sc_add(a, b)\n  return a + b\nend\n\nfunction sc_answer()\n  return 42\nend\n"
        _ = try syntheticProject(root: root, libraryName: "fixture",
                                 files: [("Sources/fixture.lua", script)], configuration: cfg)
        try LuaBackend().prepareProject(projectRoot: root, configuration: cfg)
        let shimURL = root.appendingPathComponent("Build/lua/fixture_shim.c")
        XCTAssertTrue(FileManager.default.fileExists(atPath: shimURL.path))
        let shim = try String(contentsOf: shimURL, encoding: .utf8)
        XCTAssertTrue(shim.contains("luaL_newstate"))
        XCTAssertTrue(shim.contains("lua_pcall"))
        XCTAssertTrue(shim.contains("luaL_loadbuffer"))
        XCTAssertTrue(shim.contains("long sc_add(long arg0, long arg1)"))
        XCTAssertTrue(shim.contains("long sc_answer(void)"))
        XCTAssertTrue(shim.contains("sc_lua_script"))
        let diagnostics = LuaBackend().postCompileDiagnostics(
            sources: [root.appendingPathComponent("Sources/fixture.lua")], projectRoot: root, configuration: cfg)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("not compiled to native code") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("not thread-safe") })
    }

    func testJavaShimGeneration() {
        let classesDir = URL(fileURLWithPath: "/x/Reconstructed/Build/JavaJVM/classes")
        let exports = [RuntimeShimSupport.ScriptFunction(name: "sc_add", arity: 2),
                       RuntimeShimSupport.ScriptFunction(name: "sc_answer", arity: 0)]
        let shim = JavaJVMBackend.shimSource(className: "com/example/Foo", classesDirectory: classesDir, exports: exports)
        XCTAssertTrue(shim.contains("JNI_CreateJavaVM"))
        XCTAssertTrue(shim.contains("FindClass"))
        XCTAssertTrue(shim.contains("\"com/example/Foo\""))
        XCTAssertTrue(shim.contains("\"(JJ)J\""))
        XCTAssertTrue(shim.contains("\"()J\""))
        XCTAssertTrue(shim.contains("CallStaticLongMethod"))
        XCTAssertTrue(shim.contains("long sc_add(long arg0, long arg1)"))
        XCTAssertTrue(shim.contains("long sc_answer(void)"))
        XCTAssertTrue(shim.contains("-Djava.class.path=/x/Reconstructed/Build/JavaJVM/classes"))
        XCTAssertTrue(shim.contains("AttachCurrentThread"))
    }

    func testJavaLinkFlags() {
        let home = "/opt/jdk"
        let macFlags = JavaJVMBackend.linkFlags(javaHome: home)
        XCTAssertTrue(macFlags.contains("-ljvm"))
#if os(macOS)
        XCTAssertTrue(macFlags.contains("-ljli"))
        XCTAssertLessThan(macFlags.firstIndex(of: "-ljli")!, macFlags.firstIndex(of: "-ljvm")!)
#endif
        let includes = JavaJVMBackend.includeFlags(javaHome: home)
        XCTAssertTrue(includes.contains("-I\(home)/include"))
    }

    func testAvailabilityHonesty() {
        let cfg = config()
#if os(macOS)
        let js = JavaScriptBackend().availability(configuration: cfg)
        if FileManager.default.fileExists(atPath: "/System/Library/Frameworks/JavaScriptCore.framework") {
            XCTAssertTrue(js.isAvailable)
        } else if case .unavailable(let reason, let guidance) = js {
            XCTAssertFalse(reason.isEmpty)
            XCTAssertFalse(guidance.isEmpty)
        } else {
            XCTFail("unexpected availability state")
        }
#else
        if case .unavailable(let reason, let guidance) = JavaScriptBackend().availability(configuration: cfg) {
            XCTAssertTrue(reason.contains("not available on this platform"))
            XCTAssertFalse(guidance.isEmpty)
        } else {
            XCTFail("JavaScriptCore must be unavailable on Linux")
        }
#endif
        if JavaJVMBackend.locateJavaHome() == nil {
            if case .unavailable(let reason, let guidance) = JavaJVMBackend().availability(configuration: cfg) {
                XCTAssertTrue(reason.contains("JDK"))
                XCTAssertFalse(guidance.isEmpty)
            } else {
                XCTFail("Java backend must be unavailable without a JDK")
            }
        } else {
            XCTAssertTrue(JavaJVMBackend().availability(configuration: cfg).isAvailable)
        }
        if LuaBackend.luaFlags() == nil {
            if case .unavailable(let reason, let guidance) = LuaBackend().availability(configuration: cfg) {
                XCTAssertTrue(reason.contains("Lua"))
                XCTAssertFalse(guidance.isEmpty)
            } else {
                XCTFail("Lua backend must be unavailable without Lua dev files")
            }
        } else {
            XCTAssertTrue(LuaBackend().availability(configuration: cfg).isAvailable)
        }
        if PythonBackend.locatePythonConfig() == nil {
            if case .unavailable(let reason, let guidance) = PythonBackend().availability(configuration: cfg) {
                XCTAssertTrue(reason.contains("python3-config"))
                XCTAssertFalse(guidance.isEmpty)
            } else {
                XCTFail("Python backend must be unavailable without python3-config")
            }
        } else {
            let python = PythonBackend().availability(configuration: cfg)
            XCTAssertTrue(python.isAvailable)
            XCTAssertFalse(python.toolPath?.isEmpty ?? true)
        }
        var badConfig = config()
        badConfig.compilerPath = "/nonexistent/clang"
        if case .unavailable(let reason, _) = PythonBackend().availability(configuration: badConfig) {
            XCTAssertTrue(reason.contains("No C compiler"))
        } else {
            XCTFail("Python backend must be unavailable with a bogus compiler path")
        }
    }

    func testMissingExportWarning() throws {
        let cfg = config(exportedSymbols: ["sc_add", "sc_missing"])
        let dir = try tempDir(prefix: "missing-export")
        let root = dir.appendingPathComponent("Reconstructed")
        _ = try syntheticProject(root: root, libraryName: "fixture",
                                 files: [("Sources/fixture.py", "def sc_add(a, b):\n    return a + b\n")],
                                 configuration: cfg)
        let diagnostics = PythonBackend().postCompileDiagnostics(
            sources: [root.appendingPathComponent("Sources/fixture.py")], projectRoot: root, configuration: cfg)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("sc_missing") && $0.severity == .warning })
        XCTAssertFalse(diagnostics.contains { $0.message.contains("sc_add") && $0.severity == .warning })
    }

    func testPythonEndToEndRebuild() async throws {
        EmbeddedBackends.registerAll()
        let backend = PythonBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("CPython dev files not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = try tempDir(prefix: "py-e2e")
        let image = try await buildIntFixture(in: dir)
        let pythonSource = "def sc_add(a, b):\n    return a + b\n\ndef sc_answer():\n    return 42\n"
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.py", pythonSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image,
                                                        configuration: cfg, selectedBackendID: "python")
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        XCTAssertTrue(result.diagnostics.contains { $0.message.contains("not compiled to native code") })
        try await checkIntLibrary(result.outputURL)
    }

    func testJavaScriptEndToEndRebuild() async throws {
        EmbeddedBackends.registerAll()
        let backend = JavaScriptBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("JavaScriptCore not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = try tempDir(prefix: "js-e2e")
        let image = try await buildIntFixture(in: dir)
        let jsSource = "function sc_add(a, b) { return a + b; }\nfunction sc_answer() { return 42; }\n"
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.js", jsSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image,
                                                        configuration: cfg, selectedBackendID: "javascript")
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkIntLibrary(result.outputURL)
    }

    func testJavaJVMEndToEndRebuild() async throws {
        EmbeddedBackends.registerAll()
        let backend = JavaJVMBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("JDK not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = try tempDir(prefix: "java-e2e")
        let image = try await buildIntFixture(in: dir)
        let javaSource = """
            public class Fixture {
                public static long sc_add(long a, long b) { return a + b; }
                public static long sc_answer() { return 42; }
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/Fixture.java", javaSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image,
                                                        configuration: cfg, selectedBackendID: "java-jvm")
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkIntLibrary(result.outputURL)
    }

    func testLuaEndToEndRebuild() async throws {
        EmbeddedBackends.registerAll()
        let backend = LuaBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("Lua dev files not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = try tempDir(prefix: "lua-e2e")
        let image = try await buildIntFixture(in: dir)
        let luaSource = "function sc_add(a, b)\n  return a + b\nend\n\nfunction sc_answer()\n  return 42\nend\n"
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.lua", luaSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image,
                                                        configuration: cfg, selectedBackendID: "lua")
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkIntLibrary(result.outputURL)
    }
}
