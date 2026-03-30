import Foundation

public struct AssistExplainCodeTool: AssistTool {
    public let id = "intel_explain_code"
    public let name = "Explain Code"
    public let description = "Provides a detailed explanation of the code at a path."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String else {
            return .failure("Missing required parameter: path")
        }

        do {
            let content = try context.fileSystem.readFile(at: path)
            let lines = content.components(separatedBy: .newlines)
            let functionCount = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("func ") }.count
            let typeCount = lines.filter {
                let t = $0.trimmingCharacters(in: .whitespaces)
                return t.hasPrefix("struct ") || t.hasPrefix("class ") || t.hasPrefix("enum ") || t.hasPrefix("protocol ")
            }.count
            let importCount = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }.count
            let controlFlowCount = AssistToolingSupport.keywordOccurrences(in: content, keywords: ["if ", "guard ", "switch ", "for ", "while "])

            let explanation = """
            File: \(path)
            Lines: \(lines.count)
            Imports: \(importCount)
            Type declarations: \(typeCount)
            Functions: \(functionCount)
            Control-flow constructs: \(controlFlowCount)
            Notes: This explanation is static analysis derived from source content in the sandbox.
            """

            return .success("Explanation generated for \(path)", data: ["explanation": explanation])
        } catch {
            return .failure("Failed to explain \(path): \(error.localizedDescription)")
        }
    }
}
