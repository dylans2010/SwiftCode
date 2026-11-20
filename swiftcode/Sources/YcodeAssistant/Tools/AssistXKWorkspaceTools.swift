// Expansion toolkit: Workspace. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKWorkspaceExtensionStatsTool: AssistTool {
    public init() {}
    public var id: String { "workspace_extension_stats" }
    public var name: String { "Extension Statistics" }
    public var description: String { "Counts files, total bytes and total lines per file extension under `path`, sorted by file count." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts files, total bytes and total lines per file extension under `path`, sorted by file count.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var stats: [String: (files: Int, bytes: Int, lines: Int)] = [:]
        for f in AssistToolKit.files(at: root, extensions: nil) {
            let ext = f.pathExtension.isEmpty ? "(none)" : f.pathExtension.lowercased()
            let size = (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let lines = size < 2_000_000 ? (AssistToolKit.read(f)?.reduce(0) { $1 == "\n" ? $0 + 1 : $0 } ?? 0) : 0
            let s = stats[ext] ?? (0, 0, 0); stats[ext] = (s.files + 1, s.bytes + size, s.lines + lines)
        }
        let rows = stats.sorted { $0.value.files > $1.value.files }.map { [$0.key, String($0.value.files), ByteCountFormatter.string(fromByteCount: Int64($0.value.bytes), countStyle: .file), String($0.value.lines)] }
        return .success(AssistTextFormat.markdownTable(headers: ["Extension", "Files", "Size", "Lines"], rows: rows), data: ["extensions": String(stats.count)])
    }
}


public struct XKWorkspaceLargestFilesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_largest_files" }
    public var name: String { "Largest Files" }
    public var description: String { "Lists the largest files under `path` (default top 25) with human-readable sizes." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists the largest files under `path` (default top 25) with human-readable sizes.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "limit": JSONSchema(type: "integer", description: "Maximum entries to return (default 50).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let limit = max(1, min(AssistToolKit.int(input, "limit", default: 25), 500))
        let sized = AssistToolKit.files(at: root, extensions: nil).map { ($0, (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }.sorted { $0.1 > $1.1 }.prefix(limit)
        let lines = sized.map { "\(ByteCountFormatter.string(fromByteCount: Int64($0.1), countStyle: .file))\t\(AssistToolKit.relative($0.0, context))" }
        return .success(lines.joined(separator: "\n"), data: ["count": String(lines.count)])
    }
}


public struct XKWorkspaceRecentFilesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_recent_files" }
    public var name: String { "Recently Modified Files" }
    public var description: String { "Lists files under `path` modified within the last `days` (default 7), newest first." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists files under `path` modified within the last `days` (default 7), newest first.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "days": JSONSchema(type: "integer", description: "Look-back window in days."), "limit": JSONSchema(type: "integer", description: "Maximum entries to return (default 50).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let days = max(1, AssistToolKit.int(input, "days", default: 7)), limit = max(1, AssistToolKit.int(input, "limit", default: 50))
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let fmt = ISO8601DateFormatter()
        let items = AssistToolKit.files(at: root, extensions: nil).compactMap { f -> (URL, Date)? in
            guard let d = try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, d >= cutoff else { return nil }; return (f, d) }
            .sorted { $0.1 > $1.1 }.prefix(limit)
        return .success(items.isEmpty ? "No files modified in the last \(days) day(s)." : items.map { "\(fmt.string(from: $0.1))  \(AssistToolKit.relative($0.0, context))" }.joined(separator: "\n"), data: ["count": String(items.count)])
    }
}


public struct XKWorkspaceFindByGlobTool: AssistTool {
    public init() {}
    public var id: String { "workspace_find_by_glob" }
    public var name: String { "Find Files by Glob" }
    public var description: String { "Finds files whose name (or relative path when the pattern contains '/') matches shell glob `pattern` (e.g. `*View.swift`, `Sources/**/*.json`)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds files whose name (or relative path when the pattern contains '/') matches shell glob `pattern` (e.g. `*View.swift`, `Sources/**/*.json`).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "pattern": JSONSchema(type: "string", description: "Glob pattern."), "limit": JSONSchema(type: "integer", description: "Maximum entries to return (default 50).")], required: ["pattern"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        guard let pattern = AssistToolKit.string(input, "pattern") else { return AssistToolKit.missing("pattern") }
        let limit = max(1, AssistToolKit.int(input, "limit", default: 200))
        let usePath = pattern.contains("/")
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*\\*/", with: "(.*/)?").replacingOccurrences(of: "\\*", with: "[^/]*").replacingOccurrences(of: "\\?", with: "[^/]") + "$"
        guard let re = try? NSRegularExpression(pattern: regexPattern) else { return AssistToolKit.invalid("Invalid glob.") }
        var hits: [String] = []
        for f in AssistToolKit.files(at: root, extensions: nil) {
            let subject = usePath ? AssistToolKit.relative(f, context) : f.lastPathComponent
            if re.firstMatch(in: subject, range: NSRange(subject.startIndex..., in: subject)) != nil { hits.append(AssistToolKit.relative(f, context)); if hits.count >= limit { break } }
        }
        return .success(hits.isEmpty ? "No files match \(pattern)." : hits.joined(separator: "\n"), data: ["count": String(hits.count)])
    }
}


public struct XKWorkspaceEmptyFilesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_empty_files" }
    public var name: String { "Empty Files" }
    public var description: String { "Lists zero-byte files under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists zero-byte files under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let hits = AssistToolKit.files(at: root, extensions: nil).filter { ((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 1) == 0 }.map { AssistToolKit.relative($0, context) }
        return .success(hits.isEmpty ? "No empty files." : hits.joined(separator: "\n"), data: ["count": String(hits.count)])
    }
}


public struct XKWorkspaceEmptyDirectoriesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_empty_directories" }
    public var name: String { "Empty Directories" }
    public var description: String { "Lists directories under `path` that contain no files (ignoring .DS_Store)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists directories under `path` that contain no files (ignoring .DS_Store).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let fm = FileManager.default
        var hits: [String] = []
        if let e = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            while let u = e.nextObject() as? URL {
                if [".build", "node_modules", "DerivedData", ".git"].contains(u.lastPathComponent) { e.skipDescendants(); continue }
                guard AssistToolKit.isDirectory(u) else { continue }
                let items = (try? fm.contentsOfDirectory(atPath: u.path))?.filter { $0 != ".DS_Store" } ?? []
                if items.isEmpty { hits.append(AssistToolKit.relative(u, context)) }
            }
        }
        return .success(hits.isEmpty ? "No empty directories." : hits.joined(separator: "\n"), data: ["count": String(hits.count)])
    }
}


public struct XKWorkspaceDuplicateFilesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_duplicate_files" }
    public var name: String { "Duplicate Files" }
    public var description: String { "Finds files with byte-identical content under `path` (SHA-256), grouped, ignoring files above 20 MB." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds files with byte-identical content under `path` (SHA-256), grouped, ignoring files above 20 MB.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var bySize: [Int: [URL]] = [:]
        for f in AssistToolKit.files(at: root, extensions: nil) { let s = (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0; if s > 0 && s < 20_000_000 { bySize[s, default: []].append(f) } }
        var groups: [[String]] = []
        for (_, list) in bySize where list.count > 1 {
            var byHash: [String: [String]] = [:]
            for f in list { if let d = try? Data(contentsOf: f), let h = AssistToolKit.digest(d, algorithm: "sha256") { byHash[h, default: []].append(AssistToolKit.relative(f, context)) } }
            groups += byHash.values.filter { $0.count > 1 }
        }
        let out = groups.enumerated().map { "Group \($0.offset + 1):\n" + $0.element.map { "  - " + $0 }.joined(separator: "\n") }
        return .success(out.isEmpty ? "No duplicate files." : AssistToolKit.output(out.joined(separator: "\n")), data: ["groups": String(groups.count)])
    }
}


public struct XKWorkspaceSymlinksTool: AssistTool {
    public init() {}
    public var id: String { "workspace_symlinks" }
    public var name: String { "Symbolic Links" }
    public var description: String { "Lists symbolic links under `path` with their targets and whether the target exists." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists symbolic links under `path` with their targets and whether the target exists.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let fm = FileManager.default; var out: [String] = []
        if let e = fm.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) {
            while let u = e.nextObject() as? URL {
                if [".build", ".git", "node_modules"].contains(u.lastPathComponent) { e.skipDescendants(); continue }
                if (try? u.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                    let dest = (try? fm.destinationOfSymbolicLink(atPath: u.path)) ?? "?"
                    out.append("\(AssistToolKit.relative(u, context)) -> \(dest)\(fm.fileExists(atPath: u.path) ? "" : " (BROKEN)")")
                }
            }
        }
        return .success(out.isEmpty ? "No symbolic links." : out.joined(separator: "\n"), data: ["count": String(out.count)])
    }
}


public struct XKWorkspaceBinaryFilesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_binary_files" }
    public var name: String { "Binary Files" }
    public var description: String { "Lists files under `path` that contain NUL bytes in their first 8 KB (binary), with sizes." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists files under `path` that contain NUL bytes in their first 8 KB (binary), with sizes.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var out: [String] = []
        for f in AssistToolKit.files(at: root, extensions: nil) {
            guard let h = try? FileHandle(forReadingFrom: f) else { continue }
            let d = (try? h.read(upToCount: 8192)) ?? Data(); try? h.close()
            if d.contains(0) { out.append("\(ByteCountFormatter.string(fromByteCount: Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0), countStyle: .file))\t\(AssistToolKit.relative(f, context))") }
        }
        return .success(out.isEmpty ? "No binary files." : AssistToolKit.output(out.joined(separator: "\n")), data: ["count": String(out.count)])
    }
}


