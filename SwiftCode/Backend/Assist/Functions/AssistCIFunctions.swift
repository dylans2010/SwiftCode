import Foundation

public struct AssistCIFunctions {
    public struct PipelineValidationResult {
        public let pipelinesFound: Int
        public let valid: Int
        public let invalid: Int
        public let errors: [String]
        public let validPipelines: [String]
    }

    private struct ParsedPipeline {
        let name: String?
        let stepCount: Int
        let scriptCount: Int
    }

    public static func validateCIPipelines(workspaceRoot: URL) throws -> PipelineValidationResult {
        let ciDirectory = resolveCIDirectory(workspaceRoot: workspaceRoot)
        let yamlFiles = try FileManager.default.contentsOfDirectory(at: ciDirectory, includingPropertiesForKeys: nil)
            .filter { ["yml", "yaml"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var validCount = 0
        var errors: [String] = []
        var validPipelines: [String] = []

        for fileURL in yamlFiles {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let parsed = try parsePipeline(content: content)

                var pipelineErrors: [String] = []
                if (parsed.name?.isEmpty ?? true) {
                    pipelineErrors.append("missing key 'name'")
                }
                if parsed.stepCount == 0 {
                    pipelineErrors.append("missing key 'steps'")
                }
                if parsed.scriptCount == 0 {
                    pipelineErrors.append("missing key 'scripts' (no run/script commands)")
                }

                if pipelineErrors.isEmpty {
                    validCount += 1
                    validPipelines.append(fileURL.lastPathComponent)
                } else {
                    errors.append("\(fileURL.lastPathComponent): \(pipelineErrors.joined(separator: ", "))")
                }
            } catch {
                errors.append("\(fileURL.lastPathComponent): parse error - \(error.localizedDescription)")
            }
        }

        return PipelineValidationResult(
            pipelinesFound: yamlFiles.count,
            valid: validCount,
            invalid: max(0, yamlFiles.count - validCount),
            errors: errors,
            validPipelines: validPipelines
        )
    }

    private static func resolveCIDirectory(workspaceRoot: URL) -> URL {
        let candidates = [
            workspaceRoot.appendingPathComponent("SwiftCode/Backend/CI Building", isDirectory: true),
            workspaceRoot.appendingPathComponent("Backend/CI Building", isDirectory: true)
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        return candidates[0]
    }

    private static func parsePipeline(content: String) throws -> ParsedPipeline {
        let lines = content.components(separatedBy: .newlines)

        var name: String?
        var stepCount = 0
        var scriptCount = 0

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("name:"), name == nil {
                name = line.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if line.hasPrefix("- name:") || line.hasPrefix("- uses:") || line.hasPrefix("- run:") || line == "steps:" {
                if line.hasPrefix("-") {
                    stepCount += 1
                }
            }

            if line.contains("run:") || line.contains("script:") {
                scriptCount += 1
            }
        }

        return ParsedPipeline(name: name, stepCount: stepCount, scriptCount: scriptCount)
    }
}
