import SwiftUI

// MARK: - Toolbar Minimized View
//
// A compact "^" button that lives in the toolbar and expands a popover
// showing ALL available toolbar tools so users can access them without
// pinning items to the toolbar.

struct ToolbarMinimizedView: View {
    @State private var isExpanded = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isExpanded, arrowEdge: .top) {
            ToolbarExpandedPanelView(isPresented: $isExpanded)
                .preferredColorScheme(.dark)
        }
        .help("Expand Toolbar")
    }
}

// MARK: - Expanded Panel

struct ToolbarExpandedPanelView: View {
    @Binding var isPresented: Bool

    private let toolGroups: [ToolGroup] = [
        ToolGroup(title: "File", tools: [
            ToolItem(id: "new_file",       icon: "doc.badge.plus",          label: "New File"),
            ToolItem(id: "new_folder",     icon: "folder.badge.plus",       label: "New Folder"),
            ToolItem(id: "save",           icon: "square.and.arrow.down",   label: "Save"),
            ToolItem(id: "save_all",       icon: "tray.and.arrow.down",     label: "Save All"),
        ]),
        ToolGroup(title: "Edit", tools: [
            ToolItem(id: "undo",           icon: "arrow.uturn.backward",    label: "Undo"),
            ToolItem(id: "redo",           icon: "arrow.uturn.forward",     label: "Redo"),
            ToolItem(id: "find",           icon: "magnifyingglass",         label: "Find"),
            ToolItem(id: "replace",        icon: "arrow.left.arrow.right",  label: "Find & Replace"),
            ToolItem(id: "format",         icon: "text.alignleft",          label: "Format Code"),
        ]),
        ToolGroup(title: "Build & Run", tools: [
            ToolItem(id: "build",          icon: "hammer.fill",             label: "Build"),
            ToolItem(id: "run",            icon: "play.fill",               label: "Run"),
            ToolItem(id: "stop",           icon: "stop.fill",               label: "Stop"),
            ToolItem(id: "clean",          icon: "trash",                   label: "Clean Build"),
        ]),
        ToolGroup(title: "Navigate", tools: [
            ToolItem(id: "jump_to_def",    icon: "arrow.right.to.line",     label: "Jump to Definition"),
            ToolItem(id: "back",           icon: "chevron.left",            label: "Back"),
            ToolItem(id: "forward",        icon: "chevron.right",           label: "Forward"),
            ToolItem(id: "open_quickly",   icon: "command",                 label: "Open Quickly"),
        ]),
        ToolGroup(title: "View", tools: [
            ToolItem(id: "toggle_files",   icon: "sidebar.left",            label: "Files"),
            ToolItem(id: "toggle_console", icon: "terminal",                label: "Console"),
            ToolItem(id: "minimap",        icon: "map",                     label: "Minimap"),
            ToolItem(id: "split_editor",   icon: "rectangle.split.2x1",    label: "Split Editor"),
        ]),
        ToolGroup(title: "Source Control", tools: [
            ToolItem(id: "commit",         icon: "checkmark.circle",        label: "Commit"),
            ToolItem(id: "push",           icon: "arrow.up.circle",         label: "Push"),
            ToolItem(id: "pull",           icon: "arrow.down.circle",       label: "Pull"),
            ToolItem(id: "branch",         icon: "arrow.triangle.branch",   label: "Branches"),
        ]),
        ToolGroup(title: "AI & Tools", tools: [
            ToolItem(id: "ai_chat",        icon: "message.fill",            label: "AI Chat"),
            ToolItem(id: "ai_complete",    icon: "sparkles",                label: "Complete"),
            ToolItem(id: "ai_review",      icon: "checkmark.seal",          label: "Code Review"),
            ToolItem(id: "extensions",     icon: "puzzlepiece.extension",   label: "Extensions"),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(toolGroups) { group in
                        groupSection(group)
                        Divider().opacity(0.15)
                    }
                }
            }
            .navigationTitle("All Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .frame(minWidth: 280, minHeight: 400)
    }

    private func groupSection(_ group: ToolGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                ForEach(group.tools) { tool in
                    toolButton(tool)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func toolButton(_ tool: ToolItem) -> some View {
        Button {
            // Tool actions are dispatched via NotificationCenter so any
            // editor or service that cares can respond.
            NotificationCenter.default.post(
                name: .toolbarToolActivated,
                object: nil,
                userInfo: ["toolID": tool.id]
            )
            isPresented = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                Text(tool.label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Model Types

    struct ToolGroup: Identifiable {
        let id = UUID()
        let title: String
        let tools: [ToolItem]
    }

    struct ToolItem: Identifiable {
        let id: String
        let icon: String
        let label: String
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let toolbarToolActivated = Notification.Name("com.swiftcode.toolbarToolActivated")
}
