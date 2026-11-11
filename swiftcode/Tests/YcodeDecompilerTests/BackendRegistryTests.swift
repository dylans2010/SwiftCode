import XCTest
@testable import YcodeDecompiler

final class BackendRegistryTests: XCTestCase {

    func testRegistryResolvesByExtension() {
        XCTAssertEqual(BackendRegistry.backend(forExtension: "c")?.id, "clang")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "cpp")?.id, "clang")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "cc")?.id, "clang")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "m")?.id, "clang")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "mm")?.id, "clang")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "s")?.id, "clang")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "swift")?.id, "swift")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "rs")?.id, "rust")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "go")?.id, "go")
        XCTAssertEqual(BackendRegistry.backend(forExtension: "zig")?.id, "zig")
        XCTAssertNil(BackendRegistry.backend(forExtension: "xyz"))
        XCTAssertNil(BackendRegistry.backend(forExtension: ""))
    }

    func testRegistryResolvesByID() {
        for id in ["clang", "swift", "rust", "go", "zig"] {
            XCTAssertNotNil(BackendRegistry.backend(id: id), id)
        }
        XCTAssertNil(BackendRegistry.backend(id: "not-a-backend"))
    }

    func testAvailableBackendsListsAllNativeBackends() {
        let config = BuildConfiguration(outputFileName: "libx.so", architectures: [.x86_64], format: .elf)
        let listed = BackendRegistry.availableBackends(configuration: config)
        XCTAssertEqual(listed.map(\.0.id).sorted(), ["clang", "go", "rust", "swift", "zig"])
        for (backend, availability) in listed {
            switch availability {
            case .available(let path, _):
                XCTAssertFalse(path.isEmpty, backend.id)
                XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path), backend.id)
            case .unavailable(let reason, let guidance):
                XCTAssertFalse(reason.isEmpty, backend.id)
                XCTAssertFalse(guidance.isEmpty, backend.id)
            }
        }
    }

    func testAllSourceExtensionsCoversRegisteredBackends() {
        let extensions = BackendRegistry.allSourceExtensions()
        for ext in ["c", "m", "mm", "cpp", "cc", "cxx", "s", "S", "swift", "rs", "go", "zig"] {
            XCTAssertTrue(extensions.contains(ext), ext)
        }
        XCTAssertFalse(extensions.contains("xyz"))
    }

    func testGroupSourcesMixed() throws {
        let root = URL(fileURLWithPath: "/proj")
        let sources = ["Sources/a.c", "Sources/b.swift", "Sources/c.rs", "Sources/d.go", "Sources/e.zig", "Assembly/f.s"]
            .map { root.appendingPathComponent($0) }
        let groups = try AssembleService.groupSources(sources, selectedBackend: nil)
        XCTAssertEqual(groups.count, 5)
        XCTAssertEqual(groups.first(where: { $0.backend.id == "clang" })?.sources.count, 2)
        XCTAssertEqual(groups.first(where: { $0.backend.id == "swift" })?.sources.count, 1)
        XCTAssertEqual(groups.first(where: { $0.backend.id == "rust" })?.sources.count, 1)
        XCTAssertEqual(groups.first(where: { $0.backend.id == "go" })?.sources.count, 1)
        XCTAssertEqual(groups.first(where: { $0.backend.id == "zig" })?.sources.count, 1)
    }

    func testGroupSourcesUnknownExtensionThrows() {
        let root = URL(fileURLWithPath: "/proj")
        let sources = [root.appendingPathComponent("Sources/a.xyz")]
        XCTAssertThrowsError(try AssembleService.groupSources(sources, selectedBackend: nil)) { error in
            XCTAssertTrue(error.localizedDescription.contains("xyz"))
        }
    }

    func testGroupSourcesSelectedBackendOverridesExtension() throws {
        let root = URL(fileURLWithPath: "/proj")
        let sources = [root.appendingPathComponent("Sources/a.c"), root.appendingPathComponent("Sources/b.swift")]
        let swift = BackendRegistry.backend(id: "swift")
        XCTAssertNotNil(swift)
        let groups = try AssembleService.groupSources(sources, selectedBackend: swift)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.backend.id, "swift")
        XCTAssertEqual(groups.first?.sources.count, 2)
    }

    func testClangBackendFlagParity() {
        let config = BuildConfiguration(outputFileName: "libfixture.so", architectures: [.x86_64], format: .elf)
        let source = URL(fileURLWithPath: "/x/a.c")
        let object = URL(fileURLWithPath: "/x/a.o")
        let root = URL(fileURLWithPath: "/x")
        let backend = ClangBackend()
        XCTAssertEqual(
            backend.compileArguments(source: source, object: object, projectRoot: root, configuration: config),
            config.compileArguments(source: source, object: object, projectRoot: root, format: .elf))
        XCTAssertEqual(
            backend.linkArguments(objects: [object], sources: [source],
                                  output: URL(fileURLWithPath: "/x/libfixture.so"), configuration: config),
            config.linkArguments(objects: [object], output: URL(fileURLWithPath: "/x/libfixture.so"), format: .elf))
    }

    func testClangBackendLinksCppStdlib() {
        let config = BuildConfiguration(outputFileName: "libx.so", architectures: [.x86_64], format: .elf)
        let cpp = URL(fileURLWithPath: "/x/a.cpp")
        let object = URL(fileURLWithPath: "/x/a.o")
        let args = ClangBackend().linkArguments(objects: [object], sources: [cpp],
                                                output: URL(fileURLWithPath: "/x/libx.so"), configuration: config)
        XCTAssertTrue(args.contains("-lstdc++"))
        let c = URL(fileURLWithPath: "/x/a.c")
        let cArgs = ClangBackend().linkArguments(objects: [object], sources: [c],
                                                 output: URL(fileURLWithPath: "/x/libx.so"), configuration: config)
        XCTAssertFalse(cArgs.contains("-lstdc++"))
    }

    func testMissingToolchainReportsUnavailableWithGuidance() {
        var config = BuildConfiguration(outputFileName: "libx.so", architectures: [.x86_64], format: .elf)
        config.compilerPath = "/nonexistent/clang"
        let availability = ClangBackend().availability(configuration: config)
        switch availability {
        case .available:
            XCTFail("a nonexistent compiler path must not report available")
        case .unavailable(let reason, let guidance):
            XCTAssertTrue(reason.contains("/nonexistent/clang"))
            XCTAssertFalse(guidance.isEmpty)
        }
    }

    func testBuildConfigurationDecodesOldJSONWithoutNewKeys() throws {
        let config = BuildConfiguration(outputFileName: "libold.so", architectures: [.x86_64], format: .elf)
        let data = try JSONEncoder().encode(config)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "selectedBackendID")
        json.removeValue(forKey: "perBackendFlags")
        json.removeValue(forKey: "format")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(BuildConfiguration.self, from: stripped)
        XCTAssertEqual(decoded.outputFileName, "libold.so")
        XCTAssertEqual(decoded.architectures, [.x86_64])
        XCTAssertNil(decoded.selectedBackendID)
        XCTAssertTrue(decoded.perBackendFlags.isEmpty)
        XCTAssertEqual(decoded.format, .unknown)
    }

    func testBuildConfigurationDecodesMinimalJSON() throws {
        let data = #"{"outputFileName": "libmin.so"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BuildConfiguration.self, from: data)
        XCTAssertEqual(decoded.outputFileName, "libmin.so")
        XCTAssertEqual(decoded.optimizationLevel, "2")
        XCTAssertTrue(decoded.debugSymbols)
        XCTAssertEqual(decoded.symbolVisibility, "default")
        XCTAssertNil(decoded.selectedBackendID)
        XCTAssertTrue(decoded.perBackendFlags.isEmpty)
    }

    func testBuildConfigurationRoundTripPreservesNewKeys() throws {
        var config = BuildConfiguration(outputFileName: "libx.so", architectures: [.x86_64], format: .elf)
        config.selectedBackendID = "swift"
        config.perBackendFlags = ["swift": ["-warnings-as-errors"]]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BuildConfiguration.self, from: data)
        XCTAssertEqual(decoded.selectedBackendID, "swift")
        XCTAssertEqual(decoded.perBackendFlags["swift"], ["-warnings-as-errors"])
    }
}
