import Foundation




public actor DecompilerSession {
    public enum Mode: String, Sendable, Codable, CaseIterable {
        case friendly, master
    }

    public let id: UUID
    public let store = AnalysisStore()
    public var configuration = AnalysisConfiguration()
    public private(set) var mode: Mode = .friendly
    public private(set) var selectedSliceIndex: Int = 0
    
    public private(set) var sourceURL: URL?
    
    public private(set) var project: DecompilerProject?
    
    public private(set) var navigationHistory: [DecompilerAddress] = []
    public private(set) var navigationIndex: Int = -1
    
    public private(set) var bookmarks: [DecompilerAddress] = []

    private let registry: EngineRegistry
    private var analysisTask: Task<Void, Never>?
    public private(set) var reconstructedProject: ReconstructedProject?
    public private(set) var lastAssembly: AssemblyResult?
    public private(set) var selectedBackendID: String?

    public func setSelectedBackendID(_ id: String?) {
        selectedBackendID = id
    }

    public func setReconstructedProject(_ project: ReconstructedProject?) {
        reconstructedProject = project
    }

    public func setLastAssembly(_ result: AssemblyResult?) {
        lastAssembly = result
    }

    public init(id: UUID = UUID(), registry: EngineRegistry = .shared) {
        self.id = id
        self.registry = registry
    }

    

    
    
    @discardableResult
    public func importBinary(at url: URL, sliceIndex: Int? = nil) async throws -> BinaryImage {
        try await AnalysisSecurityPolicy.validateImport(url: url)
        selectedBackendID = nil
        lastAssembly = nil
        sourceURL = url
        await setProgress(.init(stage: .importing, message: url.lastPathComponent))

        let loader = BinaryLoader(registry: registry)
        let container = try await loader.loadContainer(at: url)
        let slices = container.slices
        guard !slices.isEmpty else {
            throw DecompilerError.malformedBinary("no architecture slices found")
        }
        let chosen = sliceIndex ?? slices[min(selectedSliceIndex, slices.count - 1)].index
        selectedSliceIndex = chosen

        await setProgress(.init(stage: .parsing, message: "Parsing \(slices.first { $0.index == chosen }?.name ?? "slice")"))
        let image = try await loader.parseSlice(container: container, sliceIndex: chosen, sourceURL: url)
        await store.setBinary(image)
        await store.setProgress(.init(stage: .parsing, message: "Parsed \(image.identity.format.displayName) / \(image.architecture.displayName)"))

        if configuration.autoAnalyze {
            try await runAnalysis()
        }
        return image
    }

    
    public func selectSlice(_ index: Int) async throws {
        guard let url = sourceURL else { throw DecompilerError.invalidRequest("no binary loaded") }
        _ = try await importBinary(at: url, sliceIndex: index)
    }

    
    public func availableSlices() async throws -> [SliceDescriptor] {
        guard let url = sourceURL else { return [] }
        return try await BinaryLoader(registry: registry).detectSlices(at: url)
    }

    

    
    public func runAnalysis() async throws {
        guard let image = await store.binary else {
            throw DecompilerError.invalidRequest("no binary loaded")
        }
        analysisTask?.cancel()
        let task = Task { [weak self] () async -> Void in
            guard let self else { return }
            let coordinator = AnalysisCoordinator(session: self, registry: registry)
            do {
                try await coordinator.runFullAnalysis(image: image,
                                                      configuration: await self.configuration)
            } catch is CancellationError {
            } catch {
                await self.store.addFinding(AnalysisFinding(
                    title: "Analysis failed",
                    detail: error.localizedDescription,
                    provenance: .engine))
            }
        }
        analysisTask = task
        await task.value
        analysisTask = nil
    }

    public func cancelAnalysis() {
        analysisTask?.cancel()
    }

    public var isAnalyzing: Bool { analysisTask != nil }

    

    public func binary() async -> BinaryImage? { await store.binary }
    public func functions() async -> [DecompilerFunction] { await store.functions }
    public func symbols() async -> [BinarySymbol] { await store.symbols }
    public func strings() async -> [BinaryString] { await store.stringsList }
    public func xrefs() async -> [CrossReference] { await store.crossReferences }
    public func types() async -> [TypeInfo] { await store.types }
    public func pseudocodeResults() async -> [UInt64: DecompilationResult] { await store.pseudocode }
    public func progress() async -> AnalysisProgress { await store.progress }
    public func analysisStore() -> AnalysisStore { store }

    
    public func disassembleFunction(at address: DecompilerAddress) async throws -> [Instruction] {
        guard let image = await store.binary else { throw DecompilerError.invalidRequest("no binary loaded") }
        guard let fn = await store.function(at: address.value) else {
            throw DecompilerError.invalidRequest("no function at \(address.hexString)")
        }
        let end = fn.endAddress ?? DecompilerAddress(virtual: address.value + max(fn.size, 256))
        if let dis = await registry.resolveDisassembler(for: image, preferredID: configuration.preferredDisassemblerID) {
            let instructions = try await dis.disassemble(image: image, start: address, end: end, progress: nil)
            await store.storeInstructions(instructions)
            await store.recordHistory(AnalysisHistoryEntry(operation: "disassemble", engineID: dis.id,
                                                           detail: fn.displayName))
            return instructions
        }
        throw DecompilerError.engineUnavailable("no disassembler supports \(image.format.displayName)/\(image.architecture.displayName)")
    }

    
    public func decompileFunction(
        at address: DecompilerAddress,
        force: Bool = false,
        dialect: NativeStructuralDecompiler.Dialect = .c
    ) async throws -> DecompilationResult {
        guard let image = await store.binary else { throw DecompilerError.invalidRequest("no binary loaded") }
        guard let fn = await store.function(at: address.value) else {
            throw DecompilerError.invalidRequest("no function at \(address.hexString)")
        }
        if !force, dialect == .c, let cached = await store.pseudocode(forFunctionAt: address.value) { return cached }
        guard let backend = await registry.resolveDecompiler(for: image,
                                                            required: [.decompileFunction],
                                                            preferredID: configuration.preferredDecompilerID) else {
            throw DecompilerError.engineUnavailable("no decompiler backend supports this binary")
        }
        let result: DecompilationResult
        if backend.id == NativeStructuralDecompiler.engineID {
            var ins = Array((await store.instructions).values)
            let start = fn.address.value
            let end = fn.endAddress?.value ?? (start + max(fn.size, 256))
            if !ins.contains(where: { $0.address.value >= start && $0.address.value < end }) {
                if let fresh = try? await disassembleFunction(at: address) {
                    ins.append(contentsOf: fresh)
                }
            }
            let allFns = await store.functions
            result = NativeStructuralDecompiler.decompileFunction(
                fn, instructions: ins, image: image, allFunctions: allFns, dialect: dialect
            )
        } else {
            let request = DecompilationRequest(functionAddress: address, functionName: fn.name,
                                               imagePath: image.identity.originalLocation,
                                               architecture: image.architecture, format: image.format,
                                               options: ["dialect": dialect.rawValue])
            result = try await backend.decompile(request) { p in
                Task { await self.store.setProgress(p) }
            }
        }
        await store.storePseudocode(result)
        await store.recordHistory(AnalysisHistoryEntry(operation: "decompile", engineID: backend.id,
                                                       detail: fn.displayName))
        return result
    }

    
    
    
    
    
    public func decompileAllFunctions() async throws -> [UInt64: DecompilationResult] {
        guard let image = await store.binary else {
            throw DecompilerError.invalidRequest("no binary loaded")
        }
        let maxFunctions = configuration.maxBulkDecompileFunctions
        let ordered = await store.functions
            .filter { $0.kind != .importedSymbol }
            .sorted {
                let aExported = $0.kind == .exportedSymbol
                let bExported = $1.kind == .exportedSymbol
                if aExported != bExported { return aExported }
                return $0.address.value < $1.address.value
            }
        let selected = maxFunctions > 0 ? Array(ordered.prefix(maxFunctions)) : ordered
        let requests = selected.map { fn in
            var options: [String: String] = [:]
            let end = fn.endAddress
                ?? (fn.size > 0 ? DecompilerAddress(virtual: fn.address.value + fn.size) : nil)
            if let end { options["endAddress"] = end.hexString }
            return DecompilationRequest(functionAddress: fn.address, functionName: fn.name,
                                        imagePath: image.identity.originalLocation,
                                        architecture: image.architecture, format: image.format,
                                        options: options)
        }
        guard let backend = await registry.resolveDecompiler(
            for: image, required: [.decompileBatch],
            preferredID: configuration.preferredDecompilerID) else {
            throw DecompilerError.engineUnavailable("no decompiler backend supports this binary")
        }
        let results: [DecompilationResult]
        if backend.id == NativeStructuralDecompiler.engineID {
            let allIns = Array((await store.instructions).values)
            let allFns = await store.functions
            var lifted: [DecompilationResult] = []
            lifted.reserveCapacity(selected.count)
            for (idx, fn) in selected.enumerated() {
                try Task.checkCancellation()
                await store.setProgress(AnalysisProgress(
                    stage: .decompiling,
                    fraction: Double(idx) / Double(max(selected.count, 1)),
                    message: "Lifting \(fn.displayName)",
                    itemsProcessed: idx,
                    itemsTotal: selected.count
                ))
                lifted.append(NativeStructuralDecompiler.decompileFunction(
                    fn, instructions: allIns, image: image, allFunctions: allFns
                ))
            }
            results = lifted
        } else {
            results = try await backend.decompileBatch(requests) { p in
                Task { await self.store.setProgress(p) }
            }
        }
        for result in results {
            await store.storePseudocode(result)
        }
        await store.recordHistory(AnalysisHistoryEntry(
            operation: "decompile-batch", engineID: backend.id,
            detail: "\(results.count) functions via \(backend.displayName)"))
        return await store.pseudocode
    }

    

    @discardableResult
    public func renameFunction(at address: DecompilerAddress, to name: String) async -> Bool {
        await store.renameFunction(at: address.value, to: name)
    }

    @discardableResult
    public func renameSymbol(name: String, to newName: String) async -> Bool {
        await store.renameSymbol(name: name, to: newName)
    }

    public func addComment(_ text: String, at address: DecompilerAddress) async {
        await store.setComment(text, at: address)
    }

    public func addLabel(_ name: String, at address: DecompilerAddress) async {
        await store.setUserLabel(name, at: address)
    }

    public func togglePin(_ address: DecompilerAddress) async {
        await store.togglePinned(address.value)
    }

    

    public func navigate(to address: DecompilerAddress) {
        if navigationIndex >= 0, navigationIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((navigationIndex + 1)...)
        }
        navigationHistory.append(address)
        navigationIndex = navigationHistory.count - 1
    }

    public func navigateBack() -> DecompilerAddress? {
        guard navigationIndex > 0 else { return nil }
        navigationIndex -= 1
        return navigationHistory[navigationIndex]
    }

    public func navigateForward() -> DecompilerAddress? {
        guard navigationIndex < navigationHistory.count - 1 else { return nil }
        navigationIndex += 1
        return navigationHistory[navigationIndex]
    }

    public func addBookmark(_ address: DecompilerAddress) { bookmarks.append(address) }
    public func removeBookmark(_ address: DecompilerAddress) { bookmarks.removeAll { $0 == address } }

    

    public func setMode(_ newMode: Mode) { mode = newMode }

    
    public func updateConfiguration(_ transform: (inout AnalysisConfiguration) -> Void) {
        transform(&configuration)
    }
    public func attachProject(_ p: DecompilerProject) { project = p }

    private func setProgress(_ p: AnalysisProgress) async {
        await store.setProgress(p)
    }
}
