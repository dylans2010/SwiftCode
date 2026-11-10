import Foundation

public struct AssemblyDiagnostic: Sendable, Codable {
    public enum Severity: String, Sendable, Codable { case error, warning, note, info }
    public enum Origin: String, Sendable, Codable {
        case recoveredCode
        case userCode
        case projectConfiguration
        case linker
        case unknown
    }

    public var severity: Severity
    public var message: String
    public var file: String?
    public var line: Int?
    public var column: Int?
    public var symbol: String?
    public var origin: Origin
    public var suggestion: String?
    public var rawText: String

    public init(severity: Severity, message: String, file: String? = nil, line: Int? = nil,
                column: Int? = nil, symbol: String? = nil, origin: Origin = .unknown,
                suggestion: String? = nil, rawText: String = "") {
        self.severity = severity
        self.message = message
        self.file = file
        self.line = line
        self.column = column
        self.symbol = symbol
        self.origin = origin
        self.suggestion = suggestion
        self.rawText = rawText
    }

    public var displayLocation: String {
        guard let file else { return "" }
        if let line {
            return "\(file):\(line)" + (column.map { ":\($0)" } ?? "")
        }
        return file
    }
}

public enum AssemblyDiagnosticParser {
    public static func parseCompilerOutput(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let diag = parseClangLine(line, projectRoot: projectRoot) {
                diagnostics.append(diag)
                continue
            }
            if line.contains("error:") || line.contains("warning:") {
                let severity: AssemblyDiagnostic.Severity = line.contains("error:") ? .error : .warning
                diagnostics.append(AssemblyDiagnostic(severity: severity, message: line,
                                                      origin: .linker, rawText: rawLine))
            }
        }
        return diagnostics
    }

    public static func parseClangLine(_ line: String, projectRoot: URL) -> AssemblyDiagnostic? {
        let pattern = #"^(.+?):(\d+):(\d+):\s+(error|warning|note|fatal error):\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 6,
              let fileRange = Range(match.range(at: 1), in: line),
              let lineRange = Range(match.range(at: 2), in: line),
              let colRange = Range(match.range(at: 3), in: line),
              let sevRange = Range(match.range(at: 4), in: line),
              let msgRange = Range(match.range(at: 5), in: line) else { return nil }
        let filePath = String(line[fileRange])
        let severityText = String(line[sevRange])
        let severity: AssemblyDiagnostic.Severity
        switch severityText {
        case "error", "fatal error": severity = .error
        case "warning": severity = .warning
        case "note": severity = .note
        default: severity = .info
        }
        let relativeFile = filePath.hasPrefix(projectRoot.path)
            ? String(filePath.dropFirst(projectRoot.path.count + 1)) : filePath
        let origin = originForFile(relativeFile)
        return AssemblyDiagnostic(
            severity: severity,
            message: String(line[msgRange]),
            file: relativeFile,
            line: Int(line[lineRange]),
            column: Int(line[colRange]),
            origin: origin,
            suggestion: suggestionFor(message: String(line[msgRange]), file: relativeFile),
            rawText: line)
    }

    public static func originForFile(_ relativePath: String) -> AssemblyDiagnostic.Origin {
        if relativePath.hasPrefix("Sources/reconstructed") || relativePath.hasPrefix("Headers/") {
            return .recoveredCode
        }
        if relativePath.hasPrefix("Sources/") || relativePath.hasPrefix("Assembly/") {
            return .userCode
        }
        return .projectConfiguration
    }

    public static func parseLinkerOutput(_ text: String) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.contains("undefined symbol") || line.contains("undefined reference") {
                let symbol = extractQuotedSymbol(line)
                diagnostics.append(AssemblyDiagnostic(
                    severity: .error,
                    message: line,
                    symbol: symbol,
                    origin: .linker,
                    suggestion: symbol.map {
                        "Undefined symbol '\($0)'. If it is an imported function, check that its library is listed in the build configuration dependencies; if it is a reconstructed function, check that its definition was generated."
                    },
                    rawText: rawLine))
            } else if line.contains("duplicate symbol") {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .error,
                    message: line,
                    origin: .linker,
                    suggestion: "A symbol is defined more than once — usually a function defined in both a C source and the assembly fallback. Remove one definition.",
                    rawText: rawLine))
            } else if line.contains("error") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .linker, rawText: rawLine))
            }
        }
        return diagnostics
    }

    private static func extractQuotedSymbol(_ line: String) -> String? {
        if let start = line.firstIndex(of: "\""),
           let end = line[line.index(after: start)...].firstIndex(of: "\"") {
            return String(line[line.index(after: start)..<end])
        }
        if let start = line.firstIndex(of: "'"),
           let end = line[line.index(after: start)...].firstIndex(of: "'") {
            return String(line[line.index(after: start)..<end])
        }
        return nil
    }

    private static func suggestionFor(message: String, file: String) -> String? {
        if message.contains("use of undeclared identifier") {
            return "The identifier is not declared. If it is a Ghidra pseudocode artifact (FUN_, DAT_, or a helper like CONCAT), the reconstruction did not map it — check the reconstruction report or add a declaration in Headers/."
        }
        if message.contains("expected") && file.hasSuffix(".c") {
            return "The reconstructed C has a syntax problem at this line. Edit the generated source in the main editor; the mapping file records the original address."
        }
        if message.contains("implicit declaration") {
            return "Add the missing declaration to Headers/ or include the right system header."
        }
        return nil
    }
}
