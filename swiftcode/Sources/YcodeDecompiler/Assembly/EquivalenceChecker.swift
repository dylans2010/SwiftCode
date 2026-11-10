import Foundation

public struct EquivalenceReport: Sendable, Codable {
    public enum Verdict: String, Sendable, Codable {
        case compatible
        case compatibleWithDifferences
        case incompatible
        case unknown
    }

    public struct SymbolDifference: Sendable, Codable {
        public enum Kind: String, Sendable, Codable { case missing, added, changed }
        public var kind: Kind
        public var name: String
        public var detail: String

        public init(kind: Kind, name: String, detail: String) {
            self.kind = kind
            self.name = name
            self.detail = detail
        }
    }

    public var buildSucceeded: Bool
    public var formatValid: Bool
    public var verdict: Verdict
    public var formatMatches: Bool
    public var architectureMatches: Bool
    public var installNameMatches: Bool
    public var exportDifferences: [SymbolDifference]
    public var importDifferences: [SymbolDifference]
    public var dependencyDifferences: [SymbolDifference]
    public var notes: [String]
    public var behavioralEquivalence: String

    public init(buildSucceeded: Bool, formatValid: Bool, verdict: Verdict,
                formatMatches: Bool, architectureMatches: Bool, installNameMatches: Bool,
                exportDifferences: [SymbolDifference] = [], importDifferences: [SymbolDifference] = [],
                dependencyDifferences: [SymbolDifference] = [], notes: [String] = [],
                behavioralEquivalence: String = "Not verified: a successful build does not prove behavioral equivalence.") {
        self.buildSucceeded = buildSucceeded
        self.formatValid = formatValid
        self.verdict = verdict
        self.formatMatches = formatMatches
        self.architectureMatches = architectureMatches
        self.installNameMatches = installNameMatches
        self.exportDifferences = exportDifferences
        self.importDifferences = importDifferences
        self.dependencyDifferences = dependencyDifferences
        self.notes = notes
        self.behavioralEquivalence = behavioralEquivalence
    }

    public var missingExports: [SymbolDifference] { exportDifferences.filter { $0.kind == .missing } }
    public var addedExports: [SymbolDifference] { exportDifferences.filter { $0.kind == .added } }

    public var isABICompatible: Bool {
        buildSucceeded && formatValid && missingExports.isEmpty
    }
}

public enum EquivalenceChecker {
    public static func compare(original: BinaryImage, rebuilt: BinaryImage,
                               buildSucceeded: Bool, formatValid: Bool) -> EquivalenceReport {
        var notes: [String] = []
        let formatMatches = original.format == rebuilt.format
        if !formatMatches {
            notes.append("Format changed: \(original.format.displayName) -> \(rebuilt.format.displayName).")
        }
        let architectureMatches = original.architecture == rebuilt.architecture
        if !architectureMatches {
            notes.append("Architecture changed: \(original.architecture.displayName) -> \(rebuilt.architecture.displayName).")
        }
        let installNameMatches: Bool
        if let originalInstall = original.installName, let rebuiltInstall = rebuilt.installName {
            installNameMatches = originalInstall == rebuiltInstall
            if !installNameMatches {
                notes.append("Install name changed: \(originalInstall) -> \(rebuiltInstall).")
            }
        } else if original.installName == nil && rebuilt.installName == nil {
            installNameMatches = true
        } else {
            installNameMatches = false
            notes.append("Install name was \(original.installName ?? "absent") in the original and \(rebuilt.installName ?? "absent") in the rebuilt library.")
        }
        let exportDiffs = diffSymbols(
            original: original.exports.map(\.name), rebuilt: rebuilt.exports.map(\.name),
            label: "export")
        let importDiffs = diffSymbols(
            original: original.imports.map(\.name), rebuilt: rebuilt.imports.map(\.name),
            label: "import")
        let dependencyDiffs = diffSymbols(
            original: original.dependencies.map(\.path), rebuilt: rebuilt.dependencies.map(\.path),
            label: "dependency")
        if original.exports.count != rebuilt.exports.count {
            notes.append("Export count changed: \(original.exports.count) -> \(rebuilt.exports.count).")
        }
        notes.append("Byte-for-byte equality is not expected: compiler version, optimization, symbol ordering, addresses, UUIDs, and code signing all change the output. Differences above are structural, not proof of behavioral change.")
        let verdict: EquivalenceReport.Verdict
        if !buildSucceeded || !formatValid {
            verdict = .unknown
        } else if exportDiffs.contains(where: { $0.kind == .missing }) || !architectureMatches || !formatMatches {
            verdict = .incompatible
        } else if exportDiffs.isEmpty && importDiffs.isEmpty && dependencyDiffs.isEmpty && installNameMatches {
            verdict = .compatible
        } else {
            verdict = .compatibleWithDifferences
        }
        return EquivalenceReport(
            buildSucceeded: buildSucceeded, formatValid: formatValid, verdict: verdict,
            formatMatches: formatMatches, architectureMatches: architectureMatches,
            installNameMatches: installNameMatches,
            exportDifferences: exportDiffs, importDifferences: importDiffs,
            dependencyDifferences: dependencyDiffs, notes: notes)
    }

    private static func diffSymbols(original: [String], rebuilt: [String],
                                    label: String) -> [EquivalenceReport.SymbolDifference] {
        let originalSet = Set(original)
        let rebuiltSet = Set(rebuilt)
        var diffs: [EquivalenceReport.SymbolDifference] = []
        for name in originalSet.subtracting(rebuiltSet).sorted() {
            diffs.append(EquivalenceReport.SymbolDifference(
                kind: .missing, name: name, detail: "\(label) present in the original but missing from the rebuilt library"))
        }
        for name in rebuiltSet.subtracting(originalSet).sorted() {
            diffs.append(EquivalenceReport.SymbolDifference(
                kind: .added, name: name, detail: "\(label) added by the rebuilt library"))
        }
        return diffs
    }
}
