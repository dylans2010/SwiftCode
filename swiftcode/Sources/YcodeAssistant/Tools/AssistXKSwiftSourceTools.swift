// Expansion toolkit: SwiftSource. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKSwiftListTypesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_types" }
    public var name: String { "List Swift Types" }
    public var description: String { "Lists every struct, class, enum, protocol and actor declared under `path` with file:line and signature." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists every struct, class, enum, protocol and actor declared under `path` with file:line and signature.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Types", input: input, context: context, kinds: ["struct", "class", "enum", "protocol", "actor"])
    }
}


public struct XKSwiftListStructsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_structs" }
    public var name: String { "List Swift Structs" }
    public var description: String { "Lists struct declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists struct declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Structs", input: input, context: context, kinds: ["struct"])
    }
}


public struct XKSwiftListClassesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_classes" }
    public var name: String { "List Swift Classes" }
    public var description: String { "Lists class declarations under `path` (excludes `class func`/`class var`)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists class declarations under `path` (excludes `class func`/`class var`).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Classes", input: input, context: context, kinds: ["class"])
    }
}


public struct XKSwiftListEnumsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_enums" }
    public var name: String { "List Swift Enums" }
    public var description: String { "Lists enum declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists enum declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Enums", input: input, context: context, kinds: ["enum"])
    }
}


public struct XKSwiftListProtocolsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_protocols" }
    public var name: String { "List Swift Protocols" }
    public var description: String { "Lists protocol declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists protocol declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Protocols", input: input, context: context, kinds: ["protocol"])
    }
}


public struct XKSwiftListActorsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_actors" }
    public var name: String { "List Swift Actors" }
    public var description: String { "Lists actor declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists actor declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Actors", input: input, context: context, kinds: ["actor"])
    }
}


public struct XKSwiftListExtensionsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_extensions" }
    public var name: String { "List Swift Extensions" }
    public var description: String { "Lists extension declarations under `path` (what types are extended, where)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists extension declarations under `path` (what types are extended, where).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Extensions", input: input, context: context, kinds: ["extension"])
    }
}


public struct XKSwiftListFunctionsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_functions" }
    public var name: String { "List Swift Functions" }
    public var description: String { "Lists function declarations under `path` with signatures." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists function declarations under `path` with signatures.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Functions", input: input, context: context, kinds: ["func"])
    }
}


public struct XKSwiftListInitializersTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_initializers" }
    public var name: String { "List Swift Initializers" }
    public var description: String { "Lists init declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists init declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Initializers", input: input, context: context, kinds: ["init"])
    }
}


public struct XKSwiftListTypealiasesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_typealiases" }
    public var name: String { "List Swift Typealiases" }
    public var description: String { "Lists typealias declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists typealias declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Typealiases", input: input, context: context, kinds: ["typealias"])
    }
}


public struct XKSwiftListEnumCasesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_enum_cases" }
    public var name: String { "List Swift Enum Cases" }
    public var description: String { "Lists enum `case` declarations under `path` (switch `case` labels are excluded by the declaration pattern only when indented as members)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists enum `case` declarations under `path` (switch `case` labels are excluded by the declaration pattern only when indented as members).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Enum Cases", input: input, context: context, kinds: ["case"], filter: { d in !d.signature.hasSuffix(":") })
    }
}


public struct XKSwiftListPropertiesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_properties" }
    public var name: String { "List Swift Properties" }
    public var description: String { "Lists var/let property declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists var/let property declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Properties", input: input, context: context, kinds: ["var", "let"])
    }
}


public struct XKSwiftListPublicApiTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_public_api" }
    public var name: String { "List Public API" }
    public var description: String { "Lists public and open declarations under `path` — the module's API surface." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists public and open declarations under `path` — the module's API surface.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Public API", input: input, context: context, kinds: ["struct", "class", "enum", "protocol", "actor", "func", "init", "var", "let", "typealias"], filter: { d in d.signature.hasPrefix("public ") || d.signature.hasPrefix("open ") || d.signature.contains(" public ") || d.signature.contains(" open ") })
    }
}


public struct XKSwiftListAsyncFunctionsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_async_functions" }
    public var name: String { "List Async Functions" }
    public var description: String { "Lists functions declared `async` under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists functions declared `async` under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Async Functions", input: input, context: context, kinds: ["func"], filter: { d in d.signature.contains(" async") })
    }
}


public struct XKSwiftListThrowingFunctionsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_throwing_functions" }
    public var name: String { "List Throwing Functions" }
    public var description: String { "Lists functions declared `throws`/`rethrows` under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists functions declared `throws`/`rethrows` under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Throwing Functions", input: input, context: context, kinds: ["func"], filter: { d in d.signature.contains("throws") || d.signature.contains("rethrows") })
    }
}


public struct XKSwiftListStaticMembersTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_static_members" }
    public var name: String { "List Static Members" }
    public var description: String { "Lists static functions and properties under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists static functions and properties under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Static Members", input: input, context: context, kinds: ["func", "var", "let"], filter: { d in d.signature.contains("static ") })
    }
}


public struct XKSwiftListOverridesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_overrides" }
    public var name: String { "List Overrides" }
    public var description: String { "Lists `override` declarations under `path` (subclass customization points)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists `override` declarations under `path` (subclass customization points).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Overrides", input: input, context: context, kinds: ["func", "var", "init"], filter: { d in d.signature.contains("override ") })
    }
}


public struct XKSwiftListPrivateMembersTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_private_members" }
    public var name: String { "List Private Members" }
    public var description: String { "Lists private/fileprivate declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists private/fileprivate declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Private Members", input: input, context: context, kinds: ["func", "var", "let", "struct", "class", "enum"], filter: { d in d.signature.contains("private ") })
    }
}


public struct XKSwiftListMacrosTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_macros" }
    public var name: String { "List Swift Macros" }
    public var description: String { "Lists macro declarations under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists macro declarations under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Swift Macros", input: input, context: context, kinds: ["macro"])
    }
}


public struct XKSwiftListMutatingFunctionsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_mutating_functions" }
    public var name: String { "List Mutating Functions" }
    public var description: String { "Lists `mutating` methods under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists `mutating` methods under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "name_contains": JSONSchema(type: "string", description: "Optional case-insensitive filter on declaration names."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.declarationResult(title: "List Mutating Functions", input: input, context: context, kinds: ["func"], filter: { d in d.signature.contains("mutating ") })
    }
}


public struct XKSwiftListSwiftuiViewsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_swiftui_views" }
    public var name: String { "List SwiftUI Views" }
    public var description: String { "Lists types conforming to SwiftUI `View` under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists types conforming to SwiftUI `View` under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.scanResult(title: "List SwiftUI Views", guidance: "Each reusable view should have a #Preview and accessibility labels.", input: input, context: context, pattern: "(struct|class)\\s+\\w+\\s*(<[^>]*>)?\\s*:\\s*[^{]*\\bView\\b")
    }
}


public struct XKSwiftListTestFunctionsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_test_functions" }
    public var name: String { "List Test Functions" }
    public var description: String { "Lists XCTest `func test…` methods and Swift Testing `@Test` functions under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists XCTest `func test…` methods and Swift Testing `@Test` functions under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.scanResult(title: "List Test Functions", guidance: "Run targeted tests with test_run / swift test --filter.", input: input, context: context, pattern: "func\\s+test\\w*\\s*\\(|@Test\\b")
    }
}


public struct XKSwiftListCodableTypesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_codable_types" }
    public var name: String { "List Codable Types" }
    public var description: String { "Lists types that declare Codable/Encodable/Decodable conformance under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists types that declare Codable/Encodable/Decodable conformance under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.scanResult(title: "List Codable Types", guidance: "Check CodingKeys and decoding error handling.", input: input, context: context, pattern: "(struct|class|enum)\\s+\\w+[^{]*\\b(Codable|Encodable|Decodable)\\b")
    }
}


public struct XKSwiftListSendableTypesTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_sendable_types" }
    public var name: String { "List Sendable Types" }
    public var description: String { "Lists types that declare Sendable conformance under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists types that declare Sendable conformance under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        return AssistToolKit.scanResult(title: "List Sendable Types", guidance: "Classes marked Sendable must be final with immutable state or synchronization.", input: input, context: context, pattern: "(struct|class|enum|actor)\\s+\\w+[^{]*\\bSendable\\b")
    }
}