public struct XKFileHeadLinesTool: AssistTool {
    public init() {}
    public var id: String { "file_head_lines" }
    public var name: String { "File Head" }
    public var description: String { "Returns the first `lines` lines (default 40) of a file with line numbers." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Returns the first `lines` lines (default 40) of a file with line numbers.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file path."), "lines": JSONSchema(type: "integer", description: "Number of lines.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "path") else { return AssistToolKit.missing("path") }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard !AssistToolKit.isDirectory(url), let content = AssistToolKit.read(url) else { return AssistToolKit.notFound("File not found: \(raw)") }
        let n = max(1, AssistToolKit.int(input, "lines", default: 40))
        let all = content.components(separatedBy: .newlines)
        return .success(all.prefix(n).enumerated().map { "\($0.offset + 1)\t\($0.element)" }.joined(separator: "\n"), data: ["totalLines": String(all.count)])
    }
}


public struct XKFileTailLinesTool: AssistTool {
    public init() {}
    public var id: String { "file_tail_lines" }
    public var name: String { "File Tail" }
    public var description: String { "Returns the last `lines` lines (default 40) of a file with line numbers (useful for logs)." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Returns the last `lines` lines (default 40) of a file with line numbers (useful for logs).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file path."), "lines": JSONSchema(type: "integer", description: "Number of lines.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "path") else { return AssistToolKit.missing("path") }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard !AssistToolKit.isDirectory(url), let content = AssistToolKit.read(url) else { return AssistToolKit.notFound("File not found: \(raw)") }
        let n = max(1, AssistToolKit.int(input, "lines", default: 40))
        let all = content.components(separatedBy: .newlines)
        let start = max(0, all.count - n)
        return .success(all[start...].enumerated().map { "\(start + $0.offset + 1)\t\($0.element)" }.joined(separator: "\n"), data: ["totalLines": String(all.count)])
    }
}


public struct XKFileLineStatisticsTool: AssistTool {
    public init() {}
    public var id: String { "file_line_statistics" }
    public var name: String { "File Line Statistics" }
    public var description: String { "Counts total, code, blank and comment lines (// and /* */ styles, # for scripts) in a file or every source file under a directory." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts total, code, blank and comment lines (// and /* */ styles, # for scripts) in a file or every source file under a directory.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var total = 0, blank = 0, comment = 0, files = 0
        for f in AssistToolKit.files(at: root, extensions: ["swift", "m", "mm", "h", "c", "cpp", "js", "ts", "py", "rb", "sh", "kt", "java", "go", "rs"]) {
            guard let s = AssistToolKit.read(f) else { continue }; files += 1
            let hash = ["py", "rb", "sh"].contains(f.pathExtension)
            var inBlock = false
            for l in s.components(separatedBy: .newlines) {
                total += 1; let t = l.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { blank += 1 } else if inBlock { comment += 1; if t.contains("*/") { inBlock = false } }
                else if t.hasPrefix("//") || (hash && t.hasPrefix("#")) { comment += 1 }
                else if t.hasPrefix("/*") { comment += 1; inBlock = !t.contains("*/") }
            }
        }
        return .success("files: \(files)\ntotal: \(total)\ncode: \(total - blank - comment)\ncomment: \(comment)\nblank: \(blank)\ncomment_ratio: \(total == 0 ? 0 : comment * 100 / max(1, total - blank))%", data: ["total": String(total)])
    }
}


public struct XKFileLineEndingsReportTool: AssistTool {
    public init() {}
    public var id: String { "file_line_endings_report" }
    public var name: String { "Line Ending Report" }
    public var description: String { "Reports LF / CRLF / CR line-ending counts and mixed-ending files under `path`." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports LF / CRLF / CR line-ending counts and mixed-ending files under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var out: [String] = []; var mixed = 0
        for f in AssistToolKit.files(at: root, extensions: nil).prefix(5000) {
            guard let d = try? Data(contentsOf: f), !d.contains(0) else { continue }
            var lf = 0, crlf = 0, cr = 0; var prev: UInt8 = 0
            for b in d { if b == 10 { if prev == 13 { crlf += 1 } else { lf += 1 } } else if prev == 13 { cr += 1 }; prev = b }
            let kinds = [lf, crlf, cr].filter { $0 > 0 }.count
            if crlf > 0 || cr > 0 || kinds > 1 { out.append("\(AssistToolKit.relative(f, context)): LF=\(lf) CRLF=\(crlf) CR=\(cr)\(kinds > 1 ? " MIXED" : "")"); if kinds > 1 { mixed += 1 } }
        }
        return .success(out.isEmpty ? "All text files use LF line endings." : out.joined(separator: "\n"), data: ["nonLF": String(out.count), "mixed": String(mixed)])
    }
}


public struct XKFileEncodingReportTool: AssistTool {
    public init() {}
    public var id: String { "file_encoding_report" }
    public var name: String { "Encoding Report" }
    public var description: String { "Checks text files under `path` for invalid UTF-8, UTF-8 BOMs and UTF-16 BOMs." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Checks text files under `path` for invalid UTF-8, UTF-8 BOMs and UTF-16 BOMs.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var out: [String] = []
        for f in AssistToolKit.files(at: root, extensions: nil).prefix(5000) {
            guard let d = try? Data(contentsOf: f), !d.isEmpty else { continue }
            if d.starts(with: [0xEF, 0xBB, 0xBF]) { out.append("\(AssistToolKit.relative(f, context)): UTF-8 with BOM") }
            else if d.starts(with: [0xFF, 0xFE]) || d.starts(with: [0xFE, 0xFF]) { out.append("\(AssistToolKit.relative(f, context)): UTF-16") }
            else if !d.prefix(8192).contains(0), String(data: d, encoding: .utf8) == nil { out.append("\(AssistToolKit.relative(f, context)): invalid UTF-8") }
        }
        return .success(out.isEmpty ? "All text files are valid UTF-8 without BOM." : out.joined(separator: "\n"), data: ["issues": String(out.count)])
    }
}


public struct XKFileMetadataInfoTool: AssistTool {
    public init() {}
    public var id: String { "file_metadata_info" }
    public var name: String { "File Metadata" }
    public var description: String { "Returns size, creation/modification dates, POSIX permissions, owner and type for a file or directory." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Returns size, creation/modification dates, POSIX permissions, owner and type for a file or directory.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "path") else { return AssistToolKit.missing("path") }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path) else { return AssistToolKit.notFound("Not found: \(raw)") }
        let fmt = ISO8601DateFormatter()
        let perms = (a[.posixPermissions] as? NSNumber).map { String($0.intValue, radix: 8) } ?? "?"
        return .success("path: \(raw)\ntype: \(a[.type] as? String ?? "?")\nsize: \(a[.size] ?? 0) bytes\ncreated: \((a[.creationDate] as? Date).map(fmt.string) ?? "?")\nmodified: \((a[.modificationDate] as? Date).map(fmt.string) ?? "?")\npermissions: \(perms)\nowner: \(a[.ownerAccountName] ?? "?")")
    }
}


