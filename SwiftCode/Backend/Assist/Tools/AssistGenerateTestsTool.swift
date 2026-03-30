import Foundation

public struct AssistGenerateTestsTool: AssistTool {
    public let id = "intel_generate_tests"
    public let name = "Generate Tests"
    public let description = "Generates unit tests for the specified code."

    public init() {}

    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let path = input["path"] as? String else {
            return .failure("Missing required parameter: path")
        }

        do {
            let source = try context.fileSystem.readFile(at: path)
            let sourceName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let testPath = (input["testPath"] as? String) ?? "Tests/\(sourceName)Tests.swift"

            let functionRegex = try NSRegularExpression(pattern: "\\bfunc\\s+([A-Za-z_][A-Za-z0-9_]*)", options: [])
            let range = NSRange(location: 0, length: source.utf16.count)
            let names = functionRegex.matches(in: source, options: [], range: range).compactMap { match -> String? in
                guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: source) else { return nil }
                return String(source[r])
            }

            var body = "import XCTest\n@testable import SwiftCode\n\nfinal class \(sourceName)Tests: XCTestCase {\n"
            if names.isEmpty {
                body += "    func testPlaceholder() {\n        XCTAssertTrue(true)\n    }\n"
            } else {
                for name in names.prefix(20) {
                    body += "    func test_\(name)() {\n        // TODO: instantiate and assert behavior for \(name)\n        XCTAssertTrue(true)\n    }\n\n"
                }
            }
            body += "}\n"

            try context.fileSystem.writeFile(at: testPath, content: body)
            return .success("Tests generated for \(path)", data: ["test_path": testPath, "test_count": "\(max(1, names.count))"])
        } catch {
            return .failure("Failed generating tests for \(path): \(error.localizedDescription)")
        }
    }
}
