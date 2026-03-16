import Foundation

// MARK: - Codebase Index Models

struct CodebaseFile: Codable {
    let path: String
    let name: String
    let size: Int
    let fileType: String
    let preview: String? // Optional preview of file contents (first few lines)
}

struct CodebaseDirectory: Codable {
    let path: String
    let name: String
    let fileCount: Int
    let subdirectories: Int
}

struct CodebaseIndex: Codable {
    let rootPath: String
    let totalFiles: Int
    let totalDirectories: Int
    let files: [CodebaseFile]
    let directories: [CodebaseDirectory]
    let scannedAt: Date
    let swiftFileCount: Int
    let otherFileCount: Int
}

// MARK: - List Files Tool

@MainActor
final class ListFilesTool {
    static let shared = ListFilesTool()
    private init() {}

    private var cachedIndex: CodebaseIndex?
    private var lastScanTime: Date?
    private static let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Public API

    /// Scan the entire repository and return a structured codebase index
    func scanRepository(at rootPath: String? = nil, includePreview: Bool = false, maxPreviewLines: Int = 5) async throws -> CodebaseIndex {
        // Use cached index if available and valid
        if let cached = cachedIndex,
           let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < Self.cacheValidityDuration {
            return cached
        }

        let projectRoot: URL
        if let customPath = rootPath {
            projectRoot = URL(fileURLWithPath: customPath)
        } else if let activeProject = ProjectManager.shared.activeProject {
            projectRoot = activeProject.directoryURL
        } else {
            throw ListFilesError.noActiveProject
        }

        guard FileManager.default.fileExists(atPath: projectRoot.path) else {
            throw ListFilesError.pathNotFound(projectRoot.path)
        }

        var files: [CodebaseFile] = []
        var directories: [CodebaseDirectory] = []

        try await scanDirectory(
            at: projectRoot,
            relativeTo: projectRoot,
            files: &files,
            directories: &directories,
            includePreview: includePreview,
            maxPreviewLines: maxPreviewLines
        )

        let swiftCount = files.filter { $0.fileType == "swift" }.count
        let otherCount = files.count - swiftCount

        let index = CodebaseIndex(
            rootPath: projectRoot.path,
            totalFiles: files.count,
            totalDirectories: directories.count,
            files: files.sorted { $0.path < $1.path },
            directories: directories.sorted { $0.path < $1.path },
            scannedAt: Date(),
            swiftFileCount: swiftCount,
            otherFileCount: otherCount
        )

        // Cache the result
        cachedIndex = index
        lastScanTime = Date()

        return index
    }

    /// Invalidate the cached index, forcing a fresh scan on next call
    func invalidateCache() {
        cachedIndex = nil
        lastScanTime = nil
    }

    /// Get a simplified file list (paths only) for the agent
    func getFileList(at rootPath: String? = nil) async throws -> [String] {
        let index = try await scanRepository(at: rootPath, includePreview: false)
        return index.files.map { $0.path }
    }

    /// Get directory structure
    func getDirectoryStructure(at rootPath: String? = nil) async throws -> [String] {
        let index = try await scanRepository(at: rootPath, includePreview: false)
        return index.directories.map { $0.path }
    }

    // MARK: - Private Helpers

    private func scanDirectory(
        at url: URL,
        relativeTo base: URL,
        files: inout [CodebaseFile],
        directories: inout [CodebaseDirectory],
        includePreview: Bool,
        maxPreviewLines: Int
    ) async throws {
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for itemURL in contents {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            let relativePath = itemURL.path.replacingOccurrences(of: base.path + "/", with: "")

            // Skip common directories that shouldn't be scanned
            let skipDirs = [".git", "node_modules", "build", "Build", ".build", "DerivedData", "Pods", ".xcodeproj", ".xcworkspace"]
            if isDirectory && skipDirs.contains(itemURL.lastPathComponent) {
                continue
            }

            if isDirectory {
                // Count files and subdirectories in this directory
                let (fileCount, subdirCount) = await countContents(at: itemURL)

                directories.append(CodebaseDirectory(
                    path: relativePath,
                    name: itemURL.lastPathComponent,
                    fileCount: fileCount,
                    subdirectories: subdirCount
                ))

                // Recursively scan subdirectory
                try await scanDirectory(
                    at: itemURL,
                    relativeTo: base,
                    files: &files,
                    directories: &directories,
                    includePreview: includePreview,
                    maxPreviewLines: maxPreviewLines
                )
            } else {
                // Skip certain file types
                let skipExtensions = ["xcuserstate", "xcbkptlist", "xcscheme", "pbxproj", "storyboard", "xib"]
                let ext = itemURL.pathExtension.lowercased()
                if skipExtensions.contains(ext) {
                    continue
                }

                let fileSize = resourceValues?.fileSize ?? 0
                let fileType = ext.isEmpty ? "unknown" : ext

                var preview: String?
                if includePreview && fileSize < 100_000 { // Only preview files < 100KB
                    preview = try? await readFilePreview(at: itemURL, maxLines: maxPreviewLines)
                }

                files.append(CodebaseFile(
                    path: relativePath,
                    name: itemURL.lastPathComponent,
                    size: fileSize,
                    fileType: fileType,
                    preview: preview
                ))
            }
        }
    }

    private func countContents(at url: URL) async -> (files: Int, directories: Int) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        var fileCount = 0
        var dirCount = 0

        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                dirCount += 1
            } else {
                fileCount += 1
            }
        }

        return (fileCount, dirCount)
    }

    private func readFilePreview(at url: URL, maxLines: Int) async throws -> String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }

        let lines = content.components(separatedBy: .newlines).prefix(maxLines)
        return lines.joined(separator: "\n")
    }
}

// MARK: - Errors

enum ListFilesError: LocalizedError {
    case noActiveProject
    case pathNotFound(String)
    case scanFailed(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProject:
            return "No active project found. Please open a project first."
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .scanFailed(let reason):
            return "Failed to scan repository: \(reason)"
        }
    }
}
