import Foundation
import Crypto

/// Shared, side-effect-scoped helpers used by the expansion toolkit tools.
/// Every helper operates on real workspace data, real process output, or the
/// caller-supplied input; nothing here fabricates results.
public enum AssistToolKit {

    // MARK: - Input helpers

    public static func string(_ input: [String: Any], _ key: String) -> String? {
        if let s = input[key] as? String { return s }
        if let n = input[key] as? NSNumber { return n.stringValue }
        return nil
    }

    public static func int(_ input: [String: Any], _ key: String, default value: Int) -> Int {
        if let i = input[key] as? Int { return i }
        if let d = input[key] as? Double { return Int(d) }
        if let s = input[key] as? String, let i = Int(s.trimmingCharacters(in: .whitespaces)) { return i }
        return value
    }

    public static func bool(_ input: [String: Any], _ key: String, default value: Bool) -> Bool {
        if let b = input[key] as? Bool { return b }
        if let s = input[key] as? String { return ["true", "yes", "1"].contains(s.lowercased()) }
        if let n = input[key] as? NSNumber { return n.boolValue }
        return value
    }

    public static func stringArray(_ input: [String: Any], _ key: String) -> [String] {
        if let a = input[key] as? [String] { return a }
        if let a = input[key] as? [Any] { return a.compactMap { $0 as? String } }
        if let s = input[key] as? String {
            return s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        return []
    }

    public static func missing(_ key: String) -> AssistToolResult {
        var r = AssistToolResult.failure("Missing required parameter: \(key)")
        r.toolErrorCode = .missingArgument
        return r
    }

    public static func invalid(_ message: String) -> AssistToolResult {
        var r = AssistToolResult.failure(message)
        r.toolErrorCode = .invalidInput
        return r
    }

    public static func notFound(_ message: String) -> AssistToolResult {
        var r = AssistToolResult.failure(message)
        r.toolErrorCode = .notFound
        return r
    }

    /// Resolves an optional workspace-relative path (default: workspace root) and
    /// guarantees it stays inside the workspace.
    public static func resolve(_ input: [String: Any], key: String = "path", context: AssistContext, defaultPath: String = ".") -> URL? {
        let raw = (string(input, key) ?? defaultPath).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "." { return context.workspaceRoot.standardized }
        return AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot)
    }

    public static func relative(_ url: URL, _ context: AssistContext) -> String {
        AssistWorkspacePaths.relative(url, workspaceRoot: context.workspaceRoot)
    }

