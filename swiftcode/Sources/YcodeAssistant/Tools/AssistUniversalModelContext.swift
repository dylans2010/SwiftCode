import Foundation

/// Provider-agnostic bridge that gives EVERY model (cloud, local, Codex, OpenCode,
/// Antigravity, ACP agents, Ollama, offline, Hermes, custom endpoints) access to the
/// SwiftCode tool registry and the System Assets training data.
///
/// - `augmentInstructions(_:)` idempotently appends the universal block to any
///   system prompt / instructions string.
/// - Models without native function calling request tools with a fenced
///   ```tool_call``` JSON block; `parseToolCalls(in:)` and `executeToolCalls(_:context:)`
///   run them against the real registry.
public enum AssistUniversalModelContext {

    public static let marker = "# SWIFTCODE UNIVERSAL TOOL ACCESS"

    public struct AssetDocument: Sendable {
        public let name: String
        public let text: String
        public let summary: String
    }

    public struct AssetHit: Sendable {
        public let document: String
        public let score: Int
        public let excerpt: String
    }

    public struct ToolCall: Sendable, Equatable {
        public let tool: String
        public let argumentsJSON: String
    }

    private struct ToolIndexEntry: Sendable {
        let id: String
        let capability: String
        let risk: String
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var toolIndex: [ToolIndexEntry] = []
    nonisolated(unsafe) private static var assetCache: [AssetDocument]?

    // MARK: - Tool index (kept in sync by AssistToolRegistry.register)

    public static func updateToolIndex(_ tools: [(id: String, capability: String, risk: String)]) {
        lock.lock(); defer { lock.unlock() }
        toolIndex = tools.map { ToolIndexEntry(id: $0.id, capability: $0.capability, risk: $0.risk) }
    }

    public static var registeredToolCount: Int {
        lock.lock(); defer { lock.unlock() }
        return toolIndex.count
    }

    /// Compact catalog: every registered tool id grouped by capability.
    public static func compactToolCatalog() -> String {
        lock.lock()
        let entries = toolIndex
        lock.unlock()
        guard !entries.isEmpty else { return "(tool registry not yet loaded — call tool_catalog_search)" }
        var groups: [String: [String]] = [:]
        for e in entries { groups[e.capability, default: []].append(e.risk == "safeRead" ? e.id : "\(e.id)*") }
        return groups.keys.sorted().map { "- \($0): " + groups[$0]!.sorted().joined(separator: ", ") }.joined(separator: "\n")
    }

    // MARK: - System Assets

    public static func systemAssetDirectories() -> [URL] {
        var dirs: [URL] = []
        let index = SystemIndexService.shared
        dirs.append(index.authoritativeAssetsDirectory())
        if let bundled = index.bundledAssetsURL() { dirs.append(bundled) }
        var seen = Set<String>()
        return dirs.filter { seen.insert($0.standardizedFileURL.path).inserted && FileManager.default.fileExists(atPath: $0.path) }
    }

    /// All System Assets markdown documents (runtime/custom copies win over bundled ones).
    public static func systemAssetDocuments(refresh: Bool = false) -> [AssetDocument] {
        lock.lock()
        if !refresh, let cached = assetCache { lock.unlock(); return cached }
        lock.unlock()
        var byName: [String: AssetDocument] = [:]
        for dir in systemAssetDirectories() {
            guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in e where url.pathExtension.lowercased() == "md" {
                let name = url.lastPathComponent
                guard byName[name] == nil, let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let summary = text.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("---") && !$0.hasPrefix("<!--") } ?? ""
                byName[name] = AssetDocument(name: name, text: text, summary: String(summary.prefix(140)))
            }
        }
        let docs = byName.values.sorted { $0.name < $1.name }
        lock.lock(); assetCache = docs; lock.unlock()
        return docs
    }

