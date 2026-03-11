import SwiftUI

// MARK: - Main Toolbar View
//
// A compact, modern UI element providing quick access to all tools
// and frequent actions, positioned as a floating bar or bottom-docked.

struct MainToolbarView: View {
    @StateObject private var toolbarManager = ToolbarManager.shared
    @State private var showAllTools = false

    // Tools to show on the compact bar (pinned tools)
    private var pinnedTools: [ToolbarTool] {
        toolbarManager.enabledTools
    }

    var body: some View {
        HStack(spacing: 12) {
            // "All Tools" Button
            Button {
                showAllTools.toggle()
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.1))

            // Quick Access Pinned Tools
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(pinnedTools) { tool in
                        Button {
                            NotificationCenter.default.post(
                                name: .toolbarToolActivated,
                                object: nil,
                                userInfo: ["toolID": tool.id]
                            )
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(iconColor(for: tool.id))

                                Text(tool.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(minWidth: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
        .padding(.bottom, 20)
        .sheet(isPresented: $showAllTools) {
            ToolbarExpandedPanelView(isPresented: $showAllTools)
                .preferredColorScheme(.dark)
        }
    }

    private func iconColor(for toolId: String) -> Color {
        switch toolId {
        case "file_navigator", "create_file", "create_folder": return .orange
        case "ai_agent", "ai_code_gen", "ai_code_fix", "ai_refactor": return .purple
        case "github_actions", "commit_changes", "push_repo", "pull_repo",
             "git_history": return .blue
        case "build_trigger", "build_status", "build_logs", "terminal", "prepare_compile": return .orange
        case "errors_viewer": return .red
        case "dependency_manager", "install_dependency", "update_dependencies": return .teal
        case "code_search", "symbol_navigator", "project_index", "go_to_line",
             "symbol_outline": return .cyan
        case "sf_symbols_browser": return .indigo
        case "local_simulation": return .green
        case "plugin_manager": return .pink
        case "project_templates": return .mint
        case "file_preview": return .yellow
        default: return .secondary
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MainToolbarView()
    }
}