public struct XKFileIdentifierFrequencyTool: AssistTool {
    public init() {}
    public var id: String { "file_identifier_frequency" }
    public var name: String { "Identifier Frequency" }
    public var description: String { "Counts the most frequent identifiers (words of 3+ chars, excluding Swift keywords) in a file or directory; useful for naming and domain discovery." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts the most frequent identifiers (words of 3+ chars, excluding Swift keywords) in a file or directory; useful for naming and domain discovery.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "limit": JSONSchema(type: "integer", description: "Maximum entries to return (default 50).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let kw: Set<String> = ["let", "var", "func", "return", "self", "import", "struct", "class", "enum", "case", "public", "private", "static", "guard", "else", "true", "false", "nil", "for", "while", "init", "try", "await", "async", "throws", "some", "any", "extension", "protocol", "switch", "default", "where", "the", "internal", "final", "override", "String", "Int", "Bool"]
        let n = max(1, AssistToolKit.int(input, "limit", default: 40))
        var counts: [String: Int] = [:]
        for f in AssistToolKit.files(at: root, extensions: ["swift"]).prefix(3000) { for w in (AssistToolKit.read(f) ?? "").split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") }) where w.count >= 3 && !kw.contains(String(w)) && !(w.first?.isNumber ?? false) { counts[String(w), default: 0] += 1 } }
        return .success(counts.sorted { $0.value > $1.value }.prefix(n).map { "\($0.value)\t\($0.key)" }.joined(separator: "\n"), data: ["unique": String(counts.count)])
    }
}


public struct XKFileDuplicateLinesTool: AssistTool {
    public init() {}
    public var id: String { "file_duplicate_lines" }
    public var name: String { "Duplicate Line Finder" }
    public var description: String { "Finds non-trivial lines (trimmed length >= `min_length`, default 30) that repeat across Swift files, a cheap copy-paste detector." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds non-trivial lines (trimmed length >= `min_length`, default 30) that repeat across Swift files, a cheap copy-paste detector.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "min_length": JSONSchema(type: "integer", description: "Minimum trimmed length.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let minLen = max(10, AssistToolKit.int(input, "min_length", default: 30))
        var seen: [String: [String]] = [:]
        for f in AssistToolKit.files(at: root, extensions: ["swift"]).prefix(3000) {
            for (i, l) in (AssistToolKit.read(f) ?? "").components(separatedBy: .newlines).enumerated() {
                let t = l.trimmingCharacters(in: .whitespaces); guard t.count >= minLen, !t.hasPrefix("//"), !t.hasPrefix("import") else { continue }
                seen[t, default: []].append("\(AssistToolKit.relative(f, context)):\(i + 1)") }
        }
        let dups = seen.filter { $0.value.count > 1 }.sorted { $0.value.count > $1.value.count }.prefix(100)
        return .success(dups.isEmpty ? "No duplicated lines found." : AssistToolKit.output(dups.map { "\($0.value.count)x `\($0.key.prefix(120))`\n   " + $0.value.prefix(6).joined(separator: ", ") }.joined(separator: "\n")), data: ["groups": String(dups.count)])
    }
}


public struct XKWorkspaceTermCountTool: AssistTool {
    public init() {}
    public var id: String { "workspace_term_count" }
    public var name: String { "Term Occurrence Count" }
    public var description: String { "Counts literal occurrences of `term` per file under `path` (optionally `case_insensitive`), sorted by count." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts literal occurrences of `term` per file under `path` (optionally `case_insensitive`), sorted by count.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "term": JSONSchema(type: "string", description: "Literal text."), "case_insensitive": JSONSchema(type: "boolean", description: "Ignore case.")], required: ["term"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        guard let term = AssistToolKit.string(input, "term"), !term.isEmpty else { return AssistToolKit.missing("term") }
        let ci = AssistToolKit.bool(input, "case_insensitive", default: false)
        var rows: [(String, Int)] = []
        for f in AssistToolKit.files(at: root, extensions: nil).prefix(10000) {
            guard let s = AssistToolKit.read(f) else { continue }
            let c = (ci ? s.lowercased() : s).components(separatedBy: ci ? term.lowercased() : term).count - 1
            if c > 0 { rows.append((AssistToolKit.relative(f, context), c)) }
        }
        rows.sort { $0.1 > $1.1 }
        return .success(rows.isEmpty ? "No occurrences of '\(term)'." : AssistToolKit.output("total: \(rows.reduce(0) { $0 + $1.1 }) in \(rows.count) file(s)\n" + rows.map { "\($0.1)\t\($0.0)" }.joined(separator: "\n")), data: ["files": String(rows.count)])
    }
}


public struct XKWorkspaceDirectorySizesTool: AssistTool {
    public init() {}
    public var id: String { "workspace_directory_sizes" }
    public var name: String { "Directory Sizes" }
    public var description: String { "Reports total size and file count of each immediate subdirectory of `path`, largest first." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports total size and file count of each immediate subdirectory of `path`, largest first.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        var rows: [(String, Int, Int)] = []
        for c in children where AssistToolKit.isDirectory(c) {
            var bytes = 0, count = 0
            if let e = fm.enumerator(at: c, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) { while let u = e.nextObject() as? URL { if let v = try? u.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), v.isRegularFile == true { bytes += v.fileSize ?? 0; count += 1 } } }
            rows.append((AssistToolKit.relative(c, context), bytes, count))
        }
        rows.sort { $0.1 > $1.1 }
        return .success(AssistTextFormat.markdownTable(headers: ["Directory", "Size", "Files"], rows: rows.map { [$0.0, ByteCountFormatter.string(fromByteCount: Int64($0.1), countStyle: .file), String($0.2)] }))
    }
}


public struct XKFileCompareTool: AssistTool {
    public init() {}
    public var id: String { "file_compare" }
    public var name: String { "Compare Two Files" }
    public var description: String { "Line-diffs workspace files `path_a` and `path_b` and reports added/removed line counts plus the diff (truncated)." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Line-diffs workspace files `path_a` and `path_b` and reports added/removed line counts plus the diff (truncated).", properties: ["path_a": JSONSchema(type: "string", description: "First file."), "path_b": JSONSchema(type: "string", description: "Second file.")], required: ["path_a", "path_b"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let a = AssistToolKit.string(input, "path_a"), let b = AssistToolKit.string(input, "path_b") else { return AssistToolKit.missing("path_a/path_b") }
        guard let ua = AssistWorkspacePaths.resolve(a, workspaceRoot: context.workspaceRoot), let ub = AssistWorkspacePaths.resolve(b, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("Paths must be inside the workspace.") }
        guard let ta = AssistToolKit.read(ua), let tb = AssistToolKit.read(ub) else { return AssistToolKit.notFound("Both files must exist.") }
        if ta == tb { return .success("Files are identical.", data: ["identical": "true"]) }
        let al = ta.components(separatedBy: .newlines), bl = tb.components(separatedBy: .newlines)
        var out: [String] = []; var add = 0, rem = 0
        for c in bl.difference(from: al) { switch c { case .remove(let o, let e, _): rem += 1; out.append("-\(o + 1): \(e)"); case .insert(let o, let e, _): add += 1; out.append("+\(o + 1): \(e)") } }
        return .success(AssistToolKit.output("removed: \(rem), added: \(add)\n" + out.joined(separator: "\n")), data: ["identical": "false"])
    }
}


public struct XKFileHashDigestTool: AssistTool {
    public init() {}
    public var id: String { "file_hash_digest" }
    public var name: String { "File Hash Digest" }
    public var description: String { "Computes the SHA-256 (or `algorithm`: sha1, sha384, sha512, md5) digest of a workspace file." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Computes the SHA-256 (or `algorithm`: sha1, sha384, sha512, md5) digest of a workspace file.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file path."), "algorithm": JSONSchema(type: "string", description: "sha256 | sha1 | sha384 | sha512 | md5")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "path") else { return AssistToolKit.missing("path") }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot), let d = try? Data(contentsOf: url) else { return AssistToolKit.notFound("File not found: \(raw)") }
        let algo = AssistToolKit.string(input, "algorithm") ?? "sha256"
        guard let h = AssistToolKit.digest(d, algorithm: algo) else { return AssistToolKit.invalid("Unsupported algorithm.") }
        return .success("\(h)  \(raw)", data: ["digest": h, "bytes": String(d.count)])
    }
}


public struct XKFileLongFunctionsReportTool: AssistTool {
    public init() {}
    public var id: String { "file_long_functions_report" }
    public var name: String { "Long Swift Functions" }
    public var description: String { "Measures every Swift function body under `path` via brace matching and lists those longer than `threshold` lines (default 50) with branch counts." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Measures every Swift function body under `path` via brace matching and lists those longer than `threshold` lines (default 50) with branch counts.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "threshold": JSONSchema(type: "integer", description: "Minimum body length in lines.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        let threshold = max(5, AssistToolKit.int(input, "threshold", default: 50))
        let fre = try NSRegularExpression(pattern: "\\bfunc\\s+([A-Za-z_][\\w]*)")
        var rows: [(String, Int, Int)] = []
        for f in AssistToolKit.files(at: root, extensions: ["swift"]) {
            guard let s = AssistToolKit.read(f) else { continue }
            let lines = s.components(separatedBy: .newlines)
            var i = 0
            while i < lines.count {
                let l = lines[i]
                if let m = fre.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)), let r = Range(m.range(at: 1), in: l) {
                    var depth = 0, started = false, j = i, branches = 0
                    while j < lines.count {
                        for ch in lines[j] { if ch == "{" { depth += 1; started = true } else if ch == "}" { depth -= 1 } }
                        let t = lines[j]; for k in ["if ", "guard ", "case ", "for ", "while ", "catch", "&&", "||", "?? "] { branches += t.components(separatedBy: k).count - 1 }
                        if started && depth <= 0 { break }
                        if !started && j > i + 5 { break }
                        j += 1
                    }
                    if started, j - i + 1 > threshold { rows.append(("\(AssistToolKit.relative(f, context)):\(i + 1) \(l[r])", j - i + 1, branches)) }
                }
                i += 1
            }
        }
        rows.sort { $0.1 > $1.1 }
        return .success(rows.isEmpty ? "No functions exceed \(threshold) lines." : AssistToolKit.output(rows.map { "\($0.1) lines, ~\($0.2) branches — \($0.0)" }.joined(separator: "\n")), data: ["count": String(rows.count)])
    }
}


public struct XKFileNestingDepthReportTool: AssistTool {
    public init() {}
    public var id: String { "file_nesting_depth_report" }
    public var name: String { "Brace Nesting Depth" }
    public var description: String { "Reports the maximum brace nesting depth per Swift file under `path` (deep nesting signals refactoring opportunities)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reports the maximum brace nesting depth per Swift file under `path` (deep nesting signals refactoring opportunities).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "limit": JSONSchema(type: "integer", description: "Maximum entries to return (default 50).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        guard FileManager.default.fileExists(atPath: root.path) else { return AssistToolKit.notFound("Path not found.") }
        var rows: [(String, Int, Int)] = []
        for f in AssistToolKit.files(at: root, extensions: ["swift"]) {
            guard let s = AssistToolKit.read(f) else { continue }
            var d = 0, maxD = 0, line = 1, at = 1
            var inStr = false
            for ch in s { if ch == "\n" { line += 1; inStr = false } else if ch == "\"" { inStr.toggle() } else if !inStr { if ch == "{" { d += 1; if d > maxD { maxD = d; at = line } } else if ch == "}" { d = max(0, d - 1) } } }
            rows.append((AssistToolKit.relative(f, context), maxD, at))
        }
        rows.sort { $0.1 > $1.1 }
        return .success(AssistToolKit.output(rows.prefix(AssistToolKit.int(input, "limit", default: 30)).map { "depth \($0.1) at line \($0.2) — \($0.0)" }.joined(separator: "\n")), data: ["files": String(rows.count)])
    }
}


public struct XKFileStripTrailingWhitespaceTool: AssistTool {
    public init() {}
    public var id: String { "file_strip_trailing_whitespace" }
    public var name: String { "Strip Trailing Whitespace" }
    public var description: String { "Removes trailing spaces and tabs from every line of a file (writes atomically, verifies, supports `dry_run`)." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Removes trailing spaces and tabs from every line of a file (writes atomically, verifies, supports `dry_run`).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Strip Trailing Whitespace") { original in
            original.components(separatedBy: "\n").map { l in var s = Substring(l); while let c = s.last, c == " " || c == "\t" { s = s.dropLast() }; return String(s) }.joined(separator: "\n")
        }
    }
}


