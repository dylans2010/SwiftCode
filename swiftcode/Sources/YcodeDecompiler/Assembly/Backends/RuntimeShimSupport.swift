import Foundation

public enum RuntimeShimSupport {
    public struct ScriptFunction: Sendable, Equatable {
        public var name: String
        public var arity: Int

        public init(name: String, arity: Int) {
            self.name = name
            self.arity = arity
        }
    }

    public static func scriptSources(projectRoot: URL, extensions: Set<String>) -> [URL] {
        let fm = FileManager.default
        var sources: [URL] = []
        for root in ["Sources", "Assembly"] {
            let dir = projectRoot.appendingPathComponent(root, isDirectory: true)
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where extensions.contains(url.pathExtension) {
                sources.append(url)
            }
        }
        return sources.sorted { $0.path < $1.path }
    }

    public static func shimDirectory(projectRoot: URL, backendID: String) -> URL {
        projectRoot.appendingPathComponent("Build/\(backendID)", isDirectory: true)
    }

    public static func shimURL(projectRoot: URL, backendID: String, source: URL) -> URL {
        shimDirectory(projectRoot: projectRoot, backendID: backendID)
            .appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)_shim.c")
    }

    public static func bundleURL(projectRoot: URL, backendID: String, source: URL) -> URL {
        shimDirectory(projectRoot: projectRoot, backendID: backendID)
            .appendingPathComponent(source.lastPathComponent)
    }

    public static func cIdentifier(_ name: String) -> String {
        var cleaned = name.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "_" }
        if cleaned.isEmpty { cleaned = ["_"] }
        if let first = cleaned.first, first.isNumber { cleaned.insert("_", at: cleaned.startIndex) }
        return String(cleaned)
    }

    public static func cByteArray(variableName: String, data: Data) -> String {
        var lines: [String] = []
        lines.append("static const unsigned char \(variableName)[] = {")
        var row: [String] = []
        for byte in data {
            row.append(String(format: "0x%02x,", byte))
            if row.count == 16 {
                lines.append("    " + row.joined(separator: " "))
                row = []
            }
        }
        if !row.isEmpty { lines.append("    " + row.joined(separator: " ")) }
        lines.append("    0x00")
        lines.append("};")
        lines.append("static const unsigned long \(variableName)_len = \(data.count);")
        return lines.joined(separator: "\n")
    }

    public static func cStringLiteral(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7f {
                    out += String(format: "\\x%02x", scalar.value)
                } else {
                    out += String(scalar)
                }
            }
        }
        out += "\""
        return out
    }

    public static func definitions(in script: String, pattern: String) -> [String: Int] {
        var found: [String: Int] = [:]
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return found }
        let range = NSRange(script.startIndex..., in: script)
        for match in regex.matches(in: script, range: range) {
            guard match.numberOfRanges >= 3,
                  let nameRange = Range(match.range(at: 1), in: script),
                  let paramsRange = Range(match.range(at: 2), in: script) else { continue }
            let name = String(script[nameRange])
            let params = String(script[paramsRange])
            let arity = params.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("*") }.count
            if found[name] == nil { found[name] = arity }
        }
        return found
    }

    public static func exportedFunctions(script: String, patterns: [String], exportedSymbols: [String]) -> [ScriptFunction] {
        var defs: [String: Int] = [:]
        for pattern in patterns {
            for (name, arity) in definitions(in: script, pattern: pattern) { defs[name] = arity }
        }
        return exportedSymbols.compactMap { name in defs[name].map { ScriptFunction(name: name, arity: $0) } }
    }

    public static func missingDefinitions(sources: [URL], patterns: [String], exportedSymbols: [String]) -> [String] {
        var defined: Set<String> = []
        for source in sources {
            guard let text = try? String(contentsOf: source, encoding: .utf8) else { continue }
            for pattern in patterns { defined.formUnion(definitions(in: text, pattern: pattern).keys) }
        }
        return exportedSymbols.filter { !defined.contains($0) }
    }

    public static func wrapperSignature(name: String, arity: Int) -> String {
        if arity == 0 { return "long \(name)(void)" }
        let params = (0..<arity).map { "long arg\($0)" }.joined(separator: ", ")
        return "long \(name)(\(params))"
    }

    public static func writeIfChanged(_ text: String, to url: URL) throws -> Bool {
        try writeDataIfChanged(Data(text.utf8), to: url)
    }

    public static func writeDataIfChanged(_ data: Data, to url: URL) throws -> Bool {
        if let existing = try? Data(contentsOf: url), existing == data { return false }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return true
    }

    public static func invalidateCachedObject(projectRoot: URL, source: URL) {
        let relative = source.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
        let objectName = relative.replacingOccurrences(of: "/", with: "_") + ".o"
        let objectURL = projectRoot.appendingPathComponent("Build/Objects", isDirectory: true)
            .appendingPathComponent(objectName)
        try? FileManager.default.removeItem(at: objectURL)
    }

    public static func locateClang(configuration: BuildConfiguration) -> String? {
        if let preferred = configuration.compilerPath {
            guard FileManager.default.isExecutableFile(atPath: preferred) else { return nil }
            return preferred
        }
        return ClangBackend.locateCompiler()
    }

    public static func runTool(_ path: String, arguments: [String]) -> ProcessResult? {
        try? ProcessRunnerRegistry.shared.run(executable: path, arguments: arguments,
                                              environment: nil, currentDirectory: nil)
    }

    public static func splitFlags(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    public static func bundledStatement(scriptName: String) -> String {
        "The \(scriptName) script is bundled as data inside this library and executed by the embedded runtime; it is not compiled to native code."
    }

    public static func bundledInfo(sources: [URL]) -> AssemblyDiagnostic {
        let names = sources.map(\.lastPathComponent).joined(separator: ", ")
        return AssemblyDiagnostic(
            severity: .info,
            message: bundledStatement(scriptName: names.isEmpty ? "script" : names),
            origin: .projectConfiguration)
    }

    public static func missingExportWarnings(sources: [URL], patterns: [String], exportedSymbols: [String]) -> [AssemblyDiagnostic] {
        missingDefinitions(sources: sources, patterns: patterns, exportedSymbols: exportedSymbols).map { name in
            AssemblyDiagnostic(
                severity: .warning,
                message: "Export \(name) has no matching function definition in the script sources, so no native wrapper was generated for it; the rebuilt library will not export \(name).",
                origin: .projectConfiguration,
                suggestion: "Define \(name) in one of the script sources, or remove it from exportedSymbols.")
        }
    }
}