public struct XKSwiftListImportsTool: AssistTool {
    public init() {}
    public var id: String { "swift_list_imports" }
    public var name: String { "Swift Import Inventory" }
    public var description: String { "Counts `import` statements per module across Swift files under `path` and lists files per module (optionally only `module`)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts `import` statements per module across Swift files under `path` and lists files per module (optionally only `module`).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "module": JSONSchema(type: "string", description: "Only show files importing this module.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        let only = AssistToolKit.string(input, "module")
        var byModule: [String: [String]] = [:]
        for f in AssistToolKit.files(at: root, extensions: ["swift"]) {
            for l in (AssistToolKit.read(f) ?? "").components(separatedBy: .newlines) {
                let t = l.trimmingCharacters(in: .whitespaces)
                guard let r = t.range(of: #"^(@\w+\s+)*import\s+(class\s+|struct\s+|func\s+|enum\s+|protocol\s+)?([\w.]+)"#, options: .regularExpression) else { continue }
                let mod = String(t[r].split(separator: " ").last ?? "").split(separator: ".").first.map(String.init) ?? ""
                byModule[mod, default: []].append(AssistToolKit.relative(f, context))
            }
        }
        if let only { let files = byModule[only] ?? []; return .success(files.isEmpty ? "No files import \(only)." : files.joined(separator: "\n"), data: ["count": String(files.count)]) }
        return .success(byModule.sorted { $0.value.count > $1.value.count }.map { "\($0.value.count)\t\($0.key)" }.joined(separator: "\n"), data: ["modules": String(byModule.count)])
    }
}


public struct XKSwiftFindConformersTool: AssistTool {
    public init() {}
    public var id: String { "swift_find_conformers" }
    public var name: String { "Find Protocol Conformers" }
    public var description: String { "Finds types and extensions that adopt `protocol_name` (in their inheritance clause) under `path`." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds types and extensions that adopt `protocol_name` (in their inheritance clause) under `path`.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "protocol_name": JSONSchema(type: "string", description: "Protocol or superclass name."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: ["protocol_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let p = AssistToolKit.string(input, "protocol_name"), !p.isEmpty else { return AssistToolKit.missing("protocol_name") }
        let pat = #"(struct|class|enum|actor|extension)\s+[\w.]+(<[^>]*>)?\s*:\s*[^{]*\b"# + NSRegularExpression.escapedPattern(for: p) + #"\b"#
        return AssistToolKit.scanResult(title: "Conformers of \(p)", guidance: "These types must satisfy every requirement of \(p).", input: input, context: context, pattern: pat)
    }
}


public struct XKSwiftSymbolReferencesTool: AssistTool {
    public init() {}
    public var id: String { "swift_symbol_references" }
    public var name: String { "Symbol References" }
    public var description: String { "Finds whole-word references to `symbol` across Swift files under `path` (excluding comment lines)." }
    public var capability: ToolCapability { .repositoryDiscovery }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Finds whole-word references to `symbol` across Swift files under `path` (excluding comment lines).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "symbol": JSONSchema(type: "string", description: "Identifier to search."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: ["symbol"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let s = AssistToolKit.string(input, "symbol"), !s.isEmpty else { return AssistToolKit.missing("symbol") }
        return AssistToolKit.scanResult(title: "References to \(s)", guidance: "Update every reference when renaming or changing the signature.", input: input, context: context, pattern: "\\b" + NSRegularExpression.escapedPattern(for: s) + "\\b")
    }
}


public struct XKSwiftFileOutlineTool: AssistTool {
    public init() {}
    public var id: String { "swift_file_outline" }
    public var name: String { "Swift File Outline" }
    public var description: String { "Produces an indented outline (types, extensions, functions, properties, cases) of a Swift file using brace depth." }
    public var capability: ToolCapability { .fileReading }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Produces an indented outline (types, extensions, functions, properties, cases) of a Swift file using brace depth.", properties: ["path": JSONSchema(type: "string", description: "Swift file path.")], required: ["path"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "path") else { return AssistToolKit.missing("path") }
        guard let url = AssistWorkspacePaths.resolve(raw, workspaceRoot: context.workspaceRoot), let src = AssistToolKit.read(url) else { return AssistToolKit.notFound("File not found: \(raw)") }
        let re = try NSRegularExpression(pattern: #"^\s*(?:@[\w().:, "]+\s+)*(?:(?:public|private|fileprivate|internal|open|package|final|static|class|override|mutating|nonisolated|indirect|convenience|required|lazy|weak)\s+)*(struct|class|enum|protocol|actor|extension|func|init|var|let|case|typealias)\b"#)
        var depth = 0; var out: [String] = []
        for (i, l) in src.components(separatedBy: .newlines).enumerated() {
            if depth <= 3, re.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) != nil {
                var sig = l.trimmingCharacters(in: .whitespaces); if let b = sig.firstIndex(of: "{") { sig = String(sig[..<b]).trimmingCharacters(in: .whitespaces) }
                out.append(String(repeating: "  ", count: depth) + "\(i + 1): \(sig.prefix(160))")
            }
            var inStr = false
            for c in l { if c == "\"" { inStr.toggle() } else if !inStr { if c == "{" { depth += 1 } else if c == "}" { depth = max(0, depth - 1) } } }
        }
        return .success(out.isEmpty ? "No declarations found." : AssistToolKit.output(out.joined(separator: "\n")), data: ["entries": String(out.count)])
    }
}


public struct XKSwiftUndocumentedPublicApiTool: AssistTool {
    public init() {}
    public var id: String { "swift_undocumented_public_api" }
    public var name: String { "Undocumented Public API" }
    public var description: String { "Lists public/open declarations under `path` that have no `///` or `/** */` doc comment directly above them." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists public/open declarations under `path` that have no `///` or `/** */` doc comment directly above them.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let root = AssistToolKit.resolve(input, context: context) else { return AssistToolKit.invalid("Path must be inside the workspace.") }
        let limit = AssistToolKit.int(input, "max_results", default: 300)
        var out: [String] = []; var total = 0
        for f in AssistToolKit.files(at: root, extensions: ["swift"]) {
            let lines = (AssistToolKit.read(f) ?? "").components(separatedBy: .newlines)
            for (i, l) in lines.enumerated() {
                let t = l.trimmingCharacters(in: .whitespaces)
                guard t.range(of: #"^(@\w+(\([^)]*\))?\s+)*(public|open)\s+.*\b(func|var|let|struct|class|enum|protocol|actor|init|typealias|case)\b"#, options: .regularExpression) != nil else { continue }
                total += 1
                var j = i - 1
                while j >= 0, lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("@") { j -= 1 }
                let prev = j >= 0 ? lines[j].trimmingCharacters(in: .whitespaces) : ""
                if !(prev.hasPrefix("///") || prev.hasSuffix("*/")) { if out.count < limit { out.append("\(AssistToolKit.relative(f, context)):\(i + 1): \(t.prefix(140))") } }
            }
        }
        let pct = total == 0 ? 100 : (total - out.count) * 100 / total
        return .success("public declarations: \(total), undocumented: \(out.count), coverage: \(pct)%\n" + AssistToolKit.output(out.joined(separator: "\n")), data: ["coverage": String(pct)])
    }
}


public struct XKSwiftGenerateMemberwiseInitTool: AssistTool {
    public init() {}
    public var id: String { "swift_generate_memberwise_init" }
    public var name: String { "Generate Memberwise Initializer" }
    public var description: String { "Reads the real stored properties of `type_name` and generates an explicit (optionally public) memberwise initializer, respecting default values. Returns code; does not write." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Reads the real stored properties of `type_name` and generates an explicit (optionally public) memberwise initializer, respecting default values. Returns code; does not write.", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze."), "public": JSONSchema(type: "boolean", description: "Emit a public initializer.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let props = AssistToolKit.storedProperties(of: loaded.body).filter { !($0.isLet && $0.defaultValue != nil) }
        guard !props.isEmpty else { return AssistToolKit.invalid("\(typeName) has no initializable stored properties.") }
        let access = AssistToolKit.bool(input, "public", default: false) ? "public " : ""
        let params = props.map { "\($0.name): \($0.type.isEmpty ? "<#Type#>" : $0.type)\($0.defaultValue.map { " = " + $0 } ?? ($0.type.hasSuffix("?") ? " = nil" : ""))" }
        let code = "\(access)init(\(params.joined(separator: ", "))) {\n" + props.map { "    self.\($0.name) = \($0.name)" }.joined(separator: "\n") + "\n}"
        return .success("// \(loaded.kind) \(typeName) in \(loaded.path)\n" + code, data: ["properties": String(props.count)])
    }
}


public struct XKSwiftGenerateCodingKeysTool: AssistTool {
    public init() {}
    public var id: String { "swift_generate_coding_keys" }
    public var name: String { "Generate CodingKeys" }
    public var description: String { "Generates a CodingKeys enum for the stored properties of `type_name`, mapping camelCase to snake_case when `snake_case` is true (default)." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates a CodingKeys enum for the stored properties of `type_name`, mapping camelCase to snake_case when `snake_case` is true (default).", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze."), "snake_case": JSONSchema(type: "boolean", description: "Map to snake_case keys.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let props = AssistToolKit.storedProperties(of: loaded.body)
        guard !props.isEmpty else { return AssistToolKit.invalid("\(typeName) has no stored properties.") }
        let snake = AssistToolKit.bool(input, "snake_case", default: true)
        let cases = props.map { p -> String in let s = AssistToolKit.words(p.name).map { $0.lowercased() }.joined(separator: "_"); return snake && s != p.name ? "    case \(p.name) = \"\(s)\"" : "    case \(p.name)" }
        return .success("enum CodingKeys: String, CodingKey {\n" + cases.joined(separator: "\n") + "\n}")
    }
}


public struct XKSwiftGenerateEquatableHashableTool: AssistTool {
    public init() {}
    public var id: String { "swift_generate_equatable_hashable" }
    public var name: String { "Generate Equatable/Hashable" }
    public var description: String { "Generates explicit Equatable `==` and Hashable `hash(into:)` implementations over the stored properties of `type_name`." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates explicit Equatable `==` and Hashable `hash(into:)` implementations over the stored properties of `type_name`.", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let props = AssistToolKit.storedProperties(of: loaded.body)
        guard !props.isEmpty else { return AssistToolKit.invalid("\(typeName) has no stored properties.") }
        let eq = props.map { "lhs.\($0.name) == rhs.\($0.name)" }.joined(separator: "\n            && ")
        let hash = props.map { "        hasher.combine(\($0.name))" }.joined(separator: "\n")
        return .success("extension \(typeName): Hashable {\n    static func == (lhs: \(typeName), rhs: \(typeName)) -> Bool {\n        \(eq)\n    }\n\n    func hash(into hasher: inout Hasher) {\n\(hash)\n    }\n}")
    }
}


public struct XKSwiftGenerateProtocolFromTypeTool: AssistTool {
    public init() {}
    public var id: String { "swift_generate_protocol_from_type" }
    public var name: String { "Extract Protocol From Type" }
    public var description: String { "Generates a protocol declaring the non-private method signatures and stored/computed property requirements of `type_name`, for dependency injection and test doubles." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates a protocol declaring the non-private method signatures and stored/computed property requirements of `type_name`, for dependency injection and test doubles.", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze."), "protocol_name": JSONSchema(type: "string", description: "Name for the generated protocol.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let sigs = AssistToolKit.functionSignatures(of: loaded.body).filter { !$0.contains("private ") && !$0.contains("static ") }
            .map { $0.replacingOccurrences(of: #"\b(public|open|internal|final|override|nonisolated|@discardableResult)\s+"#, with: "", options: .regularExpression) }
        let props = AssistToolKit.storedProperties(of: loaded.body).map { "    var \($0.name): \($0.type.isEmpty ? "<#Type#>" : $0.type) { get\($0.isLet ? "" : " set") }" }
        let name = AssistToolKit.string(input, "protocol_name") ?? typeName + "Protocol"
        let code = "protocol \(name)\(loaded.kind == "actor" ? ": Actor" : (loaded.kind == "class" ? ": AnyObject" : "")) {\n" + (props + sigs.map { "    " + $0 }).joined(separator: "\n") + "\n}\n\nextension \(typeName): \(name) {}"
        return .success(code, data: ["requirements": String(props.count + sigs.count)])
    }
}


public struct XKSwiftGenerateTestSkeletonTool: AssistTool {
    public init() {}
    public var id: String { "swift_generate_test_skeleton" }
    public var name: String { "Generate Test Skeleton" }
    public var description: String { "Generates a Swift Testing (default) or XCTest suite for `type_name` with one test per real method found, each with Arrange/Act/Assert sections the agent must fill with real assertions." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates a Swift Testing (default) or XCTest suite for `type_name` with one test per real method found, each with Arrange/Act/Assert sections the agent must fill with real assertions.", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze."), "module": JSONSchema(type: "string", description: "Module under test for @testable import."), "framework": JSONSchema(type: "string", description: "swift-testing (default) or xctest.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let sigs = AssistToolKit.functionSignatures(of: loaded.body).filter { !$0.contains("private ") }
        let names = sigs.compactMap { s -> String? in guard let r = s.range(of: #"func\s+([A-Za-z_]\w*)"#, options: .regularExpression) else { return nil }; return String(s[r].dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        let module = AssistToolKit.string(input, "module") ?? "<#Module#>"
        let xctest = (AssistToolKit.string(input, "framework") ?? "swift-testing").lowercased() == "xctest"
        var out: [String] = []
        if xctest {
            out.append("import XCTest\n@testable import \(module)\n\nfinal class \(typeName)Tests: XCTestCase {")
            for n in names { out.append("    func test_\(n)() throws {\n        // Arrange: construct \(typeName) with real inputs\n        // Act: call \(n)\n        // Assert: XCTAssertEqual(actual, expected)\n    }\n") }
        } else {
            out.append("import Testing\n@testable import \(module)\n\n@Suite struct \(typeName)Tests {")
            for n in names { out.append("    @Test func \(n)Behaves() async throws {\n        // Arrange: construct \(typeName) with real inputs\n        // Act: call \(n)\n        // Assert: #expect(actual == expected)\n    }\n") }
        }
        out.append("}")
        return .success("// Methods discovered in \(loaded.path): \(names.joined(separator: ", "))\n" + out.joined(separator: "\n"), data: ["tests": String(names.count)])
    }
}


public struct XKSwiftTypeSummaryTool: AssistTool {
    public init() {}
    public var id: String { "swift_type_summary" }
    public var name: String { "Swift Type Summary" }
    public var description: String { "Summarizes `type_name`: kind, inheritance clause, stored properties with types, method signatures, and nested type count, read from source." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Summarizes `type_name`: kind, inheritance clause, stored properties with types, method signatures, and nested type count, read from source.", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let props = AssistToolKit.storedProperties(of: loaded.body)
        let sigs = AssistToolKit.functionSignatures(of: loaded.body)
        let nested = AssistToolKit.topLevelLines(of: loaded.body).filter { $0.range(of: #"\b(struct|class|enum|actor)\s+\w+"#, options: .regularExpression) != nil }.count
        var lines = ["\(loaded.header)  (\(loaded.path))", "stored properties (\(props.count)):"]
        lines += props.map { "  \($0.isLet ? "let" : "var") \($0.name): \($0.type.isEmpty ? "(inferred)" : $0.type)\($0.defaultValue.map { " = " + $0 } ?? "")" }
        lines.append("methods (\(sigs.count)):"); lines += sigs.map { "  " + $0 }
        lines.append("nested types: \(nested)")
        return .success(AssistToolKit.output(lines.joined(separator: "\n")))
    }
}


public struct XKSwiftGenerateBuilderTool: AssistTool {
    public init() {}
    public var id: String { "swift_generate_builder" }
    public var name: String { "Generate Builder" }
    public var description: String { "Generates a fluent builder type for `type_name` from its stored properties (useful for constructing complex values in tests with real values)." }
    public var capability: ToolCapability { .planning }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates a fluent builder type for `type_name` from its stored properties (useful for constructing complex values in tests with real values).", properties: ["path": JSONSchema(type: "string", description: "Swift file or directory containing the type."), "type_name": JSONSchema(type: "string", description: "Type name to analyze.")], required: ["path", "type_name"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let loaded: (path: String, kind: String, header: String, body: String)
        switch AssistToolKit.loadType(input, context: context) {
        case .success(let v): loaded = v
        case .failure(let e): return AssistToolKit.notFound(e.message)
        }
        let typeName = AssistToolKit.string(input, "type_name") ?? ""
        let props = AssistToolKit.storedProperties(of: loaded.body).filter { !($0.isLet && $0.defaultValue != nil) && !$0.type.isEmpty }
        guard !props.isEmpty else { return AssistToolKit.invalid("\(typeName) has no typed stored properties.") }
        var out = ["struct \(typeName)Builder {"]
        out += props.map { "    private var \($0.name): \($0.type.hasSuffix("?") ? $0.type : $0.type + "?")" }
        out.append("")
        for p in props { let base = p.type.hasSuffix("?") ? String(p.type.dropLast()) : p.type; out.append("    func \(p.name)(_ value: \(base)) -> Self { var c = self; c.\(p.name) = value; return c }") }
        out.append("\n    func build() throws -> \(typeName) {")
        for p in props where !p.type.hasSuffix("?") { out.append("        guard let \(p.name) else { throw BuilderError.missing(\"\(p.name)\") }") }
        out.append("        return \(typeName)(" + props.map { "\($0.name): \($0.name)" }.joined(separator: ", ") + ")\n    }\n\n    enum BuilderError: Error { case missing(String) }\n}")
        return .success(out.joined(separator: "\n"))
    }
}