public struct XKFileTabsToSpacesTool: AssistTool {
    public init() {}
    public var id: String { "file_tabs_to_spaces" }
    public var name: String { "Convert Tabs to Spaces" }
    public var description: String { "Replaces leading tab indentation with `width` spaces (default 4) on every line of a file." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Replaces leading tab indentation with `width` spaces (default 4) on every line of a file.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing."), "width": JSONSchema(type: "integer", description: "Spaces per tab.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Convert Tabs to Spaces") { original in
            let w = String(repeating: " ", count: max(1, AssistToolKit.int(input, "width", default: 4)))
            return original.components(separatedBy: "\n").map { l in let tabs = l.prefix(while: { $0 == "\t" }).count; return String(repeating: w, count: tabs) + l.dropFirst(tabs) }.joined(separator: "\n")
        }
    }
}


public struct XKFileEnsureFinalNewlineTool: AssistTool {
    public init() {}
    public var id: String { "file_ensure_final_newline" }
    public var name: String { "Ensure Final Newline" }
    public var description: String { "Ensures a file ends with exactly one trailing newline." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Ensures a file ends with exactly one trailing newline.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Ensure Final Newline") { original in
            var s = original; while s.hasSuffix("\n\n") { s.removeLast() }; if !s.hasSuffix("\n") { s += "\n" }; return s
        }
    }
}


