import Foundation
import CryptoKit

// MARK: - Tool Call

struct AgentToolCall {
    let name: String
    let parameters: [String: Any]
}

// MARK: - Tool Result

struct AgentToolResult {
    let toolName: String
    let result: String
    let isError: Bool

    static func success(_ toolName: String, _ result: String) -> AgentToolResult {
        AgentToolResult(toolName: toolName, result: result, isError: false)
    }

    static func failure(_ toolName: String, _ message: String) -> AgentToolResult {
        AgentToolResult(toolName: toolName, result: message, isError: true)
    }
}

// MARK: - Agent Tool Service

@MainActor
final class AgentToolService {
    static let shared = AgentToolService()
    private init() {}

    // MARK: - System Prompt

    nonisolated static func buildSystemPrompt() -> String {
        let toolDocs = AgentTool.all
            .map { $0.promptDescription }
            .joined(separator: "\n\n")

        return """
        You are an AI agent with access to \(AgentTool.all.count) tools for working with Swift projects, files, and code. \
        When you need to use a tool, output a tool call in EXACTLY this format (nothing else on those lines):

        <tool_call>
        {"name": "tool_name", "parameters": {"param": "value"}}
        </tool_call>

        You may issue multiple tool calls in a single reply. After receiving the results you may call more tools or \
        provide your final answer. Always read tool results carefully before deciding what to do next.

        AVAILABLE TOOLS:

        \(toolDocs)

        Guidelines:
        - Use tools to gather facts before modifying files
        - Verify that write operations succeeded
        - Provide a concise summary of actions taken in your final answer
        - If a tool returns an error try an alternative approach
        """
    }

    // MARK: - Execute

