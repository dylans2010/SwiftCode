import Foundation

// MARK: - Toolbar Item

struct ToolbarTool: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let icon: String
    let category: String
    var isEnabled: Bool
    var order: Int

    static func == (lhs: ToolbarTool, rhs: ToolbarTool) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toolbar Manager

@MainActor
final class ToolbarManager: ObservableObject {
    static let shared = ToolbarManager()

    @Published var tools: [ToolbarTool] = []

    private static let storageKey = "com.swiftcode.toolbarTools"

    private init() {
        loadTools()
    }

    var enabledTools: [ToolbarTool] {
        tools.filter(\.isEnabled).sorted { $0.order < $1.order }
    }

    func toggleTool(id: String) {
        if let idx = tools.firstIndex(where: { $0.id == id }) {
            tools[idx].isEnabled.toggle()
            persist()
        }
    }

    func moveTool(from source: IndexSet, to destination: Int) {
        var enabled = enabledTools
        enabled.move(fromOffsets: source, toOffset: destination)
        for (i, tool) in enabled.enumerated() {
            if let idx = tools.firstIndex(where: { $0.id == tool.id }) {
                tools[idx].order = i
            }
        }
        persist()
    }

    func resetToDefaults() {
        tools = Self.defaultTools
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(tools) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func loadTools() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ToolbarTool].self, from: data),
           decoded.count == Self.defaultTools.count {
            tools = decoded
        } else {
            tools = Self.defaultTools
        }
    }

    // MARK: - Default 30 Tools

    static let defaultTools: [ToolbarTool] = [
        // 10 default enabled tools
        ToolbarTool(id: "code_search", name: "Code Search", icon: "magnifyingglass", category: "Navigation", isEnabled: true, order: 0),
        ToolbarTool(id: "ai_agent", name: "AI Agent", icon: "sparkles", category: "AI", isEnabled: true, order: 1),
        ToolbarTool(id: "errors_viewer", name: "Errors Viewer", icon: "exclamationmark.triangle.fill", category: "Diagnostics", isEnabled: true, order: 2),
        ToolbarTool(id: "dependency_manager", name: "Dependencies", icon: "shippingbox.fill", category: "Project", isEnabled: true, order: 3),
        ToolbarTool(id: "file_navigator", name: "File Navigator", icon: "folder.fill", category: "Navigation", isEnabled: true, order: 4),
        ToolbarTool(id: "build_trigger", name: "Build", icon: "hammer.fill", category: "Build", isEnabled: true, order: 5),
        ToolbarTool(id: "command_palette", name: "Command Palette", icon: "terminal.fill", category: "Tools", isEnabled: true, order: 6),
        ToolbarTool(id: "go_to_line", name: "Go to Line", icon: "arrow.right.to.line", category: "Navigation", isEnabled: true, order: 7),
        ToolbarTool(id: "symbol_navigator", name: "Symbol Navigator", icon: "list.bullet.indent", category: "Navigation", isEnabled: true, order: 8),
        ToolbarTool(id: "github_actions", name: "GitHub Actions", icon: "arrow.triangle.2.circlepath.circle.fill", category: "Git", isEnabled: true, order: 9),

        // 20 additional tools (disabled by default)
        ToolbarTool(id: "create_file", name: "Create File", icon: "doc.badge.plus", category: "File", isEnabled: false, order: 10),
        ToolbarTool(id: "create_folder", name: "Create Folder", icon: "folder.badge.plus", category: "File", isEnabled: false, order: 11),
        ToolbarTool(id: "rename_file", name: "Rename File", icon: "pencil", category: "File", isEnabled: false, order: 12),
        ToolbarTool(id: "delete_file", name: "Delete File", icon: "trash", category: "File", isEnabled: false, order: 13),
        ToolbarTool(id: "refactor_file", name: "Refactor File", icon: "arrow.triangle.2.circlepath", category: "Code", isEnabled: false, order: 14),
        ToolbarTool(id: "project_settings", name: "Project Settings", icon: "gearshape.fill", category: "Project", isEnabled: false, order: 15),
        ToolbarTool(id: "project_index", name: "Project Index", icon: "list.number", category: "Navigation", isEnabled: false, order: 16),
        ToolbarTool(id: "install_dependency", name: "Install Dependency", icon: "plus.square.fill", category: "Project", isEnabled: false, order: 17),
        ToolbarTool(id: "update_dependencies", name: "Update Dependencies", icon: "arrow.clockwise.square", category: "Project", isEnabled: false, order: 18),
        ToolbarTool(id: "diff_viewer", name: "Diff Viewer", icon: "arrow.left.arrow.right", category: "Git", isEnabled: false, order: 19),
        ToolbarTool(id: "ai_code_gen", name: "AI Code Generation", icon: "wand.and.stars", category: "AI", isEnabled: false, order: 20),
        ToolbarTool(id: "ai_code_fix", name: "AI Code Fix", icon: "wrench.and.screwdriver.fill", category: "AI", isEnabled: false, order: 21),
        ToolbarTool(id: "ai_refactor", name: "AI Refactor", icon: "arrow.triangle.branch", category: "AI", isEnabled: false, order: 22),
        ToolbarTool(id: "build_status", name: "Build Status", icon: "chart.bar.fill", category: "Build", isEnabled: false, order: 23),
        ToolbarTool(id: "commit_changes", name: "Commit Changes", icon: "checkmark.circle.fill", category: "Git", isEnabled: false, order: 24),
        ToolbarTool(id: "push_repo", name: "Push Repository", icon: "arrow.up.circle.fill", category: "Git", isEnabled: false, order: 25),
        ToolbarTool(id: "pull_repo", name: "Pull Repository", icon: "arrow.down.circle.fill", category: "Git", isEnabled: false, order: 26),
        ToolbarTool(id: "build_logs", name: "Build Logs", icon: "doc.text.magnifyingglass", category: "Build", isEnabled: false, order: 27),
        ToolbarTool(id: "minimap_settings", name: "Minimap Settings", icon: "map.fill", category: "Editor", isEnabled: false, order: 28),
        ToolbarTool(id: "project_analyzer", name: "Project Analyzer", icon: "waveform.path.ecg", category: "Diagnostics", isEnabled: false, order: 29),
    ]
}