public struct XKFileNormalizeLineEndingsTool: AssistTool {
    public init() {}
    public var id: String { "file_normalize_line_endings" }
    public var name: String { "Normalize Line Endings" }
    public var description: String { "Converts all CRLF/CR line endings in a file to LF (or to CRLF when `style` is crlf)." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts all CRLF/CR line endings in a file to LF (or to CRLF when `style` is crlf).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing."), "style": JSONSchema(type: "string", description: "lf (default) or crlf.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Normalize Line Endings") { original in
            let lf = original.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            return (AssistToolKit.string(input, "style") ?? "lf").lowercased() == "crlf" ? lf.replacingOccurrences(of: "\n", with: "\r\n") : lf
        }
    }
}


public struct XKFileCollapseBlankLinesTool: AssistTool {
    public init() {}
    public var id: String { "file_collapse_blank_lines" }
    public var name: String { "Collapse Blank Lines" }
    public var description: String { "Collapses runs of more than `max_blank` consecutive blank lines (default 1) in a file." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Collapses runs of more than `max_blank` consecutive blank lines (default 1) in a file.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing."), "max_blank": JSONSchema(type: "integer", description: "Allowed consecutive blank lines.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Collapse Blank Lines") { original in
            let maxBlank = max(0, AssistToolKit.int(input, "max_blank", default: 1))
            var out: [String] = []; var run = 0
            for l in original.components(separatedBy: "\n") { if l.trimmingCharacters(in: .whitespaces).isEmpty { run += 1; if run > maxBlank { continue } } else { run = 0 }; out.append(l) }
            return out.joined(separator: "\n")
        }
    }
}