    func execute(
        toolName: String,
        parameters: [String: Any],
        projectManager: ProjectManager
    ) async -> AgentToolResult {

        func str(_ key: String) -> String { parameters[key] as? String ?? "" }
        func int(_ key: String) -> Int? {
            if let n = parameters[key] as? Int    { return n }
            if let s = parameters[key] as? String { return Int(s) }
            return nil
        }

        switch toolName {

        // ──────────────────────────────────────────────────────────────
        // MARK: File System
        // ──────────────────────────────────────────────────────────────

        case "read_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            do {
                let content = try CodingManager.shared.readFile(at: str("path"), in: project.directoryURL)
                return .success(toolName, content)
            } catch {
                return .failure(toolName, "Cannot read file: \(str("path"))")
            }

        case "write_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path"); let content = str("content")
            do {
                try CodingManager.shared.writeFile(content: content, at: path, in: project.directoryURL)
                projectManager.refreshFileTree(for: project)
                if projectManager.activeFileNode?.path == path {
                    projectManager.activeFileContent = content
                }
                return .success(toolName, "Wrote \(content.count) characters to \(path)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "create_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path"); let content = str("content")
            let dirPath = (path as NSString).deletingLastPathComponent
            let fileName = (path as NSString).lastPathComponent
            do {
                try CodingManager.shared.createFile(
                    named: fileName,
                    at: dirPath.isEmpty ? nil : dirPath,
                    in: project.directoryURL,
                    content: content
                )
                projectManager.refreshFileTree(for: project)
                return .success(toolName, "Created file: \(path)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "delete_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            do {
                try CodingManager.shared.deleteItem(at: str("path"), in: project.directoryURL)
                projectManager.refreshFileTree(for: project)
                return .success(toolName, "Deleted: \(str("path"))")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "list_directory":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path")
            let dirURL = path.isEmpty
                ? project.directoryURL
                : project.directoryURL.appendingPathComponent(path)
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else {
                return .failure(toolName, "Cannot list: \(path.isEmpty ? "root" : path)")
            }
            let lines = items
                .filter { $0.lastPathComponent != "project.json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { u -> String in
                    let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    return isDir ? "\(u.lastPathComponent)/" : u.lastPathComponent
                }
            return .success(toolName, lines.isEmpty ? "(empty)" : lines.joined(separator: "\n"))

        case "create_directory":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path")
            let dirPath = (path as NSString).deletingLastPathComponent
            let folderName = (path as NSString).lastPathComponent
            do {
                try CodingManager.shared.createDirectory(
                    named: folderName,
                    at: dirPath.isEmpty ? nil : dirPath,
                    in: project.directoryURL
                )
                projectManager.refreshFileTree(for: project)
                return .success(toolName, "Created directory: \(path)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "delete_directory":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            do {
                try CodingManager.shared.deleteItem(at: str("path"), in: project.directoryURL)
                projectManager.refreshFileTree(for: project)
                return .success(toolName, "Deleted directory: \(str("path"))")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "rename_item":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let oldPath = str("old_path"); let newName = str("new_name")
            do {
                try CodingManager.shared.renameItem(at: oldPath, to: newName, in: project.directoryURL)
                projectManager.refreshFileTree(for: project)
                return .success(toolName, "Renamed \(oldPath) → \(newName)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "file_exists":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let exists = CodingManager.shared.fileExists(at: str("path"), in: project.directoryURL)
            return .success(toolName, exists ? "true" : "false")

        case "copy_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let sourcePath = str("source"); let destPath = str("destination")
            do {
                let content = try CodingManager.shared.readFile(at: sourcePath, in: project.directoryURL)
                try CodingManager.shared.writeFile(content: content, at: destPath, in: project.directoryURL)
                projectManager.refreshFileTree(for: project)
                return .success(toolName, "Copied \(sourcePath) → \(destPath)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "get_file_info":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path")
            let url  = project.directoryURL.appendingPathComponent(path)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                return .failure(toolName, "Cannot get info for: \(path)")
            }
            let size     = attrs[.size] as? Int ?? 0
            let df       = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
            let created  = (attrs[.creationDate]     as? Date).map { df.string(from: $0) } ?? "—"
            let modified = (attrs[.modificationDate] as? Date).map { df.string(from: $0) } ?? "—"
            return .success(toolName,
                "Path: \(path)\nSize: \(size) bytes\nCreated: \(created)\nModified: \(modified)")

        case "append_to_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path"); let extra = str("content")
            do {
                var existing = try CodingManager.shared.readFile(at: path, in: project.directoryURL)
                existing += extra
                try CodingManager.shared.writeFile(content: existing, at: path, in: project.directoryURL)
                if projectManager.activeFileNode?.path == path {
                    projectManager.activeFileContent = existing
                }
                return .success(toolName, "Appended \(extra.count) characters to \(path)")
            } catch { return .failure(toolName, error.localizedDescription) }

        // ──────────────────────────────────────────────────────────────
        // MARK: Code Analysis
        // ──────────────────────────────────────────────────────────────

        case "search_in_file":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path  = str("path"); let query = str("query")
            guard let content = try? CodingManager.shared.readFile(at: path, in: project.directoryURL) else {
                return .failure(toolName, "Cannot read file: \(path)")
            }
            let matches = content.components(separatedBy: "\n")
                .enumerated()
                .compactMap { (i, line) -> String? in
                    line.localizedCaseInsensitiveContains(query)
                        ? "Line \(i + 1): \(line)" : nil
                }
            return .success(toolName, matches.isEmpty
                ? "No matches for '\(query)' in \(path)"
                : matches.joined(separator: "\n"))

        case "search_project":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            var results: [String] = []
            searchFiles(in: project.directoryURL, base: project.directoryURL,
                        query: str("query"), results: &results)
            return .success(toolName, results.isEmpty
                ? "No matches for '\(str("query"))'"
                : results.joined(separator: "\n"))

        case "find_and_replace":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path"); let find = str("find"); let replace = str("replace")
            do {
                var content = try CodingManager.shared.readFile(at: path, in: project.directoryURL)
                let occurrences = content.components(separatedBy: find).count - 1
                content = content.replacingOccurrences(of: find, with: replace)
                try CodingManager.shared.writeFile(content: content, at: path, in: project.directoryURL)
                if projectManager.activeFileNode?.path == path {
                    projectManager.activeFileContent = content
                }
                return .success(toolName,
                    "Replaced \(occurrences) occurrence(s) of '\(find)' in \(path)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "count_lines":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            guard let content = try? CodingManager.shared.readFile(at: str("path"), in: project.directoryURL) else {
                return .failure(toolName, "Cannot read file: \(str("path"))")
            }
            return .success(toolName, "\(content.components(separatedBy: "\n").count) lines")

        case "extract_swift_symbols":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            guard let content = try? CodingManager.shared.readFile(at: str("path"), in: project.directoryURL) else {
                return .failure(toolName, "Cannot read file: \(str("path"))")
            }
            let syms = extractSwiftSymbols(from: content)
            return .success(toolName, syms.isEmpty ? "No symbols found" : syms.joined(separator: "\n"))

        case "find_todos":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            var results: [String] = []
            let path = str("path")
            if path.isEmpty {
                findTodos(in: project.directoryURL, base: project.directoryURL, results: &results)
            } else {
                let url = project.directoryURL.appendingPathComponent(path)
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    content.components(separatedBy: "\n").enumerated().forEach { (i, line) in
                        let u = line.uppercased()
                        if u.contains("TODO") || u.contains("FIXME") || u.contains("HACK") {
                            results.append("Line \(i + 1): \(line.trimmingCharacters(in: .whitespaces))")
                        }
                    }
                }
            }
            return .success(toolName, results.isEmpty ? "No TODOs found" : results.joined(separator: "\n"))

        case "find_imports":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let url = project.directoryURL.appendingPathComponent(str("path"))
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return .failure(toolName, "Cannot read file: \(str("path"))")
            }
            let imports = content.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
            return .success(toolName, imports.isEmpty ? "No imports found" : imports.joined(separator: "\n"))

        case "count_words":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let url = project.directoryURL.appendingPathComponent(str("path"))
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return .failure(toolName, "Cannot read file: \(str("path"))")
            }
            let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            return .success(toolName, "\(words.count) words")

        case "get_line":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            guard let lineNum = int("line") else {
                return .failure(toolName, "Invalid line parameter")
            }
            let endLineNum = int("end_line") ?? lineNum
            let url = project.directoryURL.appendingPathComponent(str("path"))
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return .failure(toolName, "Cannot read file: \(str("path"))")
            }
            let lines = content.components(separatedBy: "\n")
            let start = max(0, lineNum - 1)
            let end   = min(lines.count - 1, endLineNum - 1)
            guard start <= end, start < lines.count else {
                return .failure(toolName, "Line out of range (file has \(lines.count) lines)")
            }
            let result = lines[start...end]
                .enumerated()
                .map { "Line \(start + $0.offset + 1): \($0.element)" }
                .joined(separator: "\n")
            return .success(toolName, result)

        case "diff_content":
            let orig = str("original").components(separatedBy: "\n")
            let mod  = str("modified").components(separatedBy: "\n")
            var diff: [String] = []
            for i in 0..<max(orig.count, mod.count) {
                if i < orig.count && i < mod.count {
                    if orig[i] != mod[i] { diff += ["- \(orig[i])", "+ \(mod[i])"] }
                } else if i < orig.count {
                    diff.append("- \(orig[i])")
                } else {
                    diff.append("+ \(mod[i])")
                }
            }
            return .success(toolName, diff.isEmpty ? "No differences" : diff.joined(separator: "\n"))

        // ──────────────────────────────────────────────────────────────
        // MARK: Code Generation
        // ──────────────────────────────────────────────────────────────

        case "generate_swiftui_view":
            return .success(toolName, codeSwiftUIView(name: str("name"), desc: str("description")))

        case "generate_model":
            return .success(toolName, codeModel(name: str("name"), properties: str("properties")))

        case "generate_viewmodel":
            return .success(toolName, codeViewModel(name: str("name"), modelName: str("model_name")))

        case "generate_service":
            return .success(toolName, codeService(name: str("name"), desc: str("description")))

        case "generate_unit_tests":
            return .success(toolName, codeUnitTests(typeName: str("type_name"), methods: str("methods")))

        case "generate_enum":
            return .success(toolName, codeEnum(name: str("name"), cases: str("cases"), rawType: str("raw_type")))

        case "generate_protocol":
            return .success(toolName, codeProtocol(name: str("name"), methods: str("methods")))

        case "generate_extension":
            return .success(toolName, codeExtension(typeName: str("type_name"), desc: str("description")))

        case "generate_struct":
            return .success(toolName, codeStruct(name: str("name"), properties: str("properties")))

        case "generate_async_function":
            let returnType = str("return_type").isEmpty ? "Void" : str("return_type")
            return .success(toolName, codeAsyncFunction(
                name: str("name"), returnType: returnType, params: str("parameters")))

        case "add_swift_import":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path"); let module = str("module")
            let url  = project.directoryURL.appendingPathComponent(path)
            guard var content = try? String(contentsOf: url, encoding: .utf8) else {
                return .failure(toolName, "Cannot read file: \(path)")
            }
            let importLine = "import \(module)"
            if content.contains(importLine) {
                return .success(toolName, "\(module) is already imported in \(path)")
            }
            content = importLine + "\n" + content
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                if projectManager.activeFileNode?.path == path {
                    projectManager.activeFileContent = content
                }
                return .success(toolName, "Added 'import \(module)' to \(path)")
            } catch { return .failure(toolName, error.localizedDescription) }

        case "generate_preview":
            let vn = str("view_name"); let pms = str("parameters")
            let body = pms.isEmpty ? "\(vn)()" : "\(vn)(\(pms))"
            return .success(toolName, "#Preview {\n    \(body)\n}")

        // ──────────────────────────────────────────────────────────────
        // MARK: Text & Strings
        // ──────────────────────────────────────────────────────────────

        case "to_camel_case":
            return .success(toolName, toCamelCase(str("text")))

        case "to_snake_case":
            return .success(toolName, toSnakeCase(str("text")))

        case "to_pascal_case":
            return .success(toolName, toPascalCase(str("text")))

        case "encode_base64":
            return .success(toolName, Data(str("text").utf8).base64EncodedString())

        case "decode_base64":
            guard let data    = Data(base64Encoded: str("text")),
                  let decoded = String(data: data, encoding: .utf8) else {
                return .failure(toolName, "Invalid Base64 input")
            }
            return .success(toolName, decoded)

        case "count_characters":
            return .success(toolName, "\(str("text").count) characters")

        case "reverse_string":
            return .success(toolName, String(str("text").reversed()))

        case "format_json":
            let raw = str("json")
            guard let data   = raw.data(using: .utf8),
                  let obj    = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
                  let result = String(data: pretty, encoding: .utf8) else {
                return .failure(toolName, "Invalid JSON input")
            }
            return .success(toolName, result)

        // ──────────────────────────────────────────────────────────────
        // MARK: Utilities
        // ──────────────────────────────────────────────────────────────

        case "calculate":
            let expr = str("expression")
            let nsExpr = NSExpression(format: expr)
            if let value = nsExpr.expressionValue(with: nil, context: nil) as? NSNumber {
                return .success(toolName, value.stringValue)
            }
            return .failure(toolName, "Cannot evaluate: \(expr)")

        case "generate_uuid":
            return .success(toolName, UUID().uuidString)

        case "current_datetime":
            let fmt = str("format").isEmpty ? "yyyy-MM-dd HH:mm:ss" : str("format")
            let df  = DateFormatter(); df.dateFormat = fmt
            return .success(toolName, df.string(from: Date()))

        case "generate_random_number":
            guard let lo = int("min"), let hi = int("max"), lo <= hi else {
                return .failure(toolName, "Invalid min/max values")
            }
            return .success(toolName, "\(Int.random(in: lo...hi))")

        case "validate_json":
            let raw = str("json")
            if let data = raw.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .success(toolName, "Valid JSON ✓")
            }
            return .success(toolName, "Invalid JSON ✗")

        case "hash_string":
            let hash = SHA256.hash(data: Data(str("text").utf8))
            let hex  = hash.map { String(format: "%02x", $0) }.joined()
            return .success(toolName, hex)

        case "url_encode":
            let encoded = str("text")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str("text")
            return .success(toolName, encoded)

        case "url_decode":
            return .success(toolName, str("text").removingPercentEncoding ?? str("text"))

        case "repeat_text":
            guard let count = int("count"), count >= 0 else {
                return .failure(toolName, "Invalid count parameter")
            }
            return .success(toolName, String(repeating: str("text"), count: count))

        // ──────────────────────────────────────────────────────────────
        // MARK: Project
        // ──────────────────────────────────────────────────────────────

        case "get_current_project":
            guard let p = projectManager.activeProject else {
                return .success(toolName, "No project is currently open")
            }
            return .success(toolName,
                "Project: \(p.name)\nDescription: \(p.description)\nFiles: \(p.fileCount)")

        case "list_projects":
            let names = projectManager.projects.map { "• \($0.name)" }
            return .success(toolName, names.isEmpty ? "No projects found" : names.joined(separator: "\n"))

        case "get_project_structure":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let tree = buildTree(at: project.directoryURL, base: project.directoryURL, indent: 0)
            return .success(toolName, tree.isEmpty ? "(empty project)" : tree)

        case "get_active_file":
            guard let node = projectManager.activeFileNode else {
                return .success(toolName, "No file open in editor")
            }
            return .success(toolName, "Name: \(node.name)\nPath: \(node.path)")

        case "read_active_file":
            guard projectManager.activeFileNode != nil else {
                return .failure(toolName, "No file is open in the editor")
            }
            return .success(toolName, projectManager.activeFileContent)

        case "write_active_file":
            guard let node = projectManager.activeFileNode else {
                return .failure(toolName, "No file is open in the editor")
            }
            let content = str("content")
            projectManager.activeFileContent = content
            projectManager.saveCurrentFile(content: content)
            return .success(toolName, "Wrote \(content.count) characters to \(node.name)")

        case "get_file_count":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let count = countFiles(in: project.directoryURL)
            return .success(toolName, "\(count) file(s)")

        case "search_and_replace_project":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let find = str("find"); let replace = str("replace"); let ext = str("file_extension")
            var affected = 0
            replaceInProject(at: project.directoryURL,
                             find: find, replace: replace,
                             fileExtension: ext, affected: &affected)
            projectManager.refreshFileTree(for: project)
            return .success(toolName, "Replaced in \(affected) file(s)")

        // ──────────────────────────────────────────────────────────────
        // MARK: Dependency Tools
        // ──────────────────────────────────────────────────────────────

        case "install_dependency":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let name = str("name"); let url = str("url"); let version = str("version")
            let packageURL = project.directoryURL.appendingPathComponent("Package.swift")
            var content = (try? String(contentsOf: packageURL, encoding: .utf8)) ?? ""
            let entry = ".package(url: \"\(url)\", from: \"\(version)\")"
            if content.contains(url) {
                return .failure(toolName, "Dependency \(name) already exists")
            }
            if content.isEmpty {
                content = """
                // swift-tools-version: 5.9
                import PackageDescription

                let package = Package(
                    name: "\(project.name)",
                    platforms: [.iOS(.v17)],
                    dependencies: [
                        \(entry)
                    ],
                    targets: [
                        .executableTarget(name: "\(project.name)", path: "Sources")
                    ]
                )
                """
            } else if let range = content.range(of: "dependencies: [") {
                content.insert(contentsOf: "\n        \(entry),", at: range.upperBound)
            }
            try? content.write(to: packageURL, atomically: true, encoding: .utf8)
            projectManager.refreshFileTree(for: project)
            return .success(toolName, "Added dependency \(name) (\(version))")

        case "remove_dependency":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let name = str("name")
            let packageURL = project.directoryURL.appendingPathComponent("Package.swift")
            guard var content = try? String(contentsOf: packageURL, encoding: .utf8) else {
                return .failure(toolName, "Package.swift not found")
            }
            let pattern = #".*\.package\(url:.*\#(name).*\),?\n?"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                content = regex.stringByReplacingMatches(in: content, range: NSRange(content.startIndex..., in: content), withTemplate: "")
            }
            try? content.write(to: packageURL, atomically: true, encoding: .utf8)
            return .success(toolName, "Removed dependency \(name)")

        case "update_dependency":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let name = str("name"); let newVersion = str("new_version")
            let packageURL = project.directoryURL.appendingPathComponent("Package.swift")
            guard var content = try? String(contentsOf: packageURL, encoding: .utf8) else {
                return .failure(toolName, "Package.swift not found")
            }
            let pattern = #"(\.package\(url:.*\#(name).*from:\s*")([^"]+)(")"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                content = regex.stringByReplacingMatches(in: content, range: NSRange(content.startIndex..., in: content), withTemplate: "$1\(newVersion)$3")
            }
            try? content.write(to: packageURL, atomically: true, encoding: .utf8)
            return .success(toolName, "Updated \(name) to version \(newVersion)")

        // ──────────────────────────────────────────────────────────────
        // MARK: Build Tools
        // ──────────────────────────────────────────────────────────────

        case "trigger_workflow":
            return .success(toolName, "Workflow trigger requested. Use GitHub integration to dispatch workflows.")

        case "check_workflow_status":
            return .success(toolName, "Use the Build Status panel to check workflow status.")

        case "get_build_logs":
            return .success(toolName, "Use the Build Logs panel to view detailed build logs.")

        // ──────────────────────────────────────────────────────────────
        // MARK: Search Tools
        // ──────────────────────────────────────────────────────────────

        case "search_codebase":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let query = str("query")
            var matches: [String] = []
            searchFiles(in: project.directoryURL, base: project.directoryURL, query: query, results: &matches)
            if matches.isEmpty { return .success(toolName, "No results found for '\(query)'") }
            let output = matches.prefix(30).joined(separator: "\n")
            return .success(toolName, "Found \(matches.count) result(s):\n\(output)")

        case "locate_function":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let name = str("name")
            let pattern = "func \(name)"
            var matches: [String] = []
            searchFiles(in: project.directoryURL, base: project.directoryURL, query: pattern, results: &matches)
            if matches.isEmpty { return .success(toolName, "Function '\(name)' not found") }
            let output = matches.joined(separator: "\n")
            return .success(toolName, output)

        case "find_references":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let symbol = str("symbol")
            var matches: [String] = []
            searchFiles(in: project.directoryURL, base: project.directoryURL, query: symbol, results: &matches)
            if matches.isEmpty { return .success(toolName, "No references found for '\(symbol)'") }
            let output = matches.prefix(50).joined(separator: "\n")
            return .success(toolName, "Found \(matches.count) reference(s):\n\(output)")

        case "analyze_symbols":
            guard let project = projectManager.activeProject else {
                return .failure(toolName, "No project is currently open")
            }
            let path = str("path")
            let url = project.directoryURL.appendingPathComponent(path)
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return .failure(toolName, "Cannot read file: \(path)")
            }
            let symbols = CodeIndexService.shared.indexFile(content: content, filePath: path)
            if symbols.isEmpty { return .success(toolName, "No symbols found in \(path)") }
            let output = symbols.map { "\($0.kind.rawValue) \($0.name) (line \($0.lineNumber))" }.joined(separator: "\n")
            return .success(toolName, "Symbols in \(path):\n\(output)")

