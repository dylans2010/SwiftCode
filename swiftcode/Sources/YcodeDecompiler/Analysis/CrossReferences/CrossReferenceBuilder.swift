import Foundation



public enum CrossReferenceBuilder {
    public static func build(instructions: [Instruction], image: BinaryImage) -> [CrossReference] {
        let provenance = AnalysisSource(provenance: .engine, pass: "xrefs")
        var out: [CrossReference] = []
        var stringAddrs = Set(image.strings.map { $0.address.value })

        for ins in instructions {
            switch ins.classification {
            case .call:
                if let t = ins.branchTarget {
                    out.append(CrossReference(source: ins.address, destination: t, kind: .call,
                                               provenance: provenance))
                }
            case .branch:
                if let t = ins.branchTarget {
                    out.append(CrossReference(source: ins.address, destination: t, kind: .jump,
                                               provenance: provenance))
                }
            case .normal, .returnInstruction, .invalid, .unknown, .data:
                
                for op in ins.operands {
                    if case .address(let dest) = op,
                       image.fileOffset(forVirtualAddress: dest.value) != nil {
                        let kind: CrossReference.Kind = stringAddrs.contains(dest.value) ? .string : .data
                        out.append(CrossReference(source: ins.address, destination: dest, kind: kind,
                                                   provenance: provenance))
                    }
                }
            }
        }
        stringAddrs.removeAll()
        return out
    }
}
