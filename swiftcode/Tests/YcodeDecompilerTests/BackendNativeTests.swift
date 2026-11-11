import XCTest
@testable import YcodeDecompiler
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class BackendNativeTests: XCTestCase {

    private func config(library: String = "fixture") -> BuildConfiguration {
        BuildConfiguration(outputFileName: "lib\(library).so", architectures: [.x86_64], format: .elf)
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

    private func buildOriginalFixture(in dir: URL) async throws -> BinaryImage {
        let fixture = "int sc_add(int a, int b) { return a + b; }\nint sc_answer(void) { return 42; }\nconst char *sc_greeting(void) { return \"hello\"; }\n"
        let fixtureURL = dir.appendingPathComponent("fixture.c")
        try fixture.write(to: fixtureURL, atomically: true, encoding: .utf8)
        let originalURL = dir.appendingPathComponent("libfixture.so")
        let (ccStatus, ccOut) = try run("/usr/bin/cc", ["-shared", "-fPIC", "-O1", "-o", originalURL.path, fixtureURL.path])
        XCTAssertEqual(ccStatus, 0, ccOut)
        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: originalURL)
        return try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: originalURL)
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
            sourceMap: SourceMapping(), exportedNames: ["sc_add", "sc_answer", "sc_greeting"],
            unresolvedImports: [], enginesUsed: [], decompilerAvailable: false)
        return ReconstructedProject(rootURL: root, libraryName: libraryName, source: source,
                                    configuration: configuration, manifest: manifest)
    }

    private func checkRebuiltLibrary(_ url: URL) async throws {
        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: url)
        let rebuilt = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: url)
        let exports = Set(rebuilt.exports.map(\.name))
        XCTAssertTrue(exports.contains("sc_add"))
        XCTAssertTrue(exports.contains("sc_answer"))
        XCTAssertTrue(exports.contains("sc_greeting"))
        guard let handle = dlopen(url.path, RTLD_NOW) else {
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

    func testSwiftBackendFlags() {
        let backend = SwiftBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/a.swift")
        let object = URL(fileURLWithPath: "/x/a.o")
        let compile = backend.compileArguments(source: source, object: object, projectRoot: root, configuration: cfg)
        XCTAssertTrue(compile.contains("-c"))
        XCTAssertTrue(compile.contains("-module-name"))
        XCTAssertTrue(compile.contains("fixture"))
        XCTAssertFalse(compile.contains("-emit-library"))
        let link = backend.linkArguments(objects: [object], sources: [source],
                                         output: URL(fileURLWithPath: "/x/libfixture.so"), configuration: cfg)
        XCTAssertTrue(link.contains("-emit-library"))
        XCTAssertTrue(link.contains("/x/libfixture.so"))
    }

    func testRustBackendFlags() {
        let backend = RustBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/lib.rs")
        let args = backend.libraryArguments(sources: [source], output: URL(fileURLWithPath: "/x/libfixture.so"),
                                            projectRoot: root, configuration: cfg)
        XCTAssertTrue(args.contains("--crate-type"))
        XCTAssertTrue(args.contains("cdylib"))
        XCTAssertFalse(args.contains { $0 == "dylib" })
        XCTAssertTrue(args.contains(root.appendingPathComponent("Sources/lib.rs").path))
    }

    func testGoBackendFlags() {
        let backend = GoBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/main.go")
        let args = backend.libraryArguments(sources: [source], output: URL(fileURLWithPath: "/x/libfixture.so"),
                                            projectRoot: root, configuration: cfg)
        XCTAssertTrue(args.contains("build"))
        XCTAssertTrue(args.contains("-buildmode=c-shared"))
        XCTAssertTrue(args.contains("."))
        XCTAssertEqual(backend.libraryEnvironment(configuration: cfg)["CGO_ENABLED"], "1")
        XCTAssertEqual(backend.libraryWorkingDirectory(projectRoot: root, configuration: cfg)?.lastPathComponent, "Sources")
    }

    func testZigBackendFlags() {
        let backend = ZigBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/root.zig")
        let args = backend.libraryArguments(sources: [source], output: URL(fileURLWithPath: "/x/libfixture.so"),
                                            projectRoot: root, configuration: cfg)
        XCTAssertTrue(args.contains("build-lib"))
        XCTAssertTrue(args.contains("-dynamic"))
        XCTAssertTrue(args.contains { $0.hasPrefix("-femit-bin=") })
        let parsed = ZigBackend.parseVersion("0.14.0")
        XCTAssertEqual(parsed?.0, 0)
        XCTAssertEqual(parsed?.1, 14)
        XCTAssertNil(ZigBackend.parseVersion("not-a-version"))
    }

    func testToolDiscoveryReturnsNilForMissingTool() {
        XCTAssertNil(BackendToolDiscovery.locate(xcrunTool: nil, fixedPaths: ["/nonexistent/tool"],
                                                 pathNames: ["definitely-not-a-real-tool-xyz"]))
        XCTAssertNil(BackendToolDiscovery.locateViaXcrun(tool: "definitely-not-a-real-tool-xyz"))
        XCTAssertNil(BackendToolDiscovery.toolVersion("/nonexistent/tool"))
    }

    func testSwiftCdeclGuidance() {
        let backend = SwiftBackend()
        let cfg = config()
        let root = URL(fileURLWithPath: "/x")
        let noExport = URL(fileURLWithPath: "/x/Sources/plain.swift")
        let diagnostics = backend.postCompileDiagnostics(sources: [noExport], projectRoot: root, configuration: cfg)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("@_cdecl") })
    }

    func testSwiftEndToEndRebuild() async throws {
        let backend = SwiftBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("swiftc not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let image = try await buildOriginalFixture(in: dir)
        let swiftSource = """
            #if canImport(Darwin)
            import Darwin
            #elseif canImport(Glibc)
            import Glibc
            #endif
            @_cdecl("sc_add")
            public func sc_add(_ a: Int32, _ b: Int32) -> Int32 { a + b }
            @_cdecl("sc_answer")
            public func sc_answer() -> Int32 { 42 }
            @_cdecl("sc_greeting")
            public func sc_greeting() -> UnsafePointer<CChar> {
                UnsafePointer(strdup("hello")!)
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.swift", swiftSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkRebuiltLibrary(result.outputURL)
    }

    func testRustEndToEndRebuild() async throws {
        let backend = RustBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("rustc not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rust-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let image = try await buildOriginalFixture(in: dir)
        let rustSource = """
            use std::os::raw::{c_char, c_int};
            #[no_mangle]
            pub extern "C" fn sc_add(a: c_int, b: c_int) -> c_int { a + b }
            #[no_mangle]
            pub extern "C" fn sc_answer() -> c_int { 42 }
            #[no_mangle]
            pub extern "C" fn sc_greeting() -> *const c_char {
                b"hello\\0".as_ptr() as *const c_char
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/lib.rs", rustSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkRebuiltLibrary(result.outputURL)
    }

    func testGoEndToEndRebuild() async throws {
        let backend = GoBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("go not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("go-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let image = try await buildOriginalFixture(in: dir)
        let goSource = """
            package main
            import "C"
            //export sc_add
            func sc_add(a C.int, b C.int) C.int { return a + b }
            //export sc_answer
            func sc_answer() C.int { return 42 }
            //export sc_greeting
            func sc_greeting() *C.char { return C.CString("hello") }
            func main() {}
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/main.go", goSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkRebuiltLibrary(result.outputURL)
    }

    func testZigEndToEndRebuild() async throws {
        let backend = ZigBackend()
        let cfg = config()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("zig not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("zig-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let image = try await buildOriginalFixture(in: dir)
        let zigSource = """
            export fn sc_add(a: i32, b: i32) i32 {
                return a + b;
            }
            export fn sc_answer() i32 {
                return 42;
            }
            export fn sc_greeting() [*:0]const u8 {
                return "hello";
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/root.zig", zigSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkRebuiltLibrary(result.outputURL)
    }
}