        default:
            // Check if it's a user-defined custom tool from CustomToolRegistry
            if let connection = CustomToolRegistry.shared.connections.first(where: { $0.agentToolID == toolName }) {
                return await executeCustomConnection(connection, parameters: parameters)
            }
            return .failure(toolName, "Unknown tool: \(toolName)")
        }
    }

    // MARK: - Custom Tool Execution

    private func executeCustomConnection(
        _ connection: CustomAgentConnection,
        parameters: [String: Any]
    ) async -> AgentToolResult {
        guard !connection.apiEndpoint.isEmpty,
              let url = URL(string: connection.apiEndpoint) else {
            return .failure(connection.agentToolID, "Invalid or missing API endpoint for tool '\(connection.name)'")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            return .failure(connection.agentToolID,
                            "Tool '\(connection.name)' parameter serialization failed: \(error.localizedDescription)")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(connection.agentToolID, "Tool '\(connection.name)' returned a non-HTTP response")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                return .failure(connection.agentToolID,
                                "Tool '\(connection.name)' returned HTTP \(httpResponse.statusCode): \(body)")
            }
            let resultText = String(data: data, encoding: .utf8) ?? "(empty response)"
            return .success(connection.agentToolID, resultText)
        } catch {
            return .failure(connection.agentToolID, "Tool '\(connection.name)' request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func searchFiles(
        in dir: URL,
        base: URL,
        query: String,
        results: inout [String]
    ) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return }

        for url in items {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                searchFiles(in: url, base: base, query: query, results: &results)
            } else {
                let rel = url.path.replacingOccurrences(of: base.path + "/", with: "")
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    content.components(separatedBy: "\n").enumerated().forEach { (i, line) in
                        if line.localizedCaseInsensitiveContains(query) {
                            results.append("\(rel):\(i + 1): \(line.trimmingCharacters(in: .whitespaces))")
                        }
                    }
                }
            }
        }
    }

    private func findTodos(in dir: URL, base: URL, results: inout [String]) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return }

        for url in items {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                findTodos(in: url, base: base, results: &results)
            } else {
                let rel = url.path.replacingOccurrences(of: base.path + "/", with: "")
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    content.components(separatedBy: "\n").enumerated().forEach { (i, line) in
                        let upper = line.uppercased()
                        if upper.contains("TODO") || upper.contains("FIXME") || upper.contains("HACK") {
                            results.append("\(rel):\(i + 1): \(line.trimmingCharacters(in: .whitespaces))")
                        }
                    }
                }
            }
        }
    }

    private func extractSwiftSymbols(from content: String) -> [String] {
        let keywords = ["class ", "struct ", "enum ", "protocol ",
                        "func ", "extension ", "actor ", "typealias "]
        let accessMods = ["public ", "private ", "internal ", "open ", "final ",
                          "@MainActor ", "override "]
        return content.components(separatedBy: "\n")
            .enumerated()
            .compactMap { (i, rawLine) -> String? in
                var line = rawLine.trimmingCharacters(in: .whitespaces)
                for m in accessMods { line = line.hasPrefix(m) ? String(line.dropFirst(m.count)) : line }
                for kw in keywords where line.hasPrefix(kw) {
                    return "Line \(i + 1): \(rawLine.trimmingCharacters(in: .whitespaces))"
                }
                return nil
            }
    }

    private func buildTree(at url: URL, base: URL, indent: Int) -> String {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return "" }

        let prefix = String(repeating: "  ", count: indent)
        return items
            .filter { $0.lastPathComponent != "project.json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { item -> String in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir {
                    let sub = buildTree(at: item, base: base, indent: indent + 1)
                    let header = "\(prefix)📁 \(item.lastPathComponent)/"
                    return sub.isEmpty ? header : header + "\n" + sub
                }
                return "\(prefix)📄 \(item.lastPathComponent)"
            }
            .joined(separator: "\n")
    }

    private func countFiles(in dir: URL) -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return 0 }
        return items.reduce(0) { total, url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return total + (isDir ? countFiles(in: url) : 1)
        }
    }

    private func replaceInProject(
        at dir: URL,
        find: String,
        replace: String,
        fileExtension: String,
        affected: inout Int
    ) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return }

        for url in items {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                replaceInProject(at: url, find: find, replace: replace,
                                 fileExtension: fileExtension, affected: &affected)
            } else {
                if !fileExtension.isEmpty && url.pathExtension != fileExtension { continue }
                if var content = try? String(contentsOf: url, encoding: .utf8),
                   content.contains(find) {
                    content = content.replacingOccurrences(of: find, with: replace)
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                    affected += 1
                }
            }
        }
    }

    // MARK: - Code Generation Templates

    private func codeSwiftUIView(name: String, desc: String) -> String {
        """
        import SwiftUI

        struct \(name): View {
            var body: some View {
                VStack {
                    \(desc.isEmpty ? "Text(\"Hello, World!\")" : "// \(desc)")
                }
                .padding()
            }
        }

        #Preview {
            \(name)()
        }
        """
    }

    private func codeModel(name: String, properties: String) -> String {
        let props = properties
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { pair -> String? in
                let parts = pair.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return nil }
                return "    var \(parts[0]): \(parts[1])"
            }
            .joined(separator: "\n")
        let body = props.isEmpty ? "    var id: UUID = UUID()" : props
        return """
        import Foundation

        struct \(name): Codable, Identifiable {
        \(body)
        }
        """
    }

    private func codeViewModel(name: String, modelName: String) -> String {
        let hasModel = !modelName.isEmpty
        let extra = hasModel ? "    @Published var items: [\(modelName)] = []\n" : ""
        return """
        import Foundation
        import Combine

        @MainActor
        final class \(name): ObservableObject {
        \(extra)    @Published var isLoading = false
            @Published var errorMessage: String?

            func load() async {
                isLoading = true
                defer { isLoading = false }
                // TODO: Implement data loading
            }
        }
        """
    }

    private func codeService(name: String, desc: String) -> String {
        let comment = desc.isEmpty ? "Singleton service" : desc
        return """
        import Foundation

        // \(comment)
        final class \(name) {
            static let shared = \(name)()
            private init() {}

            // MARK: - Public Methods

            // TODO: Implement \(name) methods
        }
        """
    }

    private func codeUnitTests(typeName: String, methods: String) -> String {
        let list = methods
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let funcs: String
        if list.isEmpty {
            funcs = "    func testExample() {\n        XCTAssertTrue(true)\n    }\n"
        } else {
            funcs = list.map {
                let fn = "test" + $0.prefix(1).uppercased() + $0.dropFirst()
                return "    func \(fn)() {\n        // TODO: Test \(typeName).\($0)\n        XCTAssertTrue(true)\n    }"
            }.joined(separator: "\n\n") + "\n"
        }
        return """
        import XCTest
        @testable import YourModule

        final class \(typeName)Tests: XCTestCase {

        \(funcs)
            override func setUp() {
                super.setUp()
            }

            override func tearDown() {
                super.tearDown()
            }
        }
        """
    }

    private func codeEnum(name: String, cases: String, rawType: String) -> String {
        let caseLines = cases
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "    case \($0)" }
            .joined(separator: "\n")
        let inheritance = rawType.isEmpty ? "" : ": \(rawType)"
        return """
        enum \(name)\(inheritance) {
        \(caseLines.isEmpty ? "    // Add cases here" : caseLines)
        }
        """
    }

    private func codeProtocol(name: String, methods: String) -> String {
        let methodLines = methods
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "    func \($0)" }
            .joined(separator: "\n")
        return """
        protocol \(name) {
        \(methodLines.isEmpty ? "    // Add protocol requirements here" : methodLines)
        }
        """
    }

    private func codeExtension(typeName: String, desc: String) -> String {
        let comment = desc.isEmpty ? "MARK: - Additional functionality" : desc
        return """
        extension \(typeName) {
            // \(comment)
        }
        """
    }

    private func codeStruct(name: String, properties: String) -> String {
        let props = properties
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { pair -> String? in
                let parts = pair.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return nil }
                return "    var \(parts[0]): \(parts[1])"
            }
            .joined(separator: "\n")
        return """
        struct \(name) {
        \(props.isEmpty ? "    // Add properties here" : props)
        }
        """
    }

    private func codeAsyncFunction(name: String, returnType: String, params: String) -> String {
        let paramStr = params
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { pair -> String? in
                let parts = pair.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return nil }
                return "\(parts[0]): \(parts[1])"
            }
            .joined(separator: ", ")
        let ret = returnType == "Void" ? "" : " -> \(returnType)"
        return """
        func \(name)(\(paramStr)) async throws\(ret) {
            // TODO: Implement \(name)
        }
        """
    }

    // MARK: - Case Conversion

    private func toCamelCase(_ text: String) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard let first = words.first else { return text }
        return ([first.lowercased()] + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }).joined()
    }

    private func toPascalCase(_ text: String) -> String {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
    }

    private func toSnakeCase(_ text: String) -> String {
        var result = ""
        for (i, ch) in text.enumerated() {
            if ch.isUppercase && i > 0 { result += "_" }
            result += ch.lowercased()
        }
        return result
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}
