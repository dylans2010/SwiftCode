import Foundation

/// Initializes the Agent system and registers all core tools
@MainActor
final class AgentSystemInitializer {
    static let shared = AgentSystemInitializer()
    private var isInitialized = false

    private init() {}

    func initialize() {
        guard !isInitialized else { return }

        // Load and register tools from managers
        AgentToolsManager.shared.loadAndRegisterTools()

        // Register critical core tools
        registerCoreTools()

        isInitialized = true

        print("[AgentSystem] Agent runtime initialized with tools from Core, Skills, and Connections.")
    }

    private func registerCoreTools() {
        // Register list_files tool
        ToolRegistry.shared.register(
            AgentTool(
                id: "list_files",
                displayName: "List Files",
                description: "List all files in the repository or a specific directory",
                parameters: [
                    AgentToolParameter(
                        name: "path",
                        description: "Optional path to scan, defaults to project root",
                        required: false,
                        defaultValue: ""
                    )
                ],
                category: .fileSystem
            ),
            source: .core
        ) { parameters in
            let path = parameters["path"] as? String
            let pathToScan = path?.isEmpty == false ? path : nil

            let index = try await ListFilesTool.shared.scanRepository(at: pathToScan)
            let fileList = index.files.prefix(50).map { $0.path }.joined(separator: "\n")

            return """
            Repository scan complete:
            - Total files: \(index.totalFiles)
            - Total directories: \(index.totalDirectories)
            - Swift files: \(index.swiftFileCount)
            - Other files: \(index.otherFileCount)

            Files (showing first 50):
            \(fileList)
            """
        }

        // Register read_file tool
        ToolRegistry.shared.register(
            AgentTool(
                id: "read_file",
                displayName: "Read File",
                description: "Read the contents of a file",
                parameters: [
                    AgentToolParameter(
                        name: "path",
                        description: "Relative path to the file"
                    )
                ],
                category: .fileSystem
            ),
            source: .core
        ) { parameters in
            guard let path = parameters["path"] as? String else {
                throw NSError(domain: "read_file", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' parameter"])
            }

            guard let project = ProjectManager.shared.activeProject else {
                throw NSError(domain: "read_file", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active project"])
            }

            let content = try await CodeReaderManager.shared.readFileAsync(project: project.name, relativePath: path)
            return content
        }

        // Register write_file tool
        ToolRegistry.shared.register(
            AgentTool(
                id: "write_file",
                displayName: "Write File",
                description: "Write or overwrite the contents of a file",
                parameters: [
                    AgentToolParameter(
                        name: "path",
                        description: "Relative path to the file"
                    ),
                    AgentToolParameter(
                        name: "content",
                        description: "Content to write to the file"
                    )
                ],
                category: .fileSystem
            ),
            source: .core
        ) { parameters in
            guard let path = parameters["path"] as? String,
                  let content = parameters["content"] as? String else {
                throw NSError(domain: "write_file", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing required parameters"])
            }

            guard let project = ProjectManager.shared.activeProject else {
                throw NSError(domain: "write_file", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active project"])
            }

            // First, read the original content if file exists
            let originalContent = (try? await CodeReaderManager.shared.readFileAsync(project: project.name, relativePath: path)) ?? ""

            // Write the file
            try CodingManager.shared.writeFile(content: content, at: path, in: project.directoryURL)

            // Create a patch for review
            CodePatchEngine.shared.createPatch(
                filePath: path,
                originalContent: originalContent,
                modifiedContent: content
            )

            return "File written successfully: \(path)"
        }

        // Register create_file tool
        ToolRegistry.shared.register(
            AgentTool(
                id: "create_file",
                displayName: "Create File",
                description: "Create a new file with optional content",
                parameters: [
                    AgentToolParameter(
                        name: "path",
                        description: "Relative path for the new file"
                    ),
                    AgentToolParameter(
                        name: "content",
                        description: "Initial content for the file",
                        required: false,
                        defaultValue: ""
                    )
                ],
                category: .fileSystem
            ),
            source: .core
        ) { parameters in
            guard let path = parameters["path"] as? String else {
                throw NSError(domain: "create_file", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' parameter"])
            }

            let content = parameters["content"] as? String ?? ""

            guard let project = ProjectManager.shared.activeProject else {
                throw NSError(domain: "create_file", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active project"])
            }

            let fileURL = project.directoryURL.appendingPathComponent(path)
            let directory = fileURL.deletingLastPathComponent()

            // Create directory if needed
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Write the file
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            // Refresh project file tree
            ProjectManager.shared.refreshFileTree(for: project)

            return "File created successfully: \(path)"
        }

        // Register delete_file tool
        ToolRegistry.shared.register(
            AgentTool(
                id: "delete_file",
                displayName: "Delete File",
                description: "Delete a file from the project",
                parameters: [
                    AgentToolParameter(
                        name: "path",
                        description: "Relative path to the file to delete"
                    )
                ],
                category: .fileSystem
            ),
            source: .core
        ) { parameters in
            guard let path = parameters["path"] as? String else {
                throw NSError(domain: "delete_file", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' parameter"])
            }

            guard let project = ProjectManager.shared.activeProject else {
                throw NSError(domain: "delete_file", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active project"])
            }

            try CodingManager.shared.deleteItem(at: path, in: project.directoryURL)

            // Refresh project file tree
            ProjectManager.shared.refreshFileTree(for: project)

            return "File deleted successfully: \(path)"
        }
    }
}