public struct XKFileSortSwiftImportsTool: AssistTool {
    public init() {}
    public var id: String { "file_sort_swift_imports" }
    public var name: String { "Sort Swift Imports" }
    public var description: String { "Sorts and deduplicates the contiguous top-of-file `import` block of a Swift file (keeps @testable/@_exported attributes)." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Sorts and deduplicates the contiguous top-of-file `import` block of a Swift file (keeps @testable/@_exported attributes).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Sort Swift Imports") { original in
            var lines = original.components(separatedBy: "\n")
            guard let first = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).range(of: #"^(@\w+\s+)*import\s"#, options: .regularExpression) != nil }) else { return original }
            var last = first
            while last + 1 < lines.count, lines[last + 1].trimmingCharacters(in: .whitespaces).range(of: #"^(@\w+\s+)*import\s"#, options: .regularExpression) != nil { last += 1 }
            var seen = Set<String>()
            let sorted = lines[first...last].map { $0.trimmingCharacters(in: .whitespaces) }.filter { seen.insert($0).inserted }
                .sorted { ($0.components(separatedBy: "import ").last ?? $0).lowercased() < ($1.components(separatedBy: "import ").last ?? $1).lowercased() }
            lines.replaceSubrange(first...last, with: sorted)
            return lines.joined(separator: "\n")
        }
    }
}