    public static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Files under `url` (or `url` itself when it is a file), filtered by extension.
    public static func files(at url: URL, extensions: Set<String>?, maxFiles: Int = 20000) -> [URL] {
        if isDirectory(url) {
            return AssistWorkspaceScan.files(under: url, extensions: extensions, maxFiles: maxFiles)
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        if let exts = extensions, !exts.contains(url.pathExtension.lowercased()) { return [] }
        return [url]
    }

    public static func read(_ url: URL) -> String? {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        if let d = try? Data(contentsOf: url) { return String(decoding: d, as: UTF8.self) }
        return nil
    }

    public static func output(_ text: String, limit: Int = 20_000) -> String {
        AssistTextFormat.truncated(text, limit: limit).0
    }

    // MARK: - Pattern scanning

    public struct Match: Sendable {
        public let file: String
        public let line: Int
        public let text: String
    }

    /// Scans files line-by-line for a regular expression. Comment-only lines are
    /// skipped when `skipComments` is true.
    public static func scan(
        root: URL,
        pattern: String,
        extensions: Set<String>? = ["swift"],
        skipComments: Bool = true,
        caseInsensitive: Bool = false,
        maxResults: Int = 400,
        context: AssistContext
    ) throws -> (matches: [Match], filesScanned: Int) {
        let regex = try NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
        var matches: [Match] = []
        let targets = files(at: root, extensions: extensions)
        for file in targets {
            guard let content = read(file) else { continue }
            let rel = relative(file, context)
            var inBlockComment = false
            for (idx, line) in content.components(separatedBy: .newlines).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if skipComments {
                    if inBlockComment {
                        if trimmed.contains("*/") { inBlockComment = false }
                        continue
                    }
                    if trimmed.hasPrefix("/*") {
                        if !trimmed.contains("*/") { inBlockComment = true }
                        continue
                    }
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") && extensions?.contains("swift") == false { continue }
                }
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    matches.append(Match(file: rel, line: idx + 1, text: String(trimmed.prefix(200))))
                    if matches.count >= maxResults { return (matches, targets.count) }
                }
            }
        }
        return (matches, targets.count)
    }

    public static func scanResult(
        title: String,
        guidance: String,
        input: [String: Any],
        context: AssistContext,
        pattern: String,
        extensions: Set<String>? = ["swift"],
        skipComments: Bool = true,
        caseInsensitive: Bool = false
    ) -> AssistToolResult {
        guard let root = resolve(input, context: context) else {
            return invalid("Path must be inside the workspace.")
        }
        guard FileManager.default.fileExists(atPath: root.path) else {
            return notFound("Path not found: \(string(input, "path") ?? ".")")
        }
        let limit = max(1, min(int(input, "max_results", default: 200), 2000))
        do {
            let (matches, scanned) = try scan(root: root, pattern: pattern, extensions: extensions,
                                              skipComments: skipComments, caseInsensitive: caseInsensitive,
                                              maxResults: limit, context: context)
            var lines = ["## \(title)", "Scanned \(scanned) file(s) under `\(relative(root, context))`. Findings: \(matches.count)\(matches.count >= limit ? " (limit reached)" : "")."]
            if matches.isEmpty {
                lines.append("No occurrences found.")
            } else {
                var byFile: [String: Int] = [:]
                for m in matches { byFile[m.file, default: 0] += 1 }
                lines.append("Files affected: \(byFile.count)")
                lines.append("")
                for m in matches { lines.append("- \(m.file):\(m.line): \(m.text)") }
                lines.append("")
                lines.append("Guidance: \(guidance)")
            }
            return .success(output(lines.joined(separator: "\n")),
                            data: ["count": String(matches.count), "filesScanned": String(scanned)])
        } catch {
            return invalid("Invalid pattern: \(error.localizedDescription)")
        }
    }

    // MARK: - Text transforms

    public static func textInput(_ input: [String: Any], key: String = "text") -> String? {
        string(input, key) ?? string(input, "input") ?? string(input, "content")
    }

    public static func words(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, c) in chars.enumerated() {
            if c.isLetter || c.isNumber {
                if c.isUppercase, !current.isEmpty {
                    let prev = chars[i - 1]
                    let nextIsLower = i + 1 < chars.count && chars[i + 1].isLowercase
                    if prev.isLowercase || prev.isNumber || (prev.isUppercase && nextIsLower) {
                        parts.append(current)
                        current = ""
                    }
                }
                current.append(c)
            } else if !current.isEmpty {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    public static func hex(_ data: some Sequence<UInt8>) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    public static func digest(_ data: Data, algorithm: String) -> String? {
        switch algorithm.lowercased() {
        case "sha256": return hex(SHA256.hash(data: data))
        case "sha384": return hex(SHA384.hash(data: data))
        case "sha512": return hex(SHA512.hash(data: data))
        case "sha1": return hex(Insecure.SHA1.hash(data: data))
        case "md5": return hex(Insecure.MD5.hash(data: data))
        default: return nil
        }
    }

    public static func prettyJSON(_ object: Any, sorted: Bool = true) -> String? {
        var opts: JSONSerialization.WritingOptions = [.prettyPrinted, .fragmentsAllowed, .withoutEscapingSlashes]
        if sorted { opts.insert(.sortedKeys) }
        guard let d = try? JSONSerialization.data(withJSONObject: object, options: opts) else { return nil }
        return String(decoding: d, as: UTF8.self)
    }

    public static func parseJSON(_ text: String) -> Any? {
        try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
    }

    // MARK: - Process execution (fixed argv, no shell)

    public static func which(_ tool: String) -> URL? {
        let fm = FileManager.default
        if tool.hasPrefix("/") { return fm.isExecutableFile(atPath: tool) ? URL(fileURLWithPath: tool) : nil }
        var dirs = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        dirs.append(contentsOf: ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/usr/local/bin", "/opt/homebrew/bin"])
        for d in dirs {
            let p = (d as NSString).appendingPathComponent(tool)
            if fm.isExecutableFile(atPath: p) { return URL(fileURLWithPath: p) }
        }
        return nil
    }

    public static func run(_ tool: String, _ arguments: [String], cwd: URL, timeout: TimeInterval = 120) -> (ok: Bool, exitCode: Int32, output: String, error: String?) {
        guard let exe = which(tool) else {
            return (false, -1, "", "Executable '\(tool)' was not found on this machine.")
        }
        do {
            let r = try AssistArgvRunner.run(executableURL: exe, arguments: arguments, workingDirectory: cwd, timeout: timeout)
            if r.timedOut { return (false, r.exitCode, r.output, "Timed out after \(Int(timeout))s.") }
            return (r.exitCode == 0, r.exitCode, r.output, nil)
        } catch {
            return (false, -1, "", error.localizedDescription)
        }
    }

    public static func processResult(_ title: String, _ tool: String, _ arguments: [String], cwd: URL, timeout: TimeInterval = 120, allowNonZero: Bool = false) -> AssistToolResult {
        let r = run(tool, arguments, cwd: cwd, timeout: timeout)
        let commandLine = ([tool] + arguments).joined(separator: " ")
        if let err = r.error {
            var f = AssistToolResult.failure("\(title) failed: \(err)")
            f.toolErrorCode = err.contains("not found") ? .unsupportedOperation : (err.contains("Timed out") ? .timeout : .executionFailed)
            return f
        }
        let body = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !r.ok && !allowNonZero {
            var f = AssistToolResult.failure("\(title) exited with status \(r.exitCode).\n$ \(commandLine)\n\(output(body, limit: 8000))")
            f.toolErrorCode = .executionFailed
            return f
        }
        return .success("## \(title)\n$ \(commandLine)\n\n\(output(body.isEmpty ? "(no output)" : body))",
                        data: ["exitCode": String(r.exitCode)])
    }

    // MARK: - Network

    public static func httpRequest(url: URL, method: String, headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval = 30) async -> (status: Int, headers: [String: String], body: Data, error: String?) {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let http = response as? HTTPURLResponse
            var h: [String: String] = [:]
            for (k, v) in http?.allHeaderFields ?? [:] { h["\(k)"] = "\(v)" }
            return (http?.statusCode ?? 0, h, data, nil)
        } catch {
            return (0, [:], Data(), error.localizedDescription)
        }
    }

    public static func validatedURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    // MARK: - Swift declarations

    public struct Declaration: Sendable {
        public let kind: String
        public let name: String
        public let file: String
        public let line: Int
        public let signature: String
    }

    public static func declarations(in root: URL, kinds: Set<String>, context: AssistContext, maxResults: Int = 2000) -> [Declaration] {
        let pattern = #"^\s*(?:@[\w().:, "]+\s+)*(?:(?:public|private|fileprivate|internal|open|package|final|static|class|override|mutating|nonmutating|nonisolated|indirect|convenience|required|lazy|weak|unowned|dynamic|async|distributed)\s+)*(struct|class|enum|protocol|actor|extension|func|init|var|let|typealias|case|macro)\b\s*([A-Za-z_][\w.]*)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var out: [Declaration] = []
        for file in files(at: root, extensions: ["swift"]) {
            guard let content = read(file) else { continue }
            let rel = relative(file, context)
            for (i, line) in content.components(separatedBy: .newlines).enumerated() {
                let ns = line as NSString
                guard let m = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
                let kind = ns.substring(with: m.range(at: 1))
                guard kinds.contains(kind) else { continue }
                let name = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : kind
                out.append(Declaration(kind: kind, name: name, file: rel, line: i + 1,
                                       signature: String(line.trimmingCharacters(in: .whitespaces).prefix(180))))
                if out.count >= maxResults { return out }
            }
        }
        return out
    }

    public static func declarationResult(title: String, input: [String: Any], context: AssistContext, kinds: Set<String>, filter: ((Declaration) -> Bool)? = nil) -> AssistToolResult {
        guard let root = resolve(input, context: context) else { return invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return notFound("Path not found: \(string(input, "path") ?? ".")") }
        let nameFilter = string(input, "name_contains")?.lowercased()
        var decls = declarations(in: root, kinds: kinds, context: context)
        if let filter { decls = decls.filter(filter) }
        if let nameFilter, !nameFilter.isEmpty { decls = decls.filter { $0.name.lowercased().contains(nameFilter) } }
        let limit = max(1, min(int(input, "max_results", default: 300), 2000))
        let shown = decls.prefix(limit)
        var lines = ["## \(title)", "Found \(decls.count) declaration(s) under `\(relative(root, context))`."]
        for d in shown { lines.append("- [\(d.kind)] \(d.name) — \(d.file):\(d.line) — `\(d.signature)`") }
        if decls.count > shown.count { lines.append("… \(decls.count - shown.count) more (raise max_results).") }
        return .success(output(lines.joined(separator: "\n")), data: ["count": String(decls.count)])
    }

    // MARK: - Writing

    public static func writeVerified(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        guard read(url) == text else {
            throw NSError(domain: "AssistToolKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Write verification failed for \(url.lastPathComponent)"])
        }
    }

    /// Applies a line transform to a file and reports the change.
    @MainActor
    public static func transformFile(_ input: [String: Any], context: AssistContext, title: String, transform: (String) -> String) -> AssistToolResult {
        guard let raw = string(input, "path") else { return missing("path") }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return invalid("Path must be inside the workspace.") }
        guard !isDirectory(url), let original = read(url) else { return notFound("File not found: \(raw)") }
        let updated = transform(original)
        if updated == original {
            return .success("\(title): no changes needed for `\(raw)`.", data: ["changed": "false"])
        }
        if bool(input, "dry_run", default: false) {
            return .success("\(title) (dry run): `\(raw)` would change (\(original.count) → \(updated.count) characters).", data: ["changed": "true"])
        }
        do {
            try writeVerified(updated, to: url)
            AssistToolRegistry.shared.invalidateReadOnlyCache()
            return .success("\(title): updated `\(raw)` (\(original.count) → \(updated.count) characters).",
                            data: ["changed": "true", "path": raw], filesChanged: [raw])
        } catch {
            var f = AssistToolResult.failure("\(title) failed: \(error.localizedDescription)")
            f.toolErrorCode = .executionFailed
            return f
        }
    }
}
