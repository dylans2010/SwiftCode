import Foundation

/// Orchestrates the analysis pipeline for a session: parse → discover
/// functions → symbols → strings → disassembly → references → persist.
/// Every stage reports honest progress; failures preserve completed results.
public struct AnalysisCoordinator: Sendable {
    public let session: DecompilerSession
    public let registry: EngineRegistry

    public init(session: DecompilerSession, registry: EngineRegistry) {
        self.session = session
        self.registry = registry
    }

    public func runFullAnalysis(image: BinaryImage, configuration: AnalysisConfiguration) async throws {
        let store = await session.analysisStore()
        let provenance = AnalysisSource(provenance: .formatParser, pass: "parse")

        // 1. Symbols from format symbol tables.
        await store.setProgress(.init(stage: .buildingSymbols, message: "Importing symbols"))
        await store.upsertSymbols(image.symbols)

        // 2. Functions: entry point + function starts + symbols + discovered.
        await store.setProgress(.init(stage: .discoveringFunctions, message: "Discovering functions"))
        var functions = FunctionDiscovery.discover(image: image, provenance: provenance)
        await store.upsertFunctions(functions)

        // 3. Strings.
        if configuration.extractStrings {
            await store.setProgress(.init(stage: .buildingSymbols, message: "Extracting strings"))
            await store.setStrings(StringAnalysis.extract(image: image))
        }

        // 4. Disassembly of executable sections (bounded).
        if let disassembler = await registry.resolveDisassembler(for: image,
                                                                  preferredID: configuration.preferredDisassemblerID) {
            await store.setProgress(.init(stage: .disassembling, message: "Disassembling \(disassembler.displayName)"))
            var allInstructions: [Instruction] = []
            let sections = image.executableSections
            var disassemblyErrors: [String] = []
            for (idx, section) in sections.enumerated() {
                try Task.checkCancellation()
                let start = section.address
                let end = DecompilerAddress(virtual: section.address.value + section.size)
                do {
                    let chunk = try await disassembler.disassemble(image: image, start: start, end: end,
                                                                    progress: nil)
                    allInstructions.append(contentsOf: chunk)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    disassemblyErrors.append("\(section.name): \(error.localizedDescription)")
                }
                await store.setProgress(.init(stage: .disassembling,
                                              fraction: sections.isEmpty ? nil : Double(idx + 1) / Double(sections.count),
                                              message: "Disassembled \(section.name)",
                                              itemsProcessed: allInstructions.count))
            }
            for error in disassemblyErrors {
                await store.addFinding(AnalysisFinding(
                    title: "Disassembly incomplete",
                    detail: error,
                    provenance: .engine))
            }
            await store.storeInstructions(allInstructions)
            if allInstructions.isEmpty {
                await store.addFinding(AnalysisFinding(
                    title: "No instructions decoded",
                    detail: "The disassembler produced no instructions for the executable sections; function-level assembly preservation and decompilation have no input.",
                    provenance: .engine))
            }

            // 5. Cross-references from decoded control flow.
            if configuration.buildReferences {
                await store.setProgress(.init(stage: .buildingReferences, message: "Building references"))
                let xrefs = CrossReferenceBuilder.build(instructions: allInstructions, image: image)
                await store.addCrossReferences(xrefs)
            }

            // 6. Refine function boundaries from discovered prologues/returns
            //    where the backend gave us real instructions.
            functions = FunctionDiscovery.refine(image: image, instructions: allInstructions,
                                                  existing: await store.functions)
            await store.upsertFunctions(functions)
        } else {
            await store.recordHistory(AnalysisHistoryEntry(operation: "disassembly",
                                                           detail: "no compatible disassembler"))
        }

        // 7. Types from metadata (best-effort, marked as recovered).
        let recoveredTypes = TypeRecovery.recover(image: image)
        await store.upsertTypes(recoveredTypes)

        await store.setProgress(.init(stage: .persisting, message: "Saving analysis"))
        await persistIfPossible(image: image)
        await store.setProgress(.init(stage: .completed, fraction: 1.0, message: "Analysis complete"))
        await store.recordHistory(AnalysisHistoryEntry(operation: "analysis",
                                                       detail: "\(functions.count) functions, \(image.symbols.count) symbols"))
    }

    private func persistIfPossible(image: BinaryImage) async {
        if let project = await session.project {
            try? await AnalysisPersistence.save(store: await session.analysisStore(), project: project, image: image)
        }
    }
}
