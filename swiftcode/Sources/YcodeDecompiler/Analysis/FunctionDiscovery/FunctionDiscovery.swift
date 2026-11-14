import Foundation



public enum FunctionDiscovery {
    
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

        
        
        
        
        let codeSections = image.segments.flatMap(\.sections).filter {
            $0.isExecutable && !isStubSection($0)
        }
        func inCode(_ address: UInt64) -> Bool {
            codeSections.contains {
                address >= $0.address.value && address < $0.address.value + $0.size
            }
        }

        if let ep = image.entryPoint { add(ep, name: "entry", kind: .entryPoint, source: provenance) }
        for fs in image.functionStarts {
            add(fs, name: "sub_\(fs.hexString)", kind: .discovered, source: provenance)
        }
        for sym in image.symbols where sym.address != nil {
            let kind: DecompilerFunction.Kind = switch sym.kind {
            case .undefined: .importedSymbol
            case .external, .global: .exportedSymbol
            default: .discovered
            }
            
            
            
            if kind != .importedSymbol, !inCode(sym.address!.value) { continue }
            add(sym.address!, name: sym.effectiveName, kind: kind,
                source: AnalysisSource(provenance: .symbolTable), size: sym.size)
        }
        for exp in image.exports where inCode(exp.address.value) {
            add(exp.address, name: exp.name, kind: .exportedSymbol,
                source: AnalysisSource(provenance: .formatParser), size: 0)
        }
        return out.sorted { $0.address.value < $1.address.value }
    }

    
    
    
    
    public static func refine(image: BinaryImage, instructions: [Instruction],
                              existing: [DecompilerFunction]) -> [DecompilerFunction] {
        guard !instructions.isEmpty else { return existing }
        var result = existing
        let byAddr = Dictionary(uniqueKeysWithValues: instructions.map { ($0.address.value, $0) })

        
        var known = Set(result.map { $0.address.value })
        var additions: [DecompilerFunction] = []
        for ins in instructions where ins.classification == .call {
            guard let target = ins.branchTarget else { continue }
            guard !known.contains(target.value) else { continue }
            
            
            
            guard image.segments.flatMap(\.sections).contains(where: {
                target.value >= $0.address.value && target.value < $0.address.value + $0.size
                    && $0.isExecutable && !isStubSection($0)
            }) else { continue }
            known.insert(target.value)
            additions.append(DecompilerFunction(
                address: target, name: "sub_\(target.hexString)", kind: .discovered,
                source: AnalysisSource(provenance: .heuristic, pass: "call-target")))
        }
        result.append(contentsOf: additions)

        
        let sorted = result.sorted { $0.address.value < $1.address.value }
        for i in sorted.indices {
            guard sorted[i].size == 0, i + 1 < sorted.count else { continue }
            var copy = sorted[i]
            copy.size = sorted[i + 1].address.value - sorted[i].address.value
            copy.endAddress = DecompilerAddress(virtual: copy.address.value + copy.size)
            if let idx = result.firstIndex(where: { $0.address.value == copy.address.value }) {
                result[idx] = copy
            }
        }
        _ = byAddr
        return result.sorted { $0.address.value < $1.address.value }
    }

    
    private static func isStubSection(_ section: BinarySectionInfo) -> Bool {
        let name = section.name.lowercased()
        return name.contains("stub") || name.contains("tramp") || name.contains("helper")
    }
}
