import Foundation




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

        
        await store.setProgress(.init(stage: .buildingSymbols, message: "Importing symbols"))
        await store.upsertSymbols(image.symbols)
        await store.recordHistory(AnalysisHistoryEntry(
            operation: "symbols", detail: "\(image.symbols.count) symbols imported"))

        
        await store.setProgress(.init(stage: .discoveringFunctions, message: "Discovering functions"))
        var functions = FunctionDiscovery.discover(image: image, provenance: provenance)
        await store.upsertFunctions(functions)
        await store.recordHistory(AnalysisHistoryEntry(
            operation: "functions", detail: "\(functions.count) functions discovered"))

        
        if configuration.extractStrings {
            await store.setProgress(.init(stage: .buildingSymbols, message: "Extracting strings"))
            let strings = StringAnalysis.extract(image: image)
            await store.setStrings(strings)
            await store.recordHistory(AnalysisHistoryEntry(
                operation: "strings", detail: "\(strings.count) strings extracted"))
        }

        
        if let disassembler = await registry.resolveDisassembler(for: image,
                                                                  preferredID: configuration.preferredDisassemblerID) {
            await store.setProgress(.init(stage: .disassembling, message: "Disassembling \(disassembler.displayName)"))
            await store.recordHistory(AnalysisHistoryEntry(
                operation: "disassembly", engineID: disassembler.id,
                detail: "\(disassembler.displayName) on \(image.executableSections.count) sections"))
            var allInstructions: [Instruction] = []
            let sections = image.executableSections
            var disassemblyErrors: [String] = []
            for (idx, section) in sections.enumerated() {
                try Task.checkCancellation()
                let start = section.address
                let end = DecompilerAddress(virtual: section.address.value + section.size)
                
                
                
                let progressBox = LatestProgress()
                let priorCount = allInstructions.count
                let flush = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard let latest = progressBox.latest else { continue }
                        let base = sections.isEmpty ? 0 : Double(idx) / Double(sections.count)
                        let span = sections.isEmpty ? 1 : 1.0 / Double(sections.count)
                        await store.setProgress(AnalysisProgress(
                            stage: .disassembling,
                            fraction: base + span * (latest.fraction ?? 0),
                            message: latest.message.isEmpty
                                ? "Disassembling \(section.name) (\(disassembler.displayName))"
                                : latest.message,
                            itemsProcessed: priorCount + latest.itemsProcessed,
                            itemsTotal: latest.itemsTotal))
                    }
                }
                do {
                    let chunk = try await disassembler.disassemble(
                        image: image, start: start, end: end,
                        progress: { progressBox.update($0) })
                    allInstructions.append(contentsOf: chunk)
                } catch is CancellationError {
                    flush.cancel()
                    throw CancellationError()
                } catch {
                    disassemblyErrors.append("\(section.name): \(error.localizedDescription)")
                }
                flush.cancel()
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
                await store.recordHistory(AnalysisHistoryEntry(
                    operation: "disassembly", detail: error, succeeded: false))
            }
            await store.storeInstructions(allInstructions)
            await store.recordHistory(AnalysisHistoryEntry(
                operation: "instructions",
                detail: "\(allInstructions.count) instructions decoded"))
            if allInstructions.isEmpty {
                await store.addFinding(AnalysisFinding(
                    title: "No instructions decoded",
                    detail: "The disassembler produced no instructions for the executable sections; function-level assembly preservation and decompilation have no input.",
                    provenance: .engine))
            }

            
            if configuration.buildReferences {
                await store.setProgress(.init(stage: .buildingReferences, message: "Building references"))
                let xrefs = CrossReferenceBuilder.build(instructions: allInstructions, image: image)
                await store.addCrossReferences(xrefs)
                await store.recordHistory(AnalysisHistoryEntry(
                    operation: "references", detail: "\(xrefs.count) cross-references built"))
            }

            
            
            functions = FunctionDiscovery.refine(image: image, instructions: allInstructions,
                                                  existing: await store.functions)
            await store.upsertFunctions(functions)
            await store.recordHistory(AnalysisHistoryEntry(
                operation: "functions",
                detail: "\(functions.count) functions after boundary refinement"))
        } else {
            await store.recordHistory(AnalysisHistoryEntry(operation: "disassembly",
                                                           detail: "no compatible disassembler"))
        }

        
        let recoveredTypes = TypeRecovery.recover(image: image)
        await store.upsertTypes(recoveredTypes)

        await store.setProgress(.init(stage: .persisting, message: "Saving analysis"))
        await persistIfPossible(image: image)
        await store.setProgress(.init(stage: .completed, fraction: 1.0, message: "Analysis complete"))
        await store.recordHistory(AnalysisHistoryEntry(operation: "analysis",
                                                       detail: "\(functions.count) functions, \(image.symbols.count) symbols"))
    }

    
    
    private final class LatestProgress: @unchecked Sendable {
        private let lock = NSLock()
        private var value: AnalysisProgress?

        var latest: AnalysisProgress? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func update(_ progress: AnalysisProgress) {
            lock.lock()
            value = progress
            lock.unlock()
        }
    }

    private func persistIfPossible(image: BinaryImage) async {
        if let project = await session.project {
            try? await AnalysisPersistence.save(store: await session.analysisStore(), project: project, image: image)
        }
    }
}
