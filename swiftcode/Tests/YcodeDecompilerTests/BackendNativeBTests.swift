import XCTest
@testable import YcodeDecompiler
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class BackendNativeBTests: XCTestCase {

    private func config(library: String = "fixture") -> BuildConfiguration {
        BuildConfiguration(outputFileName: "lib\(library).so", architectures: [.x86_64], format: .elf)
    }

    private func machOConfig(library: String = "fixture") -> BuildConfiguration {
        BuildConfiguration(outputFileName: "lib\(library).dylib", architectures: [.arm64], format: .machO)
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

    private func tempDir(prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func write(_ relativePath: String, _ contents: String, in root: URL) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
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
            originalSHA256: "aa", originalFormat: "mach-o", originalArchitecture: "arm64",
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

    private func checkRebuiltLibraryWithoutClose(_ url: URL) async throws {
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

    private func checkJavaLibrary(_ url: URL) async throws {
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
        XCTAssertNotNil(dlsym(handle, "graal_create_isolate"))
        XCTAssertNotNil(dlsym(handle, "graal_tear_down_isolate"))
        typealias CreateIsolateFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
        typealias AddFn = @convention(c) (UnsafeMutableRawPointer?, Int32, Int32) -> Int32
        typealias AnswerFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
        typealias GreetingFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafePointer<CChar>
        typealias TearDownFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
        let create = unsafeBitCast(dlsym(handle, "graal_create_isolate"), to: CreateIsolateFn.self)
        var isolate: UnsafeMutableRawPointer?
        var thread: UnsafeMutableRawPointer?
        XCTAssertEqual(create(nil, &isolate, &thread), 0)
        XCTAssertNotNil(thread)
        let add = unsafeBitCast(dlsym(handle, "sc_add"), to: AddFn.self)
        XCTAssertEqual(add(thread, 2, 3), 5)
        let answer = unsafeBitCast(dlsym(handle, "sc_answer"), to: AnswerFn.self)
        XCTAssertEqual(answer(thread), 42)
        let greeting = unsafeBitCast(dlsym(handle, "sc_greeting"), to: GreetingFn.self)
        XCTAssertEqual(String(cString: greeting(thread)), "hello")
        let tearDown = unsafeBitCast(dlsym(handle, "graal_tear_down_isolate"), to: TearDownFn.self)
        XCTAssertEqual(tearDown(thread), 0)
    }

    private func checkKotlinLibrary(_ url: URL) async throws {
        let loader = BinaryLoader()
        let container = try await loader.loadContainer(at: url)
        let rebuilt = try await loader.parseSlice(container: container, sliceIndex: 0, sourceURL: url)
        let exports = Set(rebuilt.exports.map(\.name))
        XCTAssertTrue(exports.contains("libfixture_symbols"))
        guard let handle = dlopen(url.path, RTLD_NOW) else {
            XCTFail("dlopen failed: \(String(cString: dlerror()))")
            return
        }
        defer { dlclose(handle) }
        XCTAssertNotNil(dlsym(handle, "libfixture_symbols"))
    }

    private func checkNimLibrary(_ url: URL) async throws {
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
        typealias InitFn = @convention(c) () -> Void
        typealias AddFn = @convention(c) (Int32, Int32) -> Int32
        typealias AnswerFn = @convention(c) () -> Int32
        typealias GreetingFn = @convention(c) () -> UnsafePointer<CChar>
        let initFn = unsafeBitCast(dlsym(handle, "sc_init"), to: InitFn.self)
        initFn()
        let add = unsafeBitCast(dlsym(handle, "sc_add"), to: AddFn.self)
        XCTAssertEqual(add(2, 3), 5)
        let answer = unsafeBitCast(dlsym(handle, "sc_answer"), to: AnswerFn.self)
        XCTAssertEqual(answer(), 42)
        let greeting = unsafeBitCast(dlsym(handle, "sc_greeting"), to: GreetingFn.self)
        XCTAssertEqual(String(cString: greeting()), "hello")
    }

    func testBatchBRegistration() {
        NativeBackendsB.registerAll()
        XCTAssertEqual(BackendRegistry.backend(id: "csharp")?.displayName, "C# (NativeAOT)")
        XCTAssertEqual(BackendRegistry.backend(id: "java-native")?.displayName, "Java (GraalVM Native Image)")
        XCTAssertEqual(BackendRegistry.backend(id: "kotlin")?.displayName, "Kotlin/Native")
        XCTAssertEqual(BackendRegistry.backend(id: "nim")?.displayName, "Nim")
        XCTAssertEqual(BackendRegistry.backend(id: "d")?.displayName, "D (LDC)")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "cs")?.id, "csharp")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "java")?.id, "java-native")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "kt")?.id, "kotlin")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "nim")?.id, "nim")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "d")?.id, "d")
        for id in ["csharp", "java-native", "kotlin", "nim", "d"] {
            XCTAssertEqual(BackendRegistry.backend(id: id)?.buildMode, .library, id)
            XCTAssertEqual(BackendRegistry.backend(id: id)?.kind, .native, id)
        }
    }

    func testCSharpCsprojGeneration() throws {
        let backend = CSharpBackend()
        let cfg = machOConfig()
        let root = try tempDir(prefix: "csharp-csproj")
        _ = try write("Sources/fixture.cs", "public static class Fixture {}", in: root)
        try backend.prepareProject(projectRoot: root, configuration: cfg)
        let csprojURL = root.appendingPathComponent("Build/CSharp/fixture.csproj")
        XCTAssertTrue(FileManager.default.fileExists(atPath: csprojURL.path))
        let contents = try String(contentsOf: csprojURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("<PublishAot>true</PublishAot>"))
        XCTAssertTrue(contents.contains("<NativeLib>Shared</NativeLib>"))
        XCTAssertTrue(contents.contains("<TargetFramework>net8.0</TargetFramework>"))
        XCTAssertTrue(contents.contains("<AssemblyName>libfixture</AssemblyName>"))
        XCTAssertTrue(contents.contains("../../Sources/**/*.cs"))
    }

    func testCSharpLibraryArguments() {
        let backend = CSharpBackend()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/fixture.cs")
        let output = URL(fileURLWithPath: "/x/Build/libfixture.dylib")
        let args = backend.libraryArguments(sources: [source], output: output, projectRoot: root,
                                            configuration: machOConfig())
        XCTAssertEqual(args.first, "publish")
        XCTAssertTrue(args.contains("/x/Build/CSharp/fixture.csproj"))
        XCTAssertTrue(args.contains("-c"))
        XCTAssertTrue(args.contains("Release"))
        XCTAssertTrue(args.contains("-r"))
        XCTAssertTrue(args.contains("osx-arm64"))
        XCTAssertTrue(args.contains("-o"))
        XCTAssertTrue(args.contains("/x/Build"))
        var x86Config = machOConfig()
        x86Config.architectures = [.x86_64]
        let x86Args = backend.libraryArguments(sources: [source], output: output, projectRoot: root,
                                               configuration: x86Config)
        XCTAssertTrue(x86Args.contains("osx-x64"))
        XCTAssertFalse(x86Args.contains("osx-arm64"))
    }

    func testCSharpTargetFrameworkSelection() {
        XCTAssertEqual(CSharpBackend.targetFramework(sdkVersions: ["8.0.409", "9.0.100"]), "net9.0")
        XCTAssertEqual(CSharpBackend.targetFramework(sdkVersions: ["8.0.409"]), "net8.0")
        XCTAssertEqual(CSharpBackend.targetFramework(sdkVersions: ["7.0.100"]), "net8.0")
        XCTAssertEqual(CSharpBackend.targetFramework(sdkVersions: []), "net8.0")
        XCTAssertEqual(CSharpBackend.targetFramework(sdkVersions: ["10.0.100"]), "net10.0")
        XCTAssertNil(CSharpBackend.sdkMajorVersion("not-a-version"))
        XCTAssertEqual(CSharpBackend.sdkMajorVersion("8.0.409"), 8)
    }

    func testCSharpAvailabilityReportsHonestly() {
        let backend = CSharpBackend()
        let cfg = config()
        if CSharpBackend.locateDotnet() == nil {
            guard case .unavailable(let reason, let guidance) = backend.availability(configuration: cfg) else {
                return XCTFail("dotnet absent but backend reported available")
            }
            XCTAssertTrue(reason.contains(".NET") || reason.contains("dotnet"))
            XCTAssertFalse(guidance.isEmpty)
        } else {
            guard case .available(let path, _) = backend.availability(configuration: cfg) else {
                return XCTFail("dotnet present but backend reported unavailable")
            }
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    func testCSharpUnmanagedCallersOnlyWarning() throws {
        let backend = CSharpBackend()
        let root = try tempDir(prefix: "csharp-diag")
        _ = try write("Sources/plain.cs", "public static class Plain {}", in: root)
        let diagnostics = backend.parseDiagnostics("", projectRoot: root)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("UnmanagedCallersOnly") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("dlclose") })
        let withExport = try tempDir(prefix: "csharp-diag-export")
        _ = try write("Sources/export.cs", "using System.Runtime.InteropServices;\npublic static class E { [UnmanagedCallersOnly] public static int F() => 1; }", in: withExport)
        let clean = backend.parseDiagnostics("", projectRoot: withExport)
        XCTAssertFalse(clean.contains { $0.message.contains("No [UnmanagedCallersOnly]") })
    }

    func testCSharpDotnetErrorParsing() {
        let root = URL(fileURLWithPath: "/x")
        let text = "/x/Sources/fixture.cs(3,14): error CS1002: ; expected\n/x/Sources/fixture.cs(5,1): warning CS0219: unused variable"
        let diagnostics = CSharpBackend.parseDotnetOutput(text, projectRoot: root)
        XCTAssertEqual(diagnostics.count, 2)
        let error = diagnostics[0]
        XCTAssertEqual(error.severity, .error)
        XCTAssertEqual(error.file, "Sources/fixture.cs")
        XCTAssertEqual(error.line, 3)
        XCTAssertEqual(error.column, 14)
        XCTAssertTrue(error.message.contains("CS1002"))
        XCTAssertEqual(diagnostics[1].severity, .warning)
    }

    func testJavaLibraryArguments() throws {
        let backend = JavaNativeBackend()
        let root = try tempDir(prefix: "java-args")
        let source = try write("Sources/Fixture.java",
                               "import org.graalvm.nativeimage.c.function.CEntryPoint;\npublic class Fixture {\n @CEntryPoint(name = \"sc_add\")\n static int scAdd() { return 0; }\n}\n",
                               in: root)
        let output = root.appendingPathComponent("Build/libfixture.dylib")
        let args = backend.libraryArguments(sources: [source], output: output, projectRoot: root,
                                            configuration: machOConfig())
        XCTAssertTrue(args.contains("--shared"))
        XCTAssertTrue(args.contains("-H:Name=libfixture"))
        XCTAssertTrue(args.contains("-cp"))
        XCTAssertTrue(args.contains(root.appendingPathComponent("Build/JavaNative/classes").path))
        XCTAssertTrue(args.contains("Fixture"))
        let workingDir = backend.libraryWorkingDirectory(projectRoot: root, configuration: machOConfig())
        XCTAssertEqual(workingDir?.lastPathComponent, "Build")
        XCTAssertTrue(workingDir?.path.hasPrefix(root.path) == true)
    }

    func testJavaEntryClassDetection() throws {
        let root = try tempDir(prefix: "java-entry")
        let helper = try write("Sources/Helper.java", "public class Helper {\n public static int help() { return 1; }\n}\n", in: root)
        let fixture = try write("Sources/Fixture.java", "package com.example;\nimport org.graalvm.nativeimage.c.function.CEntryPoint;\npublic class Fixture {\n @CEntryPoint(name = \"sc_add\")\n static int scAdd() { return 0; }\n}\n", in: root)
        XCTAssertEqual(JavaNativeBackend.entryClassName(sources: [helper, fixture]), "com.example.Fixture")
        XCTAssertEqual(JavaNativeBackend.className(in: "package a.b;\npublic class Foo {\n}\n"), "a.b.Foo")
        XCTAssertNil(JavaNativeBackend.className(in: "interface Nothing {\n}\n"))
    }

    func testJavaAvailabilityReportsHonestly() {
        let backend = JavaNativeBackend()
        let cfg = config()
        if JavaNativeBackend.locateNativeImage() == nil {
            guard case .unavailable(let reason, let guidance) = backend.availability(configuration: cfg) else {
                return XCTFail("native-image absent but backend reported available")
            }
            XCTAssertTrue(reason.contains("GraalVM") || reason.contains("native-image"))
            XCTAssertFalse(guidance.isEmpty)
        } else {
            guard case .available(let path, _) = backend.availability(configuration: cfg) else {
                return XCTFail("native-image present but backend reported unavailable")
            }
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    func testJavaCEntryPointWarning() throws {
        let backend = JavaNativeBackend()
        let root = try tempDir(prefix: "java-diag")
        _ = try write("Sources/plain.java", "public class Plain {\n public static void main(String[] args) {}\n}\n", in: root)
        let diagnostics = backend.parseDiagnostics("", projectRoot: root)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("@CEntryPoint") })
        let withEntry = try tempDir(prefix: "java-diag-entry")
        _ = try write("Sources/Fixture.java", "import org.graalvm.nativeimage.c.function.CEntryPoint;\npublic class Fixture {\n @CEntryPoint(name = \"sc_add\")\n static int scAdd() { return 0; }\n}\n", in: withEntry)
        let clean = backend.parseDiagnostics("", projectRoot: withEntry)
        XCTAssertFalse(clean.contains { $0.message.contains("No @CEntryPoint") })
        let closedWorld = backend.parseDiagnostics("Error: No instances of java.lang.reflect.Method are allowed in the image heap. To allow this, use -H:ReflectionConfigurationFiles=reflect-config.json", projectRoot: withEntry)
        XCTAssertTrue(closedWorld.contains { $0.message.contains("closed-world") })
    }

    func testKotlinGradleGeneration() throws {
        let backend = KotlinBackend()
        let cfg = machOConfig()
        let root = try tempDir(prefix: "kotlin-gradle")
        _ = try write("Sources/fixture.kt", "fun sc_add(a: Int, b: Int): Int = a + b\n", in: root)
        try backend.prepareProject(projectRoot: root, configuration: cfg)
        let settingsURL = root.appendingPathComponent("Build/Kotlin/settings.gradle.kts")
        let buildURL = root.appendingPathComponent("Build/Kotlin/build.gradle.kts")
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: buildURL.path))
        let settings = try String(contentsOf: settingsURL, encoding: .utf8)
        XCTAssertTrue(settings.contains("rootProject.name = \"fixture\""))
        let build = try String(contentsOf: buildURL, encoding: .utf8)
        XCTAssertTrue(build.contains("kotlin(\"multiplatform\") version \"2.0.21\""))
        XCTAssertTrue(build.contains("macosArm64"))
        XCTAssertTrue(build.contains("sharedLib"))
        XCTAssertTrue(build.contains("baseName = \"fixture\""))
        XCTAssertTrue(build.contains("kotlin.srcDir(\"../../Sources\")"))
        XCTAssertTrue(build.contains("linkDebugSharedMacosArm64"))
        XCTAssertTrue(build.contains("copyBuiltDylib"))
        XCTAssertTrue(build.contains("build/bin/macosArm64/debugShared/libfixture.dylib"))
        XCTAssertTrue(build.contains(root.appendingPathComponent("Build").path))
    }

    func testKotlinLibraryArguments() {
        let backend = KotlinBackend()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/fixture.kt")
        let output = URL(fileURLWithPath: "/x/Build/libfixture.dylib")
        let args = backend.libraryArguments(sources: [source], output: output, projectRoot: root,
                                            configuration: machOConfig())
        XCTAssertEqual(args, ["linkDebugSharedMacosArm64", "copyBuiltDylib"])
        XCTAssertEqual(backend.libraryWorkingDirectory(projectRoot: root, configuration: machOConfig())?.lastPathComponent, "Kotlin")
        XCTAssertEqual(KotlinBackend.linkTaskName(configuration: machOConfig()), "linkDebugSharedMacosArm64")
        var x86Config = machOConfig()
        x86Config.architectures = [.x86_64]
        XCTAssertEqual(KotlinBackend.linkTaskName(configuration: x86Config), "linkDebugSharedMacosX64")
    }

    func testKotlinAvailabilityReportsHonestly() {
        let backend = KotlinBackend()
        let cfg = config()
        if KotlinBackend.locateGradle() == nil {
            guard case .unavailable(let reason, let guidance) = backend.availability(configuration: cfg) else {
                return XCTFail("gradle absent but backend reported available")
            }
            XCTAssertTrue(reason.contains("Gradle"))
            XCTAssertFalse(guidance.isEmpty)
        } else {
            guard case .available(let path, _) = backend.availability(configuration: cfg) else {
                return XCTFail("gradle present but backend reported unavailable")
            }
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    func testKotlinGatewayDiagnostic() throws {
        let backend = KotlinBackend()
        let root = try tempDir(prefix: "kotlin-diag")
        let buildDir = root.appendingPathComponent("Build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(machOConfig())
        try data.write(to: buildDir.appendingPathComponent("build-config.json"))
        let diagnostics = backend.parseDiagnostics("", projectRoot: root)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("libfixture_symbols()") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("libfixture_ExportedSymbols") })
    }

    func testNimLibraryArguments() {
        let backend = NimBackend()
        let root = URL(fileURLWithPath: "/x")
        let source = URL(fileURLWithPath: "/x/Sources/lib.nim")
        let output = URL(fileURLWithPath: "/x/libfixture.so")
        let args = backend.libraryArguments(sources: [source], output: output, projectRoot: root,
                                            configuration: config())
        XCTAssertTrue(args.contains("c"))
        XCTAssertTrue(args.contains("--app:lib"))
        XCTAssertTrue(args.contains("--noMain"))
        XCTAssertTrue(args.contains("--gc:orc"))
        XCTAssertTrue(args.contains("-d:release"))
        XCTAssertTrue(args.contains("--out:/x/libfixture.so"))
        XCTAssertTrue(args.contains("/x/Sources/lib.nim"))
        XCTAssertFalse(args.contains("--shared"))
    }

    func testNimAvailabilityReportsHonestly() {
        let backend = NimBackend()
        let cfg = config()
        if NimBackend.locateNim() == nil {
            guard case .unavailable(let reason, let guidance) = backend.availability(configuration: cfg) else {
                return XCTFail("nim absent but backend reported available")
            }
            XCTAssertTrue(reason.contains("Nim"))
            XCTAssertFalse(guidance.isEmpty)
        } else {
            guard case .available(let path, _) = backend.availability(configuration: cfg) else {
                return XCTFail("nim present but backend reported unavailable")
            }
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    func testNimExportAndInitDiagnostics() throws {
        let backend = NimBackend()
        let root = try tempDir(prefix: "nim-diag")
        _ = try write("Sources/plain.nim", "proc helper(): cint = 1\n", in: root)
        let diagnostics = backend.parseDiagnostics("", projectRoot: root)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("exportc") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("NimMain()") })
        let withExport = try tempDir(prefix: "nim-diag-export")
        _ = try write("Sources/lib.nim", "proc sc_add(a: cint, b: cint): cint {.exportc, dynlib, cdecl.} = a + b\n", in: withExport)
        let clean = backend.parseDiagnostics("", projectRoot: withExport)
        XCTAssertFalse(clean.contains { $0.message.contains("No {.exportc.}") })
        let parsed = LibraryBackendSupport.parseParenthesizedDiagnostics(
            "/x/Sources/lib.nim(3, 14) Error: undeclared identifier: 'foo'\n/x/Sources/lib.nim(5, 1) Warning: unused import",
            projectRoot: URL(fileURLWithPath: "/x"))
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].severity, .error)
        XCTAssertEqual(parsed[0].file, "Sources/lib.nim")
        XCTAssertEqual(parsed[0].line, 3)
        XCTAssertEqual(parsed[0].column, 14)
        XCTAssertEqual(parsed[1].severity, .warning)
    }

    func testDLibraryArguments() {
        let backend = DBackend()
        let root = URL(fileURLWithPath: "/x")
        let sources = [URL(fileURLWithPath: "/x/Sources/util.d"), URL(fileURLWithPath: "/x/Sources/lib.d")]
        let output = URL(fileURLWithPath: "/x/libfixture.so")
        let args = backend.libraryArguments(sources: sources, output: output, projectRoot: root,
                                            configuration: config())
        XCTAssertTrue(args.contains("-shared"))
        XCTAssertTrue(args.contains("-of=/x/libfixture.so"))
        XCTAssertTrue(args.contains("-O2"))
        XCTAssertTrue(args.contains("/x/Sources/lib.d"))
        XCTAssertTrue(args.contains("/x/Sources/util.d"))
        XCTAssertLessThan(args.firstIndex(of: "/x/Sources/lib.d") ?? 99,
                          args.firstIndex(of: "/x/Sources/util.d") ?? 99)
    }

    func testDAvailabilityReportsHonestly() {
        let backend = DBackend()
        let cfg = config()
        if DBackend.locateLdc2() == nil && DBackend.locateDmd() == nil {
            guard case .unavailable(let reason, let guidance) = backend.availability(configuration: cfg) else {
                return XCTFail("neither ldc2 nor dmd present but backend reported available")
            }
            XCTAssertTrue(reason.contains("LDC"))
            XCTAssertFalse(guidance.isEmpty)
        } else if DBackend.locateLdc2() == nil {
            guard case .unavailable(let reason, _) = backend.availability(configuration: cfg) else {
                return XCTFail("only dmd present but backend reported available")
            }
            XCTAssertTrue(reason.contains("DMD"))
            XCTAssertTrue(reason.contains("druntime"))
        } else {
            guard case .available(let path, _) = backend.availability(configuration: cfg) else {
                return XCTFail("ldc2 present but backend reported unavailable")
            }
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }
    }

    func testDmdRefusal() {
        guard case .unavailable(let reason, let guidance) = DBackend.dmdRefusal(dmdPath: "/usr/bin/dmd") else {
            return XCTFail("dmd refusal must report unavailable")
        }
        XCTAssertTrue(reason.contains("DMD"))
        XCTAssertTrue(reason.contains("libphobos2.dylib"))
        XCTAssertTrue(reason.contains("druntime"))
        XCTAssertTrue(guidance.contains("LDC"))
    }

    func testDExportAndRuntimeDiagnostics() throws {
        let backend = DBackend()
        let root = try tempDir(prefix: "d-diag")
        _ = try write("Sources/plain.d", "int helper(int a) { return a; }\n", in: root)
        let diagnostics = backend.parseDiagnostics("", projectRoot: root)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("No export attribute") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("libphobos2-ldc-shared") })
        let parsed = LibraryBackendSupport.parseParenthesizedDiagnostics(
            "Sources/lib.d(2,5): Error: undefined identifier `foo`",
            projectRoot: URL(fileURLWithPath: "/x"))
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].severity, .error)
        XCTAssertEqual(parsed[0].file, "Sources/lib.d")
        XCTAssertEqual(parsed[0].line, 2)
        XCTAssertEqual(parsed[0].column, 5)
    }

    func testMultiArchitectureWarning() throws {
        let backend = CSharpBackend()
        let root = try tempDir(prefix: "multiarch")
        var multi = machOConfig()
        multi.architectures = [.arm64, .x86_64]
        let buildDir = root.appendingPathComponent("Build", isDirectory: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try JSONEncoder().encode(multi).write(to: buildDir.appendingPathComponent("build-config.json"))
        let diagnostics = backend.parseDiagnostics("", projectRoot: root)
        XCTAssertTrue(diagnostics.contains { $0.message.contains("multiple architectures") })
        XCTAssertTrue(diagnostics.contains { $0.suggestion?.contains("lipo") == true })
        let single = try tempDir(prefix: "singlearch")
        let singleBuildDir = single.appendingPathComponent("Build", isDirectory: true)
        try FileManager.default.createDirectory(at: singleBuildDir, withIntermediateDirectories: true)
        try JSONEncoder().encode(machOConfig()).write(to: singleBuildDir.appendingPathComponent("build-config.json"))
        let singleDiagnostics = backend.parseDiagnostics("", projectRoot: single)
        XCTAssertFalse(singleDiagnostics.contains { $0.message.contains("multiple architectures") })
    }

    func testCSharpEndToEndRebuild() async throws {
        let backend = CSharpBackend()
        let cfg = machOConfig()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("dotnet not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        NativeBackendsB.registerAll()
        let dir = try tempDir(prefix: "csharp-e2e")
        let image = try await buildOriginalFixture(in: dir)
        let csharpSource = """
            using System.Runtime.InteropServices;

            public static class Fixture
            {
                [UnmanagedCallersOnly(EntryPoint = "sc_add")]
                public static int ScAdd(int a, int b)
                {
                    return a + b;
                }

                [UnmanagedCallersOnly(EntryPoint = "sc_answer")]
                public static int ScAnswer()
                {
                    return 42;
                }

                [UnmanagedCallersOnly(EntryPoint = "sc_greeting")]
                public static IntPtr ScGreeting()
                {
                    return Marshal.StringToHGlobalAnsi("hello");
                }
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.cs", csharpSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkRebuiltLibraryWithoutClose(result.outputURL)
    }

    func testJavaNativeEndToEndRebuild() async throws {
        let backend = JavaNativeBackend()
        let cfg = machOConfig()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("GraalVM native-image not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        NativeBackendsB.registerAll()
        let dir = try tempDir(prefix: "java-e2e")
        let image = try await buildOriginalFixture(in: dir)
        let javaSource = """
            import org.graalvm.nativeimage.IsolateThread;
            import org.graalvm.nativeimage.c.function.CEntryPoint;
            import org.graalvm.nativeimage.c.type.CCharPointer;
            import org.graalvm.nativeimage.c.type.CTypeConversion;

            public class Fixture {
                @CEntryPoint(name = "sc_add")
                static int scAdd(IsolateThread thread, int a, int b) {
                    return a + b;
                }

                @CEntryPoint(name = "sc_answer")
                static int scAnswer(IsolateThread thread) {
                    return 42;
                }

                @CEntryPoint(name = "sc_greeting")
                static CCharPointer scGreeting(IsolateThread thread) {
                    return CTypeConversion.toCString("hello").get();
                }
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/Fixture.java", javaSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkJavaLibrary(result.outputURL)
    }

    func testKotlinEndToEndRebuild() async throws {
        let backend = KotlinBackend()
        let cfg = machOConfig()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("gradle not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        NativeBackendsB.registerAll()
        let dir = try tempDir(prefix: "kotlin-e2e")
        let image = try await buildOriginalFixture(in: dir)
        let kotlinSource = """
            fun sc_add(a: Int, b: Int): Int {
                return a + b
            }

            fun sc_answer(): Int {
                return 42
            }

            fun sc_greeting(): String {
                return "hello"
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/fixture.kt", kotlinSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        try await checkKotlinLibrary(result.outputURL)
    }

    func testNimEndToEndRebuild() async throws {
        let backend = NimBackend()
        let cfg = machOConfig()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("nim not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        NativeBackendsB.registerAll()
        let dir = try tempDir(prefix: "nim-e2e")
        let image = try await buildOriginalFixture(in: dir)
        let nimSource = """
            proc NimMain() {.cdecl, importc.}

            proc sc_init() {.exportc, dynlib, cdecl.} =
              NimMain()

            proc sc_add(a: cint, b: cint): cint {.exportc, dynlib, cdecl.} =
              a + b

            proc sc_answer(): cint {.exportc, dynlib, cdecl.} =
              42

            proc sc_greeting(): cstring {.exportc, dynlib, cdecl.} =
              "hello"
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/lib.nim", nimSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkNimLibrary(result.outputURL)
    }

    func testDEndToEndRebuild() async throws {
        let backend = DBackend()
        let cfg = machOConfig()
        guard case .available = backend.availability(configuration: cfg) else {
            throw XCTSkip("ldc2 not available")
        }
        guard AssembleService.locateCompiler() != nil else {
            throw XCTSkip("no C compiler available for the original fixture")
        }
        NativeBackendsB.registerAll()
        let dir = try tempDir(prefix: "d-e2e")
        let image = try await buildOriginalFixture(in: dir)
        let dSource = """
            export extern(C) int sc_add(int a, int b) {
                return a + b;
            }

            export extern(C) int sc_answer() {
                return 42;
            }

            export extern(C) const(char)* sc_greeting() {
                return "hello".ptr;
            }
            """
        let root = dir.appendingPathComponent("Reconstructed")
        let project = try syntheticProject(root: root, libraryName: "fixture",
                                           files: [("Sources/lib.d", dSource)],
                                           configuration: cfg)
        let result = try await AssembleService.assemble(project: project, originalImage: image, configuration: cfg)
        XCTAssertTrue(result.succeeded, result.diagnostics.map(\.message).joined(separator: "\n"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertTrue(result.equivalence?.isABICompatible == true)
        try await checkRebuiltLibrary(result.outputURL)
    }
}