public struct XKFileAddHeaderCommentTool: AssistTool {
    public init() {}
    public var id: String { "file_add_header_comment" }
    public var name: String { "Add Header Comment" }
    public var description: String { "Prepends `header` (each line prefixed with `// ` unless already a comment) to a file if the file does not already start with it." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Prepends `header` (each line prefixed with `// ` unless already a comment) to a file if the file does not already start with it.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing."), "header": JSONSchema(type: "string", description: "Header text (e.g. license line).")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Add Header Comment") { original in
            guard let header = AssistToolKit.string(input, "header"), !header.isEmpty else { return original }
            let block = header.components(separatedBy: .newlines).map { $0.hasPrefix("//") || $0.hasPrefix("#") ? $0 : "// " + $0 }.joined(separator: "\n")
            return original.hasPrefix(block) ? original : block + "\n\n" + original
        }
    }
}


public struct XKFileRegexReplaceTool: AssistTool {
    public init() {}
    public var id: String { "file_regex_replace" }
    public var name: String { "Regex Replace in File" }
    public var description: String { "Replaces every match of regex `pattern` with `template` ($1 groups) in one file. Use `dry_run` first; returns change summary." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Replaces every match of regex `pattern` with `template` ($1 groups) in one file. Use `dry_run` first; returns change summary.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing."), "pattern": JSONSchema(type: "string", description: "ICU regex."), "template": JSONSchema(type: "string", description: "Replacement template.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Regex Replace in File") { original in
            guard let p = AssistToolKit.string(input, "pattern"), let re = try? NSRegularExpression(pattern: p, options: [.anchorsMatchLines]) else { return original }
            return re.stringByReplacingMatches(in: original, range: NSRange(original.startIndex..., in: original), withTemplate: AssistToolKit.string(input, "template") ?? "")
        }
    }
}


public struct XKFileRenameIdentifierTool: AssistTool {
    public init() {}
    public var id: String { "file_rename_identifier" }
    public var name: String { "Rename Identifier in File" }
    public var description: String { "Renames whole-word occurrences of identifier `from` to `to` in a single file (word-boundary safe, skips partial matches)." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Renames whole-word occurrences of identifier `from` to `to` in a single file (word-boundary safe, skips partial matches).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing."), "from": JSONSchema(type: "string", description: "Existing identifier."), "to": JSONSchema(type: "string", description: "New identifier.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Rename Identifier in File") { original in
            guard let from = AssistToolKit.string(input, "from"), let to = AssistToolKit.string(input, "to"), !from.isEmpty,
                  let re = try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b") else { return original }
            return re.stringByReplacingMatches(in: original, range: NSRange(original.startIndex..., in: original), withTemplate: NSRegularExpression.escapedTemplate(for: to))
        }
    }
}


public struct XKFileRemovePrintStatementsTool: AssistTool {
    public init() {}
    public var id: String { "file_remove_print_statements" }
    public var name: String { "Remove print Statements" }
    public var description: String { "Deletes lines in a Swift file that consist solely of a print(...)/debugPrint(...) call." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Deletes lines in a Swift file that consist solely of a print(...)/debugPrint(...) call.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file to modify."), "dry_run": JSONSchema(type: "boolean", description: "Report whether the file would change without writing.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.transformFile(input, context: context, title: "Remove print Statements") { original in
            original.components(separatedBy: "\n").filter { $0.trimmingCharacters(in: .whitespaces).range(of: #"^(debugPrint|print)\(.*\)\s*;?$"#, options: .regularExpression) == nil }.joined(separator: "\n")
        }
    }
}


public struct XKFileBackupCopyTool: AssistTool {
    public init() {}
    public var id: String { "file_backup_copy" }
    public var name: String { "Backup File Copy" }
    public var description: String { "Copies a workspace file to `<path>.bak` (or `destination`) before risky edits; refuses to overwrite unless `overwrite` is true." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Copies a workspace file to `<path>.bak` (or `destination`) before risky edits; refuses to overwrite unless `overwrite` is true.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file path."), "destination": JSONSchema(type: "string", description: "Optional destination path."), "overwrite": JSONSchema(type: "boolean", description: "Replace existing backup.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "path") else { return AssistToolKit.missing("path") }
        let destRaw = AssistToolKit.string(input, "destination") ?? raw + ".bak"
        guard let src = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot), let dst = AssistWorkspacePaths.resolve(destRaw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("Paths must be inside the workspace.") }
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path) else { return AssistToolKit.notFound("File not found: \(raw)") }
        if fm.fileExists(atPath: dst.path) { guard AssistToolKit.bool(input, "overwrite", default: false) else { return AssistToolKit.invalid("\(destRaw) exists; pass overwrite=true.") }; try fm.removeItem(at: dst) }
        try fm.copyItem(at: src, to: dst)
        return .success("Copied \(raw) → \(destRaw)", data: ["destination": destRaw], filesChanged: [destRaw])
    }
}