    public static func searchSystemAssets(query: String, limit: Int = 6) -> [AssetHit] {
        let terms = Set(query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 2 })
        guard !terms.isEmpty else { return [] }
        var hits: [AssetHit] = []
        for doc in systemAssetDocuments() {
            let nameLower = doc.name.lowercased()
            let nameBonus = terms.filter { nameLower.contains($0) }.count * 5
            for para in doc.text.components(separatedBy: "\n\n") where para.count > 40 {
                let lower = para.lowercased()
                var score = nameBonus
                for t in terms { score += lower.components(separatedBy: t).count - 1 }
                if score > nameBonus || (nameBonus > 0 && score > 0) {
                    hits.append(AssetHit(document: doc.name, score: score, excerpt: String(para.prefix(1200))))
                }
            }
        }
        hits.sort { $0.score > $1.score }
        var perDoc: [String: Int] = [:]
        return Array(hits.filter { perDoc[$0.document, default: 0] += 1; return perDoc[$0.document]! <= 2 }.prefix(limit))
    }

    // MARK: - Prompt augmentation

    public static let toolCallProtocol = """
    ## How to call SwiftCode tools (works for every model)
    If your runtime exposes native function calling, call tools natively by id.
    Otherwise request a tool by emitting exactly one fenced block per call and then STOP your turn:
    ```tool_call
    {"tool": "<tool_id>", "arguments": { ...parameters matching the tool schema... }}
    ```
    SwiftCode executes the call against the real workspace and replies with a `tool_result` block. Continue until the task is verified, then answer normally without tool_call blocks.
    Rules: read before you write; verify every change (build/test tools); never invent tool ids — use `tool_catalog_search` to find tools and their schemas; ids marked * mutate state or run processes.
    Training data: `system_asset_search` / `system_asset_read` return SwiftCode's System Assets guidance (coding, testing, user interaction, safety). Consult them before non-trivial work. `system_skill_catalog` lists installable skills.
    """

    /// The universal block appended to every model's instructions.
    public static func universalBlock(taskHint: String? = nil) -> String {
        let docs = systemAssetDocuments()
        var parts: [String] = [marker]
        parts.append("You are operating inside SwiftCode with \(max(registeredToolCount, 1)) registered native tools and \(docs.count) System Assets documents. These are available to you regardless of which provider or model you are.")
        let baseline = SystemIndexService.shared.baselinePrompt()
        if !baseline.isEmpty { parts.append("## Baseline behavior (System Assets)\n" + baseline) }
        if let hint = taskHint, !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let hits = searchSystemAssets(query: hint, limit: 4)
            if !hits.isEmpty {
                parts.append("## Relevant System Assets for this task\n" + hits.map { "### \($0.document)\n\($0.excerpt)" }.joined(separator: "\n\n"))
            }
        }
        parts.append("## System Assets documents\n" + docs.map { $0.name.replacingOccurrences(of: ".md", with: "") }.joined(separator: ", "))
        parts.append("## Registered tools by capability\n" + compactToolCatalog())
        parts.append(toolCallProtocol)
        return parts.joined(separator: "\n\n")
    }

    /// Compact variant for small-context models (on-device, small local models).
    public static func compactBlock(taskHint: String? = nil) -> String {
        var parts: [String] = [marker]
        parts.append("You run inside SwiftCode with \(max(registeredToolCount, 1)) native tools and \(systemAssetDocuments().count) System Assets guidance documents, available to every model.")
        if let hint = taskHint, let top = searchSystemAssets(query: hint, limit: 1).first {
            parts.append("Relevant guidance (\(top.document)): " + String(top.excerpt.prefix(600)))
        }
        parts.append(toolCallProtocol)
        return parts.joined(separator: "\n\n")
    }

    /// Appends the universal block once. Safe to call repeatedly on the same text.
    /// `contextTokens` below 16k selects the compact block.
    public static func augmentInstructions(_ instructions: String, taskHint: String? = nil, contextTokens: Int? = nil) -> String {
        if instructions.contains(marker) { return instructions }
        let compact = (contextTokens ?? Int.max) < 16_000
        let block = compact ? compactBlock(taskHint: taskHint) : universalBlock(taskHint: taskHint)
        return instructions.isEmpty ? block : instructions + "\n\n" + block
    }

    public static func augment(_ request: ChatRequest, compact: Bool = false) -> ChatRequest {
        var copy = request
        copy.instructions = augmentInstructions(request.instructions, taskHint: request.messages.last?.content, contextTokens: compact ? 4_096 : request.contextTokens)
        return copy
    }

    /// Injects the universal block into an `AIMessage` conversation (system message first).
    public static func augment(_ messages: [AIMessage]) -> [AIMessage] {
        var copy = messages
        let hint = messages.last(where: { $0.role == .user })?.content
        if let i = copy.firstIndex(where: { $0.role == .system }) {
            copy[i].content = augmentInstructions(copy[i].content, taskHint: hint)
        } else if !copy.contains(where: { $0.content.contains(marker) }) {
            copy.insert(AIMessage(role: .system, content: augmentInstructions("", taskHint: hint)), at: 0)
        }
        return copy
    }

    // MARK: - Text tool-call protocol

    public static func parseToolCalls(in text: String) -> [ToolCall] {
        guard text.contains("tool_call") else { return [] }
        let pattern = #"```tool_call\s*\n?([\s\S]*?)```"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let body = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let obj = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
                  let tool = (obj["tool"] ?? obj["name"]) as? String else { return nil }
            let args = (obj["arguments"] ?? obj["args"] ?? obj["parameters"]) ?? [String: Any]()
            let argsData = (try? JSONSerialization.data(withJSONObject: args, options: [.sortedKeys])) ?? Data("{}".utf8)
            return ToolCall(tool: tool, argumentsJSON: String(decoding: argsData, as: UTF8.self))
        }
    }

    /// Executes parsed calls against the live registry. Mutating/execution tools are
    /// only run when `allowMutations` is true (agent/turbo modes); otherwise the model
    /// is told the call was blocked so it can adapt.
    @MainActor
    public static func executeToolCalls(_ calls: [ToolCall], context: AssistContext, allowMutations: Bool) async -> String {
        var blocks: [String] = []
        for call in calls.prefix(8) {
            let registry = AssistToolRegistry.shared
            guard let tool = registry.allTools.first(where: { $0.id == call.tool }) ?? registry.allTools.first(where: { $0.id == call.tool.lowercased().replacingOccurrences(of: "-", with: "_") }) else {
                blocks.append("```tool_result\n{\"tool\": \"\(call.tool)\", \"ok\": false}\nUnknown tool id. Use tool_catalog_search to find the right tool.\n```")
                continue
            }
            if !allowMutations && !tool.isReadOnly {
                blocks.append("```tool_result\n{\"tool\": \"\(tool.id)\", \"ok\": false}\nBlocked: `\(tool.id)` mutates state or runs processes and the current mode is read-only. Ask the user to switch to Agent mode or describe the change instead.\n```")
                continue
            }
            let input = (try? JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any]) ?? [:]
            let result: AssistToolResult
            do { result = try await tool.execute(input: input, context: context) }
            catch { result = .failure(error.localizedDescription) }
            let text = AssistTextFormat.truncated(result.success ? result.output : (result.error ?? result.output), limit: 12_000).0
            blocks.append("```tool_result\n{\"tool\": \"\(tool.id)\", \"ok\": \(result.success)}\n\(text)\n```")
        }
        return blocks.joined(separator: "\n\n")
    }

    /// Generic multi-turn loop for any text-only model: sends `prompt`, executes any
    /// tool_call blocks, feeds results back, and returns the final answer.
    @MainActor
    public static func runTextToolLoop(
        initialPrompt: String,
        context: AssistContext,
        allowMutations: Bool,
        maxIterations: Int = 8,
        send: (String) async throws -> String
    ) async throws -> String {
        var transcript = initialPrompt
        var last = ""
        for _ in 0..<maxIterations {
            last = try await send(transcript)
            let calls = parseToolCalls(in: last)
            if calls.isEmpty { return last }
            let results = await executeToolCalls(calls, context: context, allowMutations: allowMutations)
            transcript += "\n\n<assistant>\n\(last)\n</assistant>\n\n<tool_results>\n\(results)\n</tool_results>\n\nContinue the task using these results."
        }
        return last
    }
}
