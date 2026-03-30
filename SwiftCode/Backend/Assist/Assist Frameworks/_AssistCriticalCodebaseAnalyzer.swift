import Foundation

/// [CRITICAL SYSTEM FILE] - HIGH RISK
/// Scans the project structure, analyzes dependencies, and identifies code quality issues.
public final class _AssistCriticalCodebaseAnalyzer {
    private let context: AssistContext

    public init(context: AssistContext) {
        self.context = context
    }

    /// Performs a full scan of the project and returns a summary of the architecture.
    public func analyze() throws -> CodebaseSummary {
        let root = context.workspaceRoot
        context.logger.info("Analyzing codebase at \(root.path)", toolId: "CodebaseAnalyzer")

        let allFiles = try scanDirectory(at: root)
        let swiftFiles = allFiles.filter { $0.hasSuffix(".swift") }

        return CodebaseSummary(
            totalFiles: allFiles.count,
            swiftFileCount: swiftFiles.count,
            structure: "Scanned \(allFiles.count) files across project tree."
        )
    }

    private func scanDirectory(at url: URL) throws -> [String] {
        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) else {
            return []
        }

        var files: [String] = []
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues.isRegularFile ?? false {
                files.append(fileURL.path)
            }
        }
        return files
    }
}

public struct CodebaseSummary {
    public let totalFiles: Int
    public let swiftFileCount: Int
    public let structure: String
}
