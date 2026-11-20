import Foundation
import SwiftUI


public enum InspectorItem: Hashable, Sendable {
    case none
    case function
    case address
    case instruction
    case binary
}




public enum PendingCommand: Hashable, Sendable {
    case search
    case goToAddress
    case goToFunction
}


public struct ConsoleMessage: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case info, warning, error, engine }
    public var id = UUID()
    public var date: Date
    public var text: String
    public var kind: Kind

    public init(text: String, kind: Kind = .info, date: Date = Date()) {
        self.date = date
        self.text = text
        self.kind = kind
    }
}




@MainActor
@Observable
public final class DecompilerObservableState {
    public let session: DecompilerSession

    
    public private(set) var binary: BinaryImage?
    public private(set) var functions: [DecompilerFunction] = []
    public private(set) var symbols: [BinarySymbol] = []
    public private(set) var strings: [BinaryString] = []
    public private(set) var crossReferences: [CrossReference] = []
    public private(set) var types: [TypeInfo] = []
    public private(set) var pseudocode: [UInt64: DecompilationResult] = [:]
    public private(set) var progress: AnalysisProgress = .idle
    public private(set) var history: [AnalysisHistoryEntry] = []
    public private(set) var comments: [String: String] = [:]
    public private(set) var userLabels: [String: String] = [:]
    public private(set) var findings: [AnalysisFinding] = []
    public private(set) var pinnedFunctions: Set<UInt64> = []
    public private(set) var mode: DecompilerSession.Mode = .friendly
    public private(set) var slices: [SliceDescriptor] = []
    public private(set) var isAnalyzing = false

    
    
    public private(set) var disassembly: [Instruction] = []
    public private(set) var disassemblyFunctionAddress: DecompilerAddress?

    
    public var selectedFunctionAddress: DecompilerAddress?
    public var selectedAddress: DecompilerAddress?
    public var selectedInstructionRange: ClosedRange<UInt64>?
    public var inspectorItem: InspectorItem = .none

    
    public var showInspector = true
    public var showConsole = false
    public var showAssist = true
    
    
    
    public var assistPanel: AnyView?

    
    public var pendingCommand: PendingCommand?

    
    public private(set) var consoleMessages: [ConsoleMessage] = []

    
    public private(set) var engines: [EngineDescriptor] = []
    public private(set) var reconstructedProject: ReconstructedProject?
    public private(set) var lastAssembly: AssemblyResult?
    public private(set) var selectedBackendID: String?
    public private(set) var isDecompilingAsset = false
    public private(set) var isAssembling = false

    public init(session: DecompilerSession) {
        self.session = session
    }

    

    
    public func refresh() async {
        let store = session.store
        binary = await store.binary
        functions = await store.functions
        symbols = await store.symbols
        strings = await store.stringsList
        crossReferences = await store.crossReferences
        types = await store.types
        pseudocode = await store.pseudocode
        progress = await store.progress
        history = await store.history
        comments = await store.comments
        userLabels = await store.userLabels
        findings = await store.findings
        pinnedFunctions = await store.pinnedFunctions
        mode = await session.mode
        reconstructedProject = await session.reconstructedProject
        if await session.selectedBackendID == nil,
           let savedBackend = reconstructedProject?.configuration.selectedBackendID {
            await session.setSelectedBackendID(savedBackend)
        }
        selectedBackendID = await session.selectedBackendID
        lastAssembly = await session.lastAssembly
        
        
        
    }

    
    public func reloadAll() async {
        await refresh()
        slices = (try? await session.availableSlices()) ?? []
        engines = await EngineRegistry.shared.descriptors()
    }

    

    public func log(_ text: String, kind: ConsoleMessage.Kind = .info) {
        consoleMessages.append(ConsoleMessage(text: text, kind: kind))
        if consoleMessages.count > 2000 { consoleMessages.removeFirst(consoleMessages.count - 2000) }
    }

    public func clearConsole() { consoleMessages.removeAll() }

    

