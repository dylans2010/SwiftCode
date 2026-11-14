import Foundation




public actor AnalysisStore {
    public private(set) var binary: BinaryImage?
    public private(set) var progress = AnalysisProgress.idle
    public private(set) var functions: [DecompilerFunction] = []
    public private(set) var symbols: [BinarySymbol] = []
    public private(set) var stringsList: [BinaryString] = []
    public private(set) var crossReferences: [CrossReference] = []
    public private(set) var types: [TypeInfo] = []
    
    public private(set) var instructions: [UInt64: Instruction] = [:]
    
    public private(set) var pseudocode: [UInt64: DecompilationResult] = [:]
    
    public private(set) var comments: [String: String] = [:]
    
    public private(set) var userLabels: [String: String] = [:]
    
    public private(set) var findings: [AnalysisFinding] = []
    
    public private(set) var history: [AnalysisHistoryEntry] = []
    
    public private(set) var pinnedFunctions: Set<UInt64> = []

    public init() {}

    

    public func setBinary(_ image: BinaryImage?) { binary = image }

    public func setProgress(_ p: AnalysisProgress) { progress = p }

    public func upsertFunctions(_ fns: [DecompilerFunction]) {
        var byAddr = Dictionary(uniqueKeysWithValues: functions.map { ($0.address.value, $0) })
        for f in fns { byAddr[f.address.value] = f }
        functions = byAddr.values.sorted { $0.address.value < $1.address.value }
    }

    public func function(at address: UInt64) -> DecompilerFunction? {
        functions.first { $0.address.value == address }
    }

    
    public func function(atOrContaining address: UInt64) -> DecompilerFunction? {
        function(containing: address)
    }

    
    public func function(containing address: UInt64) -> DecompilerFunction? {
        if let exact = function(at: address) { return exact }
        var best: DecompilerFunction?
        for f in functions where f.address.value <= address {
            if let end = f.endAddress?.value, address < end { return f }
            if best == nil || f.address.value > best!.address.value { best = f }
        }
        if let best, let next = functions.first(where: { $0.address.value > best.address.value }) {
            if address < next.address.value { return best }
        }
        return nil
    }

    public func upsertSymbols(_ syms: [BinarySymbol]) {
        var byKey = Dictionary(uniqueKeysWithValues: symbols.map { (symbolKey($0), $0) })
        for s in syms { byKey[symbolKey(s)] = s }
        symbols = byKey.values.sorted {
            ($0.address?.value ?? UInt64.max) < ($1.address?.value ?? UInt64.max)
        }
    }

    private func symbolKey(_ s: BinarySymbol) -> String {
        "\(s.address?.hexString ?? "-")|\(s.name)"
    }

    public func setStrings(_ list: [BinaryString]) { stringsList = list }

    public func addCrossReferences(_ refs: [CrossReference]) {
        var seen = Set(crossReferences.map(\.id))
        for r in refs where !seen.contains(r.id) {
            crossReferences.append(r); seen.insert(r.id)
        }
    }

    public func upsertTypes(_ t: [TypeInfo]) {
        var byID = Dictionary(uniqueKeysWithValues: types.map { ($0.id, $0) })
        for type in t { byID[type.id] = type }
        types = byID.values.sorted { $0.name < $1.name }
    }

    public func storeInstructions(_ list: [Instruction]) {
        for i in list { instructions[i.address.value] = i }
    }

    public func instruction(at address: UInt64) -> Instruction? { instructions[address] }

    public func instructions(inRange range: ClosedRange<UInt64>) -> [Instruction] {
        instructions.values.filter { range.contains($0.address.value) }.sorted { $0.address.value < $1.address.value }
    }

    public func storePseudocode(_ result: DecompilationResult) {
        pseudocode[result.functionAddress.value] = result
        if var f = function(at: result.functionAddress.value) {
            f.hasPseudocode = true
            upsertFunctions([f])
        }
    }

    public func pseudocode(forFunctionAt address: UInt64) -> DecompilationResult? {
        pseudocode[address]
    }

    public func setComment(_ text: String, at address: DecompilerAddress) {
        comments[address.hexString] = text
    }

    public func comment(at address: DecompilerAddress) -> String? { comments[address.hexString] }

    
    @discardableResult
    public func renameFunction(at address: UInt64, to newName: String) -> Bool {
        guard var f = function(at: address) else { return false }
        f.name = newName
        upsertFunctions([f])
        if let idx = symbols.firstIndex(where: { $0.address?.value == address }) {
            var s = symbols[idx]; s.userName = newName; upsertSymbols([s])
        }
        return true
    }

    public func renameSymbol(name: String, to newName: String) -> Bool {
        guard let s = symbols.first(where: { $0.name == name || $0.effectiveName == name }) else { return false }
        var copy = s; copy.userName = newName
        upsertSymbols([copy])
        return true
    }

    public func setUserLabel(_ name: String, at address: DecompilerAddress) {
        userLabels[address.hexString] = name
    }

    public func addFinding(_ finding: AnalysisFinding) {
        findings.removeAll { $0.id == finding.id }
        findings.append(finding)
    }

    public func togglePinned(_ address: UInt64) {
        if pinnedFunctions.contains(address) { pinnedFunctions.remove(address) }
        else { pinnedFunctions.insert(address) }
        if var f = function(at: address) {
            f.isPinned = pinnedFunctions.contains(address)
            upsertFunctions([f])
        }
    }

    public func recordHistory(_ entry: AnalysisHistoryEntry) {
        history.append(entry)
    }

    
    public var overviewCounts: (functions: Int, symbols: Int, imports: Int, exports: Int,
                                strings: Int, sections: Int) {
        (functions.count, symbols.count, binary?.imports.count ?? 0,
         binary?.exports.count ?? 0, stringsList.count,
         binary?.segments.flatMap(\.sections).count ?? 0)
    }
}

public struct AnalysisFinding: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var title: String
    public var detail: String
    public var address: DecompilerAddress?
    public var functionAddress: DecompilerAddress?
    
    public var userConfirmed: Bool
    public var provenance: AnalysisProvenance
    public var createdAt: Date

    public init(id: String = UUID().uuidString, title: String, detail: String,
                address: DecompilerAddress? = nil, functionAddress: DecompilerAddress? = nil,
                userConfirmed: Bool = false, provenance: AnalysisProvenance, createdAt: Date = Date()) {
        self.id = id; self.title = title; self.detail = detail
        self.address = address; self.functionAddress = functionAddress
        self.userConfirmed = userConfirmed; self.provenance = provenance; self.createdAt = createdAt
    }
}

public struct AnalysisHistoryEntry: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var date: Date
    public var operation: String
    public var engineID: String?
    public var detail: String
    public var succeeded: Bool

    public init(operation: String, engineID: String? = nil, detail: String = "", succeeded: Bool = true) {
        self.id = UUID().uuidString
        self.date = Date()
        self.operation = operation
        self.engineID = engineID
        self.detail = detail
        self.succeeded = succeeded
    }
}
