import Foundation

public enum NativeBackendsB {
    public static func registerAll() {
        BackendRegistry.register(CSharpBackend())
        BackendRegistry.register(JavaNativeBackend())
        BackendRegistry.register(KotlinBackend())
        BackendRegistry.register(NimBackend())
        BackendRegistry.register(DBackend())
    }
}

enum LibraryBackendSupport {
    static func storedConfiguration(projectRoot: URL) -> BuildConfiguration? {
        let configURL = projectRoot.appendingPathComponent("Build/build-config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(BuildConfiguration.self, from: data) else { return nil }
        return config
    }

    static func multiArchitectureWarning(projectRoot: URL) -> AssemblyDiagnostic? {
        guard let config = storedConfiguration(projectRoot: projectRoot),
              config.architectures.count > 1 else { return nil }
        let requested = config.architectures.map(\.displayName).joined(separator: ", ")
        let built = config.architectures.first?.displayName ?? "a single architecture"
        return AssemblyDiagnostic(
            severity: .warning,
            message: "The build configuration requests multiple architectures (\(requested)), but this backend builds one architecture per invocation, so the output covers \(built) only.",
            origin: .projectConfiguration,
            suggestion: "Build once per architecture and combine the outputs with lipo -create for a universal library.")
    }

    static func sourceTexts(projectRoot: URL, extensions: Set<String>) -> [String] {
        var texts: [String] = []
        let fm = FileManager.default
        for root in ["Sources", "Assembly"] {
            let dir = projectRoot.appendingPathComponent(root, isDirectory: true)
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where extensions.contains(url.pathExtension) {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    texts.append(text)
                }
            }
        }
        return texts
    }

    static func anySourceContains(projectRoot: URL, extensions: Set<String>, marker: String) -> Bool {
        sourceTexts(projectRoot: projectRoot, extensions: extensions).contains { $0.contains(marker) }
    }

    static func parseParenthesizedDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        let pattern = #"^(.+?)\((\d+),\s*(\d+)\)\s*:?\s*(Error|Warning):\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return diagnostics }
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges == 6,
               let fileRange = Range(match.range(at: 1), in: line),
               let lineRange = Range(match.range(at: 2), in: line),
               let colRange = Range(match.range(at: 3), in: line),
               let sevRange = Range(match.range(at: 4), in: line),
               let msgRange = Range(match.range(at: 5), in: line) {
                var file = String(line[fileRange])
                if file.hasPrefix(projectRoot.path) {
                    file = String(file.dropFirst(projectRoot.path.count + 1))
                }
                diagnostics.append(AssemblyDiagnostic(
                    severity: line[sevRange] == "Error" ? .error : .warning,
                    message: String(line[msgRange]),
                    file: file,
                    line: Int(line[lineRange]),
                    column: Int(line[colRange]),
                    origin: .userCode,
                    rawText: rawLine))
                continue
            }
            if line.hasPrefix("Error:") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .linker, rawText: rawLine))
            }
        }
        return diagnostics
    }
}
