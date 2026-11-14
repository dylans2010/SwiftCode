import XCTest
@testable import YcodeDecompiler





final class PipelineReproTests: XCTestCase {

    private let fixturePath = "/Users/dylan/Downloads/Payload/Spotify.app/Frameworks/spotifyglass.dylib"
    private let logPath = "/tmp/swiftcode-pipeline-repro.log"

    private func log(_ message: String) {
        let line = "\(Date()): \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
        print(message)
    }

    func testFullPipelineRepro() async throws {
        guard FileManager.default.fileExists(atPath: fixturePath) else {
            throw XCTSkip("spotifyglass.dylib fixture not present")
        }
        try? "\n=== RUN \(Date()) ===\n".write(toFile: logPath, atomically: true, encoding: .utf8)
        await EngineBootstrap.installDefaults()
        let registry = EngineRegistry.shared
        for d in await registry.descriptors() {
            log("ENGINE \(d.id) kind=\(d.kind) avail=\(d.isAvailable) detail=\(d.availabilityDetail) version=\(d.version ?? "-")")
        }

        let session = DecompilerSession()
        await session.updateConfiguration { $0.maxBulkDecompileFunctions = 50 }

        let url = URL(fileURLWithPath: fixturePath)
        let image = try await session.importBinary(at: url)
        log("IMAGE format=\(image.format) arch=\(image.architecture) platform=\(image.targetPlatform ?? "-") minOS=\(image.minOSVersion ?? "-")")
        log("IMAGE execSections=\(image.executableSections.map { "\($0.segment)/\($0.name)@\($0.address.hexString)+\($0.size)" })")
        log("SYMBOLS=\(image.symbols.count) IMPORTS=\(image.imports.count) EXPORTS=\(image.exports.count) FUNSTARTS=\(image.functionStarts.count)")

        let store = await session.analysisStore()
        let progress = await store.progress
        log("PROGRESS \(progress.stage) \(progress.message)")
        let functions = await session.functions()
        let instructions = await store.instructions
        let pseudocode = await session.pseudocodeResults()
        log("FUNCTIONS=\(functions.count) INSTRUCTIONS=\(instructions.count) PSEUDOCODE=\(pseudocode.count)")
        let findings = await store.findings
        for f in findings.prefix(20) { log("FINDING \(f.title): \(f.detail)") }
        let history = await store.history
        for h in history.suffix(20) { log("HIST \(h.operation) \(h.engineID ?? "-") \(h.detail)") }

        
        let project = try await ReconstructionPipeline.decompileAsset(session: session)
        log("PROJECT root=\(project.rootURL.path)")
        for file in project.source.files {
            log("FILE \(file.relativePath) lang=\(file.language) q=\(file.quality) bytes=\(file.contents.utf8.count)")
        }
        log("RECORDS=\(project.source.records.count) engines=\(project.source.enginesUsed)")
        let q = project.source.records.reduce(into: [String: Int]()) { $0[$1.quality.rawValue, default: 0] += 1 }
        log("QUALITY \(q)")
        for d in project.source.diagnostics.prefix(20) {
            log("DIAG [\(d.severity.rawValue)] \(d.message)")
        }
    }
}