    @discardableResult
    public func importBinary(at url: URL) async throws -> BinaryImage {
        log("Importing \(url.lastPathComponent)…")
        return try await withLiveProgress {
            try await session.importBinary(at: url)
        } reload: { image in
            await reloadAll()
            log("Imported \(image.identity.originalFileName) (\(image.format.displayName), \(image.architecture.displayName))",
                kind: .engine)
        } onError: { error in
            await refresh()
            log("Import failed: \(error.localizedDescription)", kind: .error)
        }
    }

    
    
    
    
    private func withLiveProgress<T>(
        _ work: () async throws -> T,
        reload: (T) async -> Void,
        onError: (Error) async -> Void
    ) async throws -> T {
        isAnalyzing = true
        let poller = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
        defer {
            poller.cancel()
            isAnalyzing = false
        }
        do {
            let result = try await work()
            await reload(result)
            return result
        } catch {
            await onError(error)
            throw error
        }
    }

    public func selectSlice(_ index: Int) async throws {
        _ = try await withLiveProgress(
            { try await session.selectSlice(index) },
            reload: { _ in await reloadAll() },
            onError: { _ in await refresh() }
        )
        log("Switched architecture slice to \(index)")
    }

    
    
    public func startAnalysis() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        log("Starting analysis…")
        Task { [weak self] in
            guard let self else { return }
            defer { self.isAnalyzing = false }
            do {
                try await session.runAnalysis()
                await refresh()
                log("Analysis finished: \(progress.message)", kind: .engine)
            } catch is CancellationError {
                await refresh()
                log("Analysis cancelled", kind: .warning)
            } catch {
                await refresh()
                log("Analysis failed: \(error.localizedDescription)", kind: .error)
            }
            await refresh()
        }
        
        
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(300))
            for _ in 0..<1500 {
                await self.refresh()
                switch self.progress.stage {
                case .completed, .failed, .cancelled:
                    return
                default:
                    break
                }
                
                if !self.isAnalyzing { return }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    public func cancelAnalysis() {
        Task { await session.cancelAnalysis() }
        log("Analysis cancellation requested", kind: .warning)
    }

    public func setMode(_ newMode: DecompilerSession.Mode) async {
        await session.setMode(newMode)
        mode = newMode
        log("Switched to \(newMode == .friendly ? "Friendly" : "Master") mode")
    }

    public func setBackend(_ id: String?) async {
        await session.setSelectedBackendID(id)
        selectedBackendID = id
        if let id, let backend = BackendRegistry.backend(id: id) {
            log("Assemble backend: \(backend.displayName)")
        } else {
            log("Assemble backend: automatic (per file extension)")
        }
    }

    public func toggleMode() async {
        await setMode(mode == .friendly ? .master : .friendly)
    }

    

    @discardableResult
    public func saveProject(to url: URL? = nil) async throws -> DecompilerProject? {
        let manager = DecompilerProjectManager.shared
        if let existing = await session.project {
            let saved = try await manager.save(existing, session: session)
            await session.attachProject(saved)
            log("Saved project \(saved.manifest.name)")
            return saved
        }
        guard let url else { return nil }
        
        let name = url.deletingPathExtension().lastPathComponent
        let project = try await manager.create(name: name, session: session)
        
        
        var final = project
        if project.bundleURL.standardizedFileURL != url.standardizedFileURL {
            let fm = FileManager.default
            if fm.fileExists(atPath: url.path) { try? fm.removeItem(at: url) }
            try fm.moveItem(at: project.bundleURL, to: url)
            final = DecompilerProject(bundleURL: url, manifest: project.manifest)
            try await manager.saveManifest(final)
        }
        await session.attachProject(final)
        try await manager.save(final, session: session)
        log("Created project \(final.manifest.name) at \(final.bundleURL.path)", kind: .engine)
        return final
    }

    

    public var selectedFunction: DecompilerFunction? {
        guard let addr = selectedFunctionAddress else { return nil }
        return functions.first { $0.address.value == addr.value }
    }

    public func selectFunction(at address: DecompilerAddress?) {
        selectedFunctionAddress = address
        selectedAddress = address
        if let address { Task { await session.navigate(to: address) } }
        inspectorItem = address == nil ? .none : .function
    }

    public func selectFunction(_ function: DecompilerFunction) {
        selectFunction(at: function.address)
    }

    public func selectAddress(_ address: DecompilerAddress?, inspector: InspectorItem = .address) {
        selectedAddress = address
        inspectorItem = address == nil ? .none : inspector
        if let address { Task { await session.navigate(to: address) } }
    }

    public func navigate(to address: DecompilerAddress) {
        Task { await session.navigate(to: address) }
        selectedAddress = address
    }

    public func navigateBack() async {
        if let addr = await session.navigateBack() {
            selectedAddress = addr
            await refresh()
        }
    }

    public func navigateForward() async {
        if let addr = await session.navigateForward() {
            selectedAddress = addr
            await refresh()
        }
    }

    public func function(containing address: DecompilerAddress) -> DecompilerFunction? {
        functions.first { $0.address.value == address.value }
            ?? functions.first { f in
                guard let end = f.endAddress?.value else { return false }
                return f.address.value <= address.value && address.value < end
            }
    }

    

    
    @discardableResult
    public func loadDisassembly(for address: DecompilerAddress? = nil) async throws -> [Instruction] {
        let target = address ?? selectedFunctionAddress ?? selectedAddress
        guard let target else { throw DecompilerError.invalidRequest("no function selected") }
        let result = try await session.disassembleFunction(at: target)
        disassembly = result
        disassemblyFunctionAddress = target
        log("Disassembled \(result.count) instructions at \(target.hexString)", kind: .engine)
        return result
    }

    
    @discardableResult
    public func decompileSelected(
        force: Bool = false,
        dialect: NativeStructuralDecompiler.Dialect = .c
    ) async throws -> DecompilationResult? {
        guard let address = selectedFunctionAddress else { return nil }
        log("Decompiling \(selectedFunction?.displayName ?? address.hexString)…")
        do {
            let result = try await session.decompileFunction(at: address, force: force, dialect: dialect)
            await refresh()
            log("Decompiled \(result.functionName): \(result.pseudocode.components(separatedBy: .newlines).count) lines",
                kind: .engine)
            return result
        } catch {
            log("Decompile failed: \(error.localizedDescription)", kind: .error)
            throw error
        }
    }

    public func decompileAllFunctionsBatch() async throws {
        log("Batch decompiling all functions…")
        _ = try await session.decompileAllFunctions()
        await refresh()
        log("Decompiled \(pseudocode.count) functions", kind: .engine)
    }

    public func renameFunction(_ fn: DecompilerFunction, to newName: String) async {
        _ = await session.renameFunction(at: fn.address, to: newName)
        _ = try? await session.decompileFunction(at: fn.address, force: true)
        await refresh()
    }

    public func pseudocode(for function: DecompilerFunction) -> DecompilationResult? {
        pseudocode[function.address.value]
    }

    
    public func pseudocodeForSelection() async throws -> DecompilationResult? {
        guard let fn = selectedFunction else { return nil }
        if let cached = pseudocode[fn.address.value] { return cached }
        return try await decompileSelected()
    }

    
    
    public func decompileAsset() {
        guard !isDecompilingAsset else { return }
        guard binary != nil else {
            log("Import a binary before running Decompile Asset.", kind: .warning)
            return
        }
        isDecompilingAsset = true
        log("Decompiling asset…")
        Task { [weak self] in
            guard let self else { return }
            defer { self.isDecompilingAsset = false }
            do {
                let project = try await ReconstructionPipeline.decompileAsset(session: session)
                await refresh()
                let counts = project.source.records.reduce(into: [String: Int]()) {
                    $0[$1.quality.rawValue, default: 0] += 1
                }
                let summary = counts.sorted { $0.key < $1.key }
                    .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                log("Decompiled \(project.source.records.count) functions into \(project.rootURL.path) (\(summary))", kind: .engine)
            } catch {
                await refresh()
                log("Decompile Asset failed: \(error.localizedDescription)", kind: .error)
            }
        }
    }

    
    public func assemble() {
        guard !isAssembling else { return }
        guard reconstructedProject != nil || binary != nil else {
            log("Run Decompile Asset before Assemble.", kind: .warning)
            return
        }
        isAssembling = true
        if let id = selectedBackendID, let backend = BackendRegistry.backend(id: id) {
            log("Assembling with \(backend.displayName)…")
        } else {
            log("Assembling…")
        }
        Task { [weak self] in
            guard let self else { return }
            defer { self.isAssembling = false }
            do {
                let result = try await ReconstructionPipeline.assemble(session: session)
                await refresh()
                if result.succeeded {
                    log("Assembled \(result.outputURL.lastPathComponent) (\(result.filesCompiled.count) compiled, \(result.filesReused.count) reused)", kind: .engine)
                    if let equivalence = result.equivalence {
                        log("Equivalence: \(equivalence.verdict.rawValue), ABI compatible: \(equivalence.isABICompatible)", kind: .engine)
                    }
                } else {
                    log("Assembly failed: \(result.errors.first?.message ?? "unknown error")", kind: .error)
                    for diag in result.errors {
                        log("\(diag.displayLocation) \(diag.message)", kind: .error)
                    }
                }
            } catch {
                await refresh()
                log("Assemble failed: \(error.localizedDescription)", kind: .error)
            }
        }
    }

    
    public func openInMainEditor() {
        Task { [weak self] in
            guard let self else { return }
            var project = reconstructedProject
            if project == nil {
                project = await ReconstructionPipeline.loadReconstructedProject(session: session)
            }
            guard let project else {
                log("Run Decompile Asset first — there is no reconstructed project to open.", kind: .warning)
                return
            }
            await refresh()
            let opened = await DecompilerEditorBridge.openReconstructedProject(project)
            if opened {
                log("Opened \(project.libraryName) in the main editor.", kind: .engine)
            } else {
                log("The main editor is not available for this project. The reconstructed project is at \(project.rootURL.path).", kind: .warning)
            }
        }
    }

    
    public func openSourceLocation(for address: DecompilerAddress) {
        Task { [weak self] in
            guard let self else { return }
            guard let project = reconstructedProject else {
                log("Run Decompile Asset first.", kind: .warning)
                return
            }
            let opened = await DecompilerEditorBridge.openSourceLocation(address: address, in: project)
            if !opened {
                log("No source mapping for \(address.hexString).", kind: .warning)
            }
        }
    }

    

    public func renameSelectedFunction(to name: String) async {
        guard let addr = selectedFunctionAddress else { return }
        _ = await session.renameFunction(at: addr, to: name)
        await refresh()
        log("Renamed function to \(name)", kind: .engine)
    }

    public func addComment(_ text: String, at address: DecompilerAddress) async {
        await session.addComment(text, at: address)
        await refresh()
    }

    public func addLabel(_ name: String, at address: DecompilerAddress) async {
        await session.addLabel(name, at: address)
        await refresh()
    }

    public func togglePin(at address: DecompilerAddress) async {
        await session.togglePin(address)
        await refresh()
    }

    

    
    public func readBytes(fileOffset: UInt64, length: Int) async throws -> Data {
        guard let image = binary else { throw DecompilerError.invalidRequest("no binary loaded") }
        return try await Task.detached {
            try image.bytes(fileOffset: fileOffset, length: length)
        }.value
    }

    public func readBytes(virtualAddress: UInt64, length: Int) async throws -> Data {
        guard let image = binary else { throw DecompilerError.invalidRequest("no binary loaded") }
        return try await Task.detached {
            try image.bytes(virtualAddress: virtualAddress, length: length)
        }.value
    }

    
    public var overviewCounts: (functions: Int, symbols: Int, imports: Int, exports: Int,
                               strings: Int, sections: Int) {
        (functions.count, symbols.count, binary?.imports.count ?? 0,
         binary?.exports.count ?? 0, strings.count,
         binary?.segments.flatMap(\.sections).count ?? 0)
    }
}
