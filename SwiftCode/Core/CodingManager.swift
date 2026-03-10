import Foundation

/// Central manager for all project file operations.
/// The code editor and agent tools should use CodingManager instead of directly calling FileManager.
@MainActor
final class CodingManager: ObservableObject {
    static let shared = CodingManager()

    private let fm = FileManager.default

    // MARK: - Projects Directory

    /// Central project storage directory: Documents/Projects
    var projectsBaseDirectory: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Projects", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    // MARK: - Read

    /// Read file content as a string.
    func readFile(at relativePath: String, in projectDir: URL) throws -> String {
        let url = projectDir.appendingPathComponent(relativePath)
        let standardized = url.standardizedFileURL
        guard standardized.path.hasPrefix(projectDir.standardizedFileURL.path) else {
            throw CodingError.pathOutsideProject
        }
        return try String(contentsOf: standardized, encoding: .utf8)
    }

    /// Read file content asynchronously.
    nonisolated func readFileAsync(at relativePath: String, in projectDir: URL) async throws -> String {
        let url = projectDir.appendingPathComponent(relativePath).standardizedFileURL
        let projectStd = projectDir.standardizedFileURL
        guard url.path.hasPrefix(projectStd.path) else {
            throw CodingError.pathOutsideProject
        }
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw CodingError.encodingError
        }
        return content
    }

    // MARK: - Write

    /// Write content to a file, creating intermediate directories if needed.
    func writeFile(content: String, at relativePath: String, in projectDir: URL) throws {
        let url = projectDir.appendingPathComponent(relativePath)
        let standardized = url.standardizedFileURL
        guard standardized.path.hasPrefix(projectDir.standardizedFileURL.path) else {
            throw CodingError.pathOutsideProject
        }
        let parent = standardized.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try content.write(to: standardized, atomically: true, encoding: .utf8)
    }

    // MARK: - Create

    /// Create a new file with optional initial content.
    func createFile(named name: String, at directoryPath: String?, in projectDir: URL, content: String = "") throws {
        let base = directoryPath.map { projectDir.appendingPathComponent($0) } ?? projectDir
        let fileURL = base.appendingPathComponent(name)
        let standardized = fileURL.standardizedFileURL
        guard standardized.path.hasPrefix(projectDir.standardizedFileURL.path) else {
            throw CodingError.pathOutsideProject
        }
        guard !fm.fileExists(atPath: standardized.path) else {
            throw CodingError.alreadyExists
        }
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try content.write(to: standardized, atomically: true, encoding: .utf8)
    }

    /// Create a new directory.
    func createDirectory(named name: String, at directoryPath: String?, in projectDir: URL) throws {
        let base = directoryPath.map { projectDir.appendingPathComponent($0) } ?? projectDir
        let folderURL = base.appendingPathComponent(name)
        let standardized = folderURL.standardizedFileURL
        guard standardized.path.hasPrefix(projectDir.standardizedFileURL.path) else {
            throw CodingError.pathOutsideProject
        }
        try fm.createDirectory(at: standardized, withIntermediateDirectories: false)
    }

    // MARK: - Delete

    /// Delete a file or directory.
    func deleteItem(at relativePath: String, in projectDir: URL) throws {
        let url = projectDir.appendingPathComponent(relativePath)
        let standardized = url.standardizedFileURL
        guard standardized.path.hasPrefix(projectDir.standardizedFileURL.path) else {
            throw CodingError.pathOutsideProject
        }
        guard standardized != projectDir.standardizedFileURL else {
            throw CodingError.cannotDeleteRoot
        }
        try fm.removeItem(at: standardized)
    }

    // MARK: - Rename

    /// Rename a file or directory.
    func renameItem(at relativePath: String, to newName: String, in projectDir: URL) throws {
        let oldURL = projectDir.appendingPathComponent(relativePath)
        let parentPath = (relativePath as NSString).deletingLastPathComponent
        let newRelative = parentPath.isEmpty ? newName : "\(parentPath)/\(newName)"
        let newURL = projectDir.appendingPathComponent(newRelative)

        let oldStd = oldURL.standardizedFileURL
        let newStd = newURL.standardizedFileURL
        let projStd = projectDir.standardizedFileURL

        guard oldStd.path.hasPrefix(projStd.path),
              newStd.path.hasPrefix(projStd.path) else {
            throw CodingError.pathOutsideProject
        }
        try fm.moveItem(at: oldStd, to: newStd)
    }

    // MARK: - Scan

    /// Scan the project directory and return a list of relative file paths.
    func scanProjectFiles(in projectDir: URL) -> [String] {
        var files: [String] = []
        guard let enumerator = fm.enumerator(
            at: projectDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return files }

        let basePath = projectDir.standardizedFileURL.path
        while let url = enumerator.nextObject() as? URL {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            if isFile {
                let relative = url.standardizedFileURL.path.replacingOccurrences(of: basePath + "/", with: "")
                if relative != "project.json" {
                    files.append(relative)
                }
            }
        }
        return files.sorted()
    }

    // MARK: - File Existence

    func fileExists(at relativePath: String, in projectDir: URL) -> Bool {
        let url = projectDir.appendingPathComponent(relativePath)
        return fm.fileExists(atPath: url.standardizedFileURL.path)
    }
}

// MARK: - Errors

enum CodingError: LocalizedError {
    case pathOutsideProject
    case alreadyExists
    case cannotDeleteRoot
    case encodingError
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .pathOutsideProject: return "Path is outside the project directory."
        case .alreadyExists: return "A file with that name already exists."
        case .cannotDeleteRoot: return "Cannot delete the project root directory."
        case .encodingError: return "Failed to decode file content as UTF-8."
        case .fileNotFound: return "File not found."
        }
    }
}
