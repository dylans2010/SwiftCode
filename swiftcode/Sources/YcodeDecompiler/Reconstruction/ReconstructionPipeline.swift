import Foundation

public enum ReconstructionPipeline {
    public static func decompileAsset(session: DecompilerSession) async throws -> ReconstructedProject {
        guard let image = await session.binary() else {
            throw DecompilerError.invalidRequest("No binary loaded. Import a binary before running Decompile Asset.")
        }
        let store = await session.analysisStore()
        await store.setProgress(AnalysisProgress(stage: .decompiling, message: "Decompiling asset"))
        if await store.functions.isEmpty {
            try await session.runAnalysis()
        }
        var decompilerAvailable = false
        var bulkNote: String?
        do {
            _ = try await session.decompileAllFunctions()
            decompilerAvailable = true
        } catch let error as DecompilerError {
            bulkNote = error.localizedDescription
        } catch {
            bulkNote = error.localizedDescription
        }
        let functions = await session.functions()
        let pseudocode = await session.pseudocodeResults()
        let instructions = Array(await store.instructions.values)
        if !decompilerAvailable {
            await store.addFinding(AnalysisFinding(
                title: "Bulk decompilation unavailable",
                detail: bulkNote ?? "No decompiler backend is available. Assembly fallback will be used.",
                provenance: .engine))
        }
        await store.setProgress(AnalysisProgress(stage: .decompiling, fraction: 0.7,
                                                 message: "Reconstructing source"))
        let source = SourceReconstructor.reconstruct(
            image: image, functions: functions, pseudocode: pseudocode,
            instructions: instructions, decompilerAvailable: decompilerAvailable)
        let project = await session.reconstructedProject
        let rootURL: URL
        if let existing = project {
            rootURL = existing.rootURL
        } else if let bundle = await session.project?.bundleURL {
            rootURL = bundle.appendingPathComponent("Reconstructed", isDirectory: true)
        } else {
            let created = try await DecompilerProjectManager.shared.create(
                name: source.libraryName, session: session)
            await session.attachProject(created)
            rootURL = created.bundleURL.appendingPathComponent("Reconstructed", isDirectory: true)
        }
        var configuration = BuildConfiguration.inferred(from: image, libraryName: source.libraryName)
        let savedConfigURL = rootURL.appendingPathComponent("Build/build-config.json")
        if let savedData = try? Data(contentsOf: savedConfigURL),
           let saved = try? JSONDecoder().decode(BuildConfiguration.self, from: savedData) {
            configuration = saved
        }
        let generated = try ReconstructedProjectGenerator.generate(
            source: source, image: image, configuration: configuration, at: rootURL)
        await session.setReconstructedProject(generated)
        await store.setProgress(AnalysisProgress(stage: .completed, fraction: 1.0,
                                                 message: "Decompiled \(functions.count) functions into \(generated.rootURL.lastPathComponent)"))
        await store.recordHistory(AnalysisHistoryEntry(
            operation: "decompile-asset",
            detail: "\(source.records.count) functions, \(source.files.count) files, decompiler: \(decompilerAvailable ? "yes" : "no")"))
        return generated
    }

    public static func loadReconstructedProject(session: DecompilerSession) async -> ReconstructedProject? {
        if let existing = await session.reconstructedProject {
            return existing
        }
        guard let bundle = await session.project?.bundleURL else { return nil }
        let rootURL = bundle.appendingPathComponent("Reconstructed", isDirectory: true)
        let manifestURL = rootURL.appendingPathComponent("ProjectConfiguration/manifest.json")
        let configURL = rootURL.appendingPathComponent("Build/build-config.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ReconstructedProjectManifest.self, from: manifestData),
              let configData = try? Data(contentsOf: configURL),
              let configuration = try? JSONDecoder().decode(BuildConfiguration.self, from: configData),
              let image = await session.binary() else { return nil }
        let source = SourceReconstructor.reconstruct(
            image: image, functions: await session.functions(),
            pseudocode: await session.pseudocodeResults(),
            instructions: Array(await session.analysisStore().instructions.values),
            decompilerAvailable: manifest.decompilerAvailable)
        let project = ReconstructedProject(rootURL: rootURL, libraryName: manifest.libraryName,
                                           source: source, configuration: configuration,
                                           manifest: manifest)
        await session.setReconstructedProject(project)
        return project
    }

    public static func assemble(session: DecompilerSession,
                                configuration: BuildConfiguration? = nil) async throws -> AssemblyResult {
        guard let image = await session.binary() else {
            throw DecompilerError.invalidRequest("No binary loaded.")
        }
        guard let project = await loadReconstructedProject(session: session) else {
            throw DecompilerError.invalidRequest("No reconstructed project yet. Run Decompile Asset first.")
        }
        let config = configuration ?? project.configuration
        let store = await session.analysisStore()
        await store.setProgress(AnalysisProgress(stage: .building, message: "Assembling \(config.outputFileName)"))
        let result = try await AssembleService.assemble(
            project: project, originalImage: image, configuration: config) { progress in
                Task { await store.setProgress(progress) }
            }
        await session.setLastAssembly(result)
        await store.setProgress(AnalysisProgress(
            stage: result.succeeded ? .completed : .failed,
            fraction: result.succeeded ? 1.0 : nil,
            message: result.succeeded
                ? "Assembled \(config.outputFileName)"
                : "Assembly failed: \(result.errors.first?.message ?? "unknown error")"))
        await store.recordHistory(AnalysisHistoryEntry(
            operation: "assemble",
            detail: "\(config.outputFileName) — \(result.succeeded ? "succeeded" : "failed") (\(result.filesCompiled.count) compiled, \(result.filesReused.count) reused)",
            succeeded: result.succeeded))
        return result
    }
}
