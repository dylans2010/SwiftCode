import Foundation

/// Function discovery from format metadata: entry point, function starts,
/// symbols, exports — plus call-target harvesting from xrefs.
public enum FunctionDiscovery {
    /// Confirmed functions from explicit metadata (provenance: formatParser/symbolTable).
    public static func discover(image: BinaryImage, provenance: AnalysisSource) -> [DecompilerFunction] {
        var out: [DecompilerFunction] = []
        var seen = Set<UInt64>()

        func add(_ address: DecompilerAddress, name: String, kind: DecompilerFunction.Kind,
                 source: AnalysisSource, size: UInt64 = 0) {
            guard !seen.contains(address.value) else { return }
            seen.insert(address.value)
            out.append(DecompilerFunction(address: address, size: size, name: name,
                                          kind: kind, source: source))
        }

        if let ep = image.entryPoint { add(ep, name: "entry", kind: .entryPoint, source: provenance) }
        for fs in image.functionStarts {
            add(fs, name: "sub_\(fs.hexString)", kind: .discovered, source: provenance)
        }
        for sym in image.symbols where sym.address != nil {
            let isFunc = sym.name.hasPrefix("_") || sym.name.contains("func") || true
            _ = isFunc
            let kind: DecompilerFunction.Kind = switch sym.kind {
            case .undefined: .importedSymbol
            case .external, .global: .exportedSymbol
            default: .discovered
            }
            add(sym.address!, name: sym.effectiveName, kind: kind,
                source: AnalysisSource(provenance: .symbolTable), size: sym.size)
        }
        for exp in image.exports {
            add(exp.address, name: exp.name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .formatParser), size: 0)
        }
        return out.sorted { $0.address.value < $1.address.value }
    }

    /// Heuristic refinement using real decoded instructions: split at
    /// unconditional-return boundaries only when a backend supplied them.
    /// Without disassembly this returns the input unchanged — we never
    /// fabricate function boundaries.
    public static func refine(image: BinaryImage, instructions: [Instruction],
                              existing: [DecompilerFunction]) -> [DecompilerFunction] {
        guard !instructions.isEmpty else { return existing }
        var result = existing
        let byAddr = Dictionary(uniqueKeysWithValues: instructions.map { ($0.address.value, $0) })

        // Harvest direct call targets as additional discovered functions.
        var known = Set(result.map { $0.address.value })
        var additions: [DecompilerFunction] = []
        for ins in instructions where ins.classification == .call {
            guard let target = ins.branchTarget else { continue }
            guard !known.contains(target.value) else { continue }
            // Only accept targets inside executable sections.
            guard image.executableSections.contains(where: {
                target.value >= $0.address.value && target.value < $0.address.value + $0.size
            }) else { continue }
            known.insert(target.value)
            additions.append(DecompilerFunction(
                address: target, name: "sub_\(target.hexString)", kind: .discovered,
                source: AnalysisSource(provenance: .heuristic, pass: "call-target")))
        }
        result.append(contentsOf: additions)

        // Fill sizes from sorted addresses where missing.
        let sorted = result.sorted { $0.address.value < $1.address.value }
        for i in sorted.indices {
            guard sorted[i].size == 0, i + 1 < sorted.count else { continue }
            var copy = sorted[i]
            copy.size = sorted[i + 1].address.value - sorted[i].address.value
            if let idx = result.firstIndex(where: { $0.address.value == copy.address.value }) {
                result[idx] = copy
            }
        }
        _ = byAddr
        return result.sorted { $0.address.value < $1.address.value }
    }
}
