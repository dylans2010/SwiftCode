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

            return try await FileTool.shared.read(path: path)
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

return try FileTool.shared.write(path: path, content: content)
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

return try FileTool.shared.create(path: path, content: content)
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

return try FileTool.shared.delete(path: path)
        }

        ToolRegistry.shared.register(
            AgentTool(
                id: "transfer_project",
                displayName: "Transfer Project",
                description: "Transfer the active project to a nearby device",
                parameters: [
                    AgentToolParameter(name: "peerName", description: "Nearby peer display name"),
                    AgentToolParameter(name: "permissionPreset", description: "read-only, limited-edit, full-access or custom", required: false, defaultValue: "limited-edit")
                ],
                category: .project
            ),
            source: .core
        ) { parameters in
            guard let peerName = parameters["peerName"] as? String else {
                throw NSError(domain: "transfer_project", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'peerName' parameter"])
            }
            let presetRaw = (parameters["permissionPreset"] as? String) ?? TransferPermission.AccessPreset.limitedEdit.rawValue
            let preset = TransferPermission.AccessPreset(rawValue: presetRaw) ?? .limitedEdit
            return try await TransferTool.shared.transferCurrentProject(to: peerName, permission: .makePreset(preset))
        }
    }
}

