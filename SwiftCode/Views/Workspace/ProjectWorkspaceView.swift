import SwiftUI

struct ProjectWorkspaceView: View {
    let project: Project
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showNavigatorSheet = false
    @State private var showAISheet = false
    @State private var showBuildStatus = false
    @State private var showGitHubSheet = false
    @State private var showSettingsSheet = false

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

                // Code Editor fills the full screen
                CodeEditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        // File Navigator sheet (medium or full height)
        .sheet(isPresented: $showNavigatorSheet) {
            NavigationStack {
                FileNavigatorView(project: project)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showNavigatorSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Auto-dismiss navigator when a file is selected
        .onChange(of: projectManager.activeFileNode) { newNode in
            if newNode != nil {
                showNavigatorSheet = false
            }
        }
        // AI Assistant sheet
        .sheet(isPresented: $showAISheet) {
            AIAssistantView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
        HStack(spacing: 10) {
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

            // File Navigator
            Button {
                showNavigatorSheet = true
            } label: {
                Image(systemName: "folder.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

            Text(project.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Build Status
            Button {
                showBuildStatus = true
            } label: {
                Image(systemName: "hammer.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.orange)
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

            // AI Assistant
            Button {
                showAISheet = true
            } label: {
                Image(systemName: "sparkles")
                    .imageScale(.medium)
                    .foregroundStyle(.purple)
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
        guard let repo = (projectManager.activeProject ?? project).githubRepo else { return "" }
        return String(repo.split(separator: "/").first ?? "")
    }

    private var repoNameFromRepo: String {
        guard let repo = (projectManager.activeProject ?? project).githubRepo else { return "" }
        return String(repo.split(separator: "/").last ?? "")
    }
}
