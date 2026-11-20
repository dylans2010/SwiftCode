// Expansion toolkit: Knowledge. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKSystemAssetListTool: AssistTool {
    public init() {}
    public var id: String { "system_asset_list" }
    public var name: String { "List System Assets" }
    public var description: String { "Lists every System Assets training/guidance document bundled with SwiftCode (plus user custom assets) with sizes. Every model can read them via system_asset_read." }
    public var capability: ToolCapability { .memory }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists every System Assets training/guidance document bundled with SwiftCode (plus user custom assets) with sizes. Every model can read them via system_asset_read.", properties: [:], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let docs = AssistUniversalModelContext.systemAssetDocuments()
        guard !docs.isEmpty else { return AssistToolKit.notFound("No System Assets were found in the app bundle.") }
        return .success("\(docs.count) System Assets documents:\n" + docs.map { "- \($0.name) (\($0.text.count) chars) — \($0.summary)" }.joined(separator: "\n"), data: ["count": String(docs.count)])
    }
}


public struct XKSystemAssetReadTool: AssistTool {
    public init() {}
    public var id: String { "system_asset_read" }
    public var name: String { "Read System Asset" }
    public var description: String { "Returns the full text of a System Assets document by `name` (e.g. `UnitTestingBestPractices` or `Authentication.md`). Use it to load the authoritative SwiftCode guidance for a task." }
    public var capability: ToolCapability { .memory }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Returns the full text of a System Assets document by `name` (e.g. `UnitTestingBestPractices` or `Authentication.md`). Use it to load the authoritative SwiftCode guidance for a task.", properties: ["name": JSONSchema(type: "string", description: "Document name with or without .md.")], required: ["name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let name = AssistToolKit.string(input, "name"), !name.isEmpty else { return AssistToolKit.missing("name") }
        let key = name.lowercased().replacingOccurrences(of: ".md", with: "")
        let docs = AssistUniversalModelContext.systemAssetDocuments()
        guard let doc = docs.first(where: { $0.name.lowercased().replacingOccurrences(of: ".md", with: "") == key }) ?? docs.first(where: { $0.name.lowercased().contains(key) }) else {
            return AssistToolKit.notFound("No System Asset named '\(name)'. Call system_asset_list or system_asset_search.") }
        return .success("# \(doc.name)\n\n" + AssistToolKit.output(doc.text, limit: 40000), data: ["name": doc.name])
    }
}


public struct XKSystemAssetSearchTool: AssistTool {
    public init() {}
    public var id: String { "system_asset_search" }
    public var name: String { "Search System Assets" }
    public var description: String { "Ranks System Assets documents and paragraphs by relevance to `query` (term frequency) and returns the best excerpts, so any model can pull SwiftCode training guidance on demand." }
    public var capability: ToolCapability { .memory }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Ranks System Assets documents and paragraphs by relevance to `query` (term frequency) and returns the best excerpts, so any model can pull SwiftCode training guidance on demand.", properties: ["query": JSONSchema(type: "string", description: "What guidance you need, e.g. 'keychain token storage'."), "limit": JSONSchema(type: "integer", description: "Max excerpts (default 6).")], required: ["query"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let q = AssistToolKit.string(input, "query"), !q.isEmpty else { return AssistToolKit.missing("query") }
        let hits = AssistUniversalModelContext.searchSystemAssets(query: q, limit: max(1, min(AssistToolKit.int(input, "limit", default: 6), 20)))
        guard !hits.isEmpty else { return AssistToolKit.notFound("No System Assets matched '\(q)'.") }
        return .success(hits.map { "## \($0.document) (score \($0.score))\n\($0.excerpt)" }.joined(separator: "\n\n"), data: ["count": String(hits.count)])
    }
}


public struct XKToolCatalogSearchTool: AssistTool {
    public init() {}
    public var id: String { "tool_catalog_search" }
    public var name: String { "Search Tool Catalog" }
    public var description: String { "Searches every registered SwiftCode tool by `query` (id, name, description) and returns matching ids with descriptions and parameter schemas, so models with compact catalogs can discover the right tool." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Searches every registered SwiftCode tool by `query` (id, name, description) and returns matching ids with descriptions and parameter schemas, so models with compact catalogs can discover the right tool.", properties: ["query": JSONSchema(type: "string", description: "Capability you need, e.g. 'git history of a file'."), "limit": JSONSchema(type: "integer", description: "Max tools (default 10).")], required: ["query"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let q = AssistToolKit.string(input, "query")?.lowercased(), !q.isEmpty else { return AssistToolKit.missing("query") }
        let terms = q.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 1 }
        let limit = max(1, min(AssistToolKit.int(input, "limit", default: 10), 40))
        var ranked: [(tool: AssistTool, score: Int)] = []
        for t in AssistToolRegistry.shared.allTools {
            let idWords: String = t.id.replacingOccurrences(of: "_", with: " ")
            let hay: String = (idWords + " " + t.name + " " + t.description).lowercased()
            var score = 0
            for term in terms where hay.contains(term) { score += t.id.contains(term) ? 3 : 1 }
            if score > 0 { ranked.append((tool: t, score: score)) }
        }
        ranked.sort { lhs, rhs in lhs.score == rhs.score ? lhs.tool.id < rhs.tool.id : lhs.score > rhs.score }
        let scored = Array(ranked.prefix(limit))
        guard !scored.isEmpty else { return AssistToolKit.notFound("No tools matched '\(q)'.") }
        let out = scored.map { entry -> String in
            let t = entry.tool
            let schema = (try? JSONEncoder().encode(t.parametersSchema)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
            return "- `\(t.id)` [\(t.riskLevel)] — \(t.description)\n  parameters: \(schema)" }
        return .success(out.joined(separator: "\n"), data: ["count": String(scored.count)])
    }
}


public struct XKSystemSkillCatalogTool: AssistTool {
    public init() {}
    public var id: String { "system_skill_catalog" }
    public var name: String { "System Skill Catalog" }
    public var description: String { "Lists SwiftCode System Skills (bundled SKILL.md playbooks) with install status, or returns one skill's full instructions when `name` is given." }
    public var capability: ToolCapability { .memory }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists SwiftCode System Skills (bundled SKILL.md playbooks) with install status, or returns one skill's full instructions when `name` is given.", properties: ["name": JSONSchema(type: "string", description: "Optional skill name to read.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let manager = SystemSkillInstallManager.shared
        let all = manager.availableSkills()
        if let name = AssistToolKit.string(input, "name"), !name.isEmpty {
            guard let s = all.first(where: { $0.name == name || $0.directoryName == name }) else { return AssistToolKit.notFound("No System Skill named '\(name)'.") }
            return .success(AssistToolKit.output(s.content, limit: 30000), data: ["installed": String(manager.isInstalled(s))])
        }
        return .success("\(all.count) System Skills (\(manager.installedCount()) installed):\n" + all.map { "- \($0.name) [\($0.category)]\(manager.isInstalled($0) ? " ✓" : "") — \($0.description)" }.joined(separator: "\n"), data: ["count": String(all.count)])
    }
}
