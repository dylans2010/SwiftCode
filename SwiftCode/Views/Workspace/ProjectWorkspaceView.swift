import SwiftUI

struct ProjectWorkspaceView: View {
    let project: Project
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showNavigator = true
    @State private var showAIAssistant = true
    @State private var showBuildStatus = false
    @State private var showGitHubSheet = false
    @State private var showSettingsSheet = false
    @State private var navigatorWidth: CGFloat = 240
    @State private var assistantWidth: CGFloat = 320
    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                workspaceToolbar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)

                Divider().opacity(0.3)

                // Main content
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // File Navigator
                        if showNavigator {
                            FileNavigatorView(project: project)
                                .frame(width: navigatorWidth)
                                .background(Color(red: 0.12, green: 0.12, blue: 0.16))

                            // Drag handle
                            ResizeDivider(isDragging: $isDraggingLeft) { delta in
                                navigatorWidth = max(180, min(400, navigatorWidth + delta))
                            }
                        }

                        // Code Editor
                        CodeEditorView()
                            .frame(maxWidth: .infinity)

                        // AI Assistant
                        if showAIAssistant {
                            // Drag handle
                            ResizeDivider(isDragging: $isDraggingRight) { delta in
                                assistantWidth = max(260, min(500, assistantWidth - delta))
                            }

                            AIAssistantView()
                                .frame(width: assistantWidth)
                                .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showBuildStatus) {
            BuildStatusView(owner: ownerFromRepo, repo: repoNameFromRepo)
        }
        .sheet(isPresented: $showGitHubSheet) {
            GitHubIntegrationView(project: project)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }

    // MARK: - Toolbar

    private var workspaceToolbar: some View {
        HStack(spacing: 8) {
            // Back
            Button {
                projectManager.closeProject()
            } label: {
                Image(systemName: "chevron.left")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 20)

            // Toggle Navigator
            Button {
                withAnimation(.spring(response: 0.3)) { showNavigator.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
                    .imageScale(.medium)
                    .foregroundStyle(showNavigator ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            Text(project.name)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            // Build
            Button {
                showBuildStatus = true
            } label: {
                Label("Build", systemImage: "hammer.fill")
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.orange.opacity(0.8), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            // GitHub
            Button {
                showGitHubSheet = true
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            // Toggle AI
            Button {
                withAnimation(.spring(response: 0.3)) { showAIAssistant.toggle() }
            } label: {
                Image(systemName: "sidebar.right")
                    .imageScale(.medium)
                    .foregroundStyle(showAIAssistant ? .purple : .secondary)
            }
            .buttonStyle(.plain)

            // Settings
            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var ownerFromRepo: String {
        guard let repo = project.githubRepo else { return "" }
        return String(repo.split(separator: "/").first ?? "")
    }

    private var repoNameFromRepo: String {
        guard let repo = project.githubRepo else { return "" }
        return String(repo.split(separator: "/").last ?? "")
    }
}

// MARK: - Resize Divider

struct ResizeDivider: View {
    @Binding var isDragging: Bool
    let onDrag: (CGFloat) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.blue.opacity(0.5) : Color.white.opacity(0.08))
            .frame(width: 4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        onDrag(value.translation.width)
                    }
                    .onEnded { _ in isDragging = false }
            )
            #if targetEnvironment(macCatalyst)
        .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
        #endif
    }
}
