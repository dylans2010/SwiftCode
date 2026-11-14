import Foundation



public enum DebugInformationAnalysis {
    public struct Info: Sendable {
        public var hasDWARF: Bool
        public var hasPDBReference: Bool
        public var dwarfSections: [String]
        public var pdbPath: String?
        public var summary: String
    }

    public static func inspect(image: BinaryImage, sections: [BinarySectionInfo]) -> Info {
        let dwarf = sections.map(\.name).filter { $0.contains("debug") || $0.hasPrefix(".zdebug") }
        let pdb = image.codeSignatureInfo?.contains(".pdb") == true
        let summary: String
        if !dwarf.isEmpty {
            summary = "DWARF debug sections present (\(dwarf.count))"
        } else if pdb {
            summary = "PDB reference present; PDB file itself not embedded"
        } else {
            summary = "No debug information present"
        }
        return Info(hasDWARF: !dwarf.isEmpty, hasPDBReference: pdb,
                    dwarfSections: dwarf, pdbPath: nil, summary: summary)
    }
}
