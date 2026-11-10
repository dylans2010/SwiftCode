import Foundation

/// Exports symbol tables as CSV or JSON.
public enum SymbolExporter {
    /// CSV with a header row. Fields containing commas, quotes or
    /// newlines are quoted per RFC 4180.
    public static func exportCSV(symbols: [BinarySymbol]) -> String {
        let header = ["name", "demangled_name", "effective_name", "address",
                      "size", "kind", "library", "user_name", "provenance"]
        var lines = [header.joined(separator: ",")]
        let sorted = symbols.sorted {
            ($0.address?.value ?? UInt64.max) < ($1.address?.value ?? UInt64.max)
        }
        for s in sorted {
            let row = [
                s.name,
                s.demangledName ?? "",
                s.effectiveName,
                s.address?.hexString ?? "",
                String(s.size),
                s.kind.rawValue,
                s.library ?? "",
                s.userName ?? "",
                s.source.provenance.rawValue
            ]
            lines.append(row.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// JSON array of symbol records using the standard decompiler encoder.
    public static func exportJSON(symbols: [BinarySymbol]) throws -> Data {
        let sorted = symbols.sorted {
            ($0.address?.value ?? UInt64.max) < ($1.address?.value ?? UInt64.max)
        }
        return try JSONEncoder.decompiler.encode(sorted)
    }

    /// JSON string variant of `exportJSON`.
    public static func exportJSONText(symbols: [BinarySymbol]) throws -> String {
        let data = try exportJSON(symbols: symbols)
        return String(decoding: data, as: UTF8.self)
    }

    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
