import Foundation

/// Lightweight Swift source helpers (brace matching, member extraction) used by
/// the expansion toolkit's code-generation tools. They operate on real files.
public extension AssistToolKit {

    struct StoredProperty: Sendable {
        public let name: String
        public let type: String
        public let isLet: Bool
        public let defaultValue: String?
    }

    /// Returns the declaration line and body text (inside the outer braces) of the
    /// first struct/class/actor/enum/protocol/extension named `name`.
    static func typeBody(in source: String, named name: String) -> (kind: String, header: String, body: String)? {
        let pattern = #"\b(struct|class|actor|enum|protocol|extension)\s+"# + NSRegularExpression.escapedPattern(for: name) + #"\b[^{]*\{"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let whole = Range(m.range, in: source), let kindR = Range(m.range(at: 1), in: source) else { return nil }
        var depth = 1
        var idx = whole.upperBound
        let bodyStart = idx
        while idx < source.endIndex {
            let c = source[idx]
            if c == "{" { depth += 1 } else if c == "}" { depth -= 1; if depth == 0 { break } }
            idx = source.index(after: idx)
        }
        return (String(source[kindR]), String(source[whole]).replacingOccurrences(of: "{", with: "").trimmingCharacters(in: .whitespacesAndNewlines), String(source[bodyStart..<idx]))
    }

    /// Top-level (depth-0) lines of a type body.
    static func topLevelLines(of body: String) -> [String] {
        var out: [String] = []
        var depth = 0
        for line in body.components(separatedBy: .newlines) {
            if depth == 0 { out.append(line) }
            for c in line { if c == "{" { depth += 1 } else if c == "}" { depth = max(0, depth - 1) } }
        }
        return out
    }

    /// Stored (non-computed, non-static) properties declared at the top level of a type body.
    static func storedProperties(of body: String) -> [StoredProperty] {
        let re = try? NSRegularExpression(pattern: #"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|private|fileprivate|internal|package|open|final|nonisolated|weak|unowned|lazy)(?:\(set\))?\s+)*(let|var)\s+([A-Za-z_]\w*)\s*(?::\s*([^={]+?))?\s*(?:=\s*(.+?))?\s*(\{)?\s*$"#)
        var props: [StoredProperty] = []
        for line in topLevelLines(of: body) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("static ") || t.hasPrefix("class ") || t.contains(" static ") || t.hasPrefix("//") { continue }
            let ns = line as NSString
            guard let re, let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
            if m.range(at: 5).location != NSNotFound { continue } // computed property / observer block
            let kind = ns.substring(with: m.range(at: 1))
            let name = ns.substring(with: m.range(at: 2))
            let type = m.range(at: 3).location != NSNotFound ? ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespaces) : ""
            let def = m.range(at: 4).location != NSNotFound ? ns.substring(with: m.range(at: 4)).trimmingCharacters(in: .whitespaces) : nil
            props.append(StoredProperty(name: name, type: type, isLet: kind == "let", defaultValue: def))
        }
        return props
    }

    /// Function signatures (without bodies) declared at the top level of a type body.
    static func functionSignatures(of body: String) -> [String] {
        topLevelLines(of: body).compactMap { line -> String? in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.range(of: #"^((@\w+(\([^)]*\))?\s+)*(public|private|fileprivate|internal|package|open|final|static|override|mutating|nonisolated|class)\s+)*func\s"#, options: .regularExpression) != nil else { return nil }
            var sig = t
            if let brace = sig.firstIndex(of: "{") { sig = String(sig[..<brace]) }
            return sig.trimmingCharacters(in: .whitespaces)
        }
    }

    /// Loads a Swift file and locates `type_name` in it. Returns a failure result when not found.
    static func loadType(_ input: [String: Any], context: AssistContext) -> Result<(path: String, kind: String, header: String, body: String), AssistToolKitError> {
        guard let raw = string(input, "path") else { return .failure(.init("Missing required parameter: path")) }
        guard let typeName = string(input, "type_name"), !typeName.isEmpty else { return .failure(.init("Missing required parameter: type_name")) }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return .failure(.init("Path must be inside the workspace.")) }
        var candidates = files(at: url, extensions: ["swift"])
        if candidates.isEmpty { return .failure(.init("No Swift files at \(raw).")) }
        candidates.sort { $0.path < $1.path }
        for f in candidates {
            guard let src = read(f), let t = typeBody(in: src, named: typeName), t.kind != "extension" else { continue }
            return .success((relative(f, context), t.kind, t.header, t.body))
        }
        return .failure(.init("Type '\(typeName)' was not found under \(raw)."))
    }
}

public struct AssistToolKitError: Error, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}
