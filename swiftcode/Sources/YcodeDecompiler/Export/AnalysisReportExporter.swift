import Foundation



public enum AnalysisReportExporter {
    
    
    
    public static func export(image: BinaryImage?,
                              functions: [DecompilerFunction],
                              symbols: [BinarySymbol],
                              strings: [BinaryString],
                              crossReferences: [CrossReference],
                              types: [TypeInfo],
                              findings: [AnalysisFinding],
                              history: [AnalysisHistoryEntry],
                              engines: [EngineDescriptor] = [],
                              generatedAt: Date = Date()) -> String {
        var out = "# Decompiler Analysis Report\n\n"
        out += "Generated: \(ISO8601DateFormatter().string(from: generatedAt))\n\n"

        
        out += "## Binary\n\n"
        if let image {
            out += "| Property | Value |\n|---|---|\n"
            out += "| File | \(image.identity.originalFileName) |\n"
            out += "| Format | \(image.format.displayName) |\n"
            out += "| Architecture | \(image.architecture.displayName) |\n"
            out += "| CPU | \(image.cpuIdentifier) |\n"
            out += "| File type | \(image.fileType) |\n"
            out += "| SHA-256 | \(image.identity.sha256) |\n"
            out += "| Size | \(image.identity.fileSize) bytes |\n"
            out += "| Slice | \(image.identity.sliceIndex) (\(image.identity.sliceName)) |\n"
            if let entry = image.entryPoint {
                out += "| Entry point | \(entry.description) |\n"
            }
            if let build = image.buildVersion { out += "| Build | \(build) |\n" }
            if let minOS = image.minOSVersion { out += "| Minimum OS | \(minOS) |\n" }
            out += "| Encrypted | \(image.isEncrypted) |\n"
            out += "| Signed | \(image.isSigned) |\n"
            out += "| Debug info | \(image.hasDebugInfo) |\n"
            out += "| Segments | \(image.segments.count) |\n"
            out += "| Imports | \(image.imports.count) |\n"
            out += "| Exports | \(image.exports.count) |\n"
            out += "| Dependencies | \(image.dependencies.count) |\n\n"
        } else {
            out += "_No binary loaded._\n\n"
        }

        
        out += "## Contents\n\n"
        out += "| Entity | Count |\n|---|---|\n"
        out += "| Functions | \(functions.count) |\n"
        out += "| Symbols | \(symbols.count) |\n"
        out += "| Strings | \(strings.count) |\n"
        out += "| Cross-references | \(crossReferences.count) |\n"
        out += "| Types | \(types.count) |\n"
        out += "| Findings | \(findings.count) |\n"
        out += "| History entries | \(history.count) |\n\n"

        
        out += "## Engines\n\n"
        var usedIDs = Set(history.compactMap(\.engineID))
        for e in engines { usedIDs.insert(e.id) }
        if usedIDs.isEmpty {
            out += "_No analysis engines were used._\n\n"
        } else {
            let byID = Dictionary(uniqueKeysWithValues: engines.map { ($0.id, $0) })
            out += "| Engine | Kind | Version | Available |\n|---|---|---|---|\n"
            for id in usedIDs.sorted() {
                if let d = byID[id] {
                    out += "| \(d.displayName) (\(d.id)) | \(d.kind.rawValue) | \(d.version ?? "-") | \(d.isAvailable) |\n"
                } else {
                    out += "| \(id) | - | - | - |\n"
                }
            }
            out += "\n"
        }

        
        out += "## Findings\n\n"
        if findings.isEmpty {
            out += "_No findings recorded._\n\n"
        } else {
            for f in findings.sorted(by: { $0.createdAt < $1.createdAt }) {
                let confirmed = f.userConfirmed ? "confirmed" : "unconfirmed"
                out += "### \(f.title)\n\n"
                out += "- Provenance: \(f.provenance.rawValue) (\(confirmed))\n"
                if let addr = f.address { out += "- Address: \(addr.description)\n" }
                if let fnAddr = f.functionAddress { out += "- Function: \(fnAddr.description)\n" }
                out += "- Detail: \(f.detail)\n\n"
            }
        }

        
        out += "## Analysis History\n\n"
        if history.isEmpty {
            out += "_No analysis operations recorded._\n"
        } else {
            out += "| Date | Operation | Engine | Detail | Status |\n|---|---|---|---|---|\n"
            let formatter = ISO8601DateFormatter()
            for h in history.sorted(by: { $0.date < $1.date }) {
                out += "| \(formatter.string(from: h.date)) | \(h.operation) | \(h.engineID ?? "-") | \(h.detail) | \(h.succeeded ? "ok" : "failed") |\n"
            }
        }
        out += "\n"
        return out
    }
}
