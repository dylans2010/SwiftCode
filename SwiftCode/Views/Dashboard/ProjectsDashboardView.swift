import SwiftUI
import UniformTypeIdentifiers

struct ProjectsDashboardView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var settings: AppSettings
    @State private var showCreationSheet = false
    @State private var showNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var showImportPicker = false
    @State private var showGitHubImportSheet = false
    @State private var githubImportURL = ""
    @State private var showRenameSheet = false
    @State private var projectToRename: Project?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedProject: Project?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showSettings = false
    @State private var isImporting = false

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 20)]
    }

    private var sortedProjects: [Project] {
        switch settings.dashboardSortOrder {
        case .name:
            return projectManager.projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastOpened:
            return projectManager.projects.sorted { $0.lastOpened > $1.lastOpened }
        case .creationDate:
            return projectManager.projects.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.07, blue: 0.12),
                        Color(red: 0.10, green: 0.10, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if projectManager.projects.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        if settings.dashboardLayout == .grid {
                            LazyVGrid(columns: gridColumns, spacing: 20) {
                                ForEach(sortedProjects) { project in
                                    ProjectCardView(project: project, showIcon: settings.showProjectIcons)
                                        .onTapGesture { projectManager.openProject(project) }
                                        .contextMenu { contextMenu(for: project) }
                                }
                            }
                            .padding()
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(sortedProjects) { project in
                                    ProjectListRowView(project: project, showIcon: settings.showProjectIcons, showPreview: settings.showFolderPreview)
                                        .onTapGesture { projectManager.openProject(project) }
                                        .contextMenu { contextMenu(for: project) }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showCreationSheet) { creationOptionsSheet }
            .sheet(isPresented: $showNewProjectSheet) { newProjectSheet }
            .sheet(isPresented: $showImportPicker) {
                FileImporterRepresentableView(
                    allowedContentTypes: [UTType.zip],
                    allowsMultipleSelection: false
                ) { urls in
                    showImportPicker = false
                    if let url = urls.first {
                        handleZipImport(.success([url]))
                    }
                }
            }
            .sheet(isPresented: $showGitHubImportSheet) { gitHubImportSheet }
            .sheet(isPresented: $showRenameSheet) { renameSheet }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showSettings) {
                GeneralSettingsView()
                    .environmentObject(AppSettings.shared)
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "swift")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                )
            Text("No Projects Yet")
                .font(.title2).bold()
                .foregroundStyle(.white)
            Text("Create a new project, import a zip archive,\nor clone from GitHub to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    showCreationSheet = true
                } label: {
                    Label("New Project", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.orange.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showCreationSheet = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
        }
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
            }
        }
    }

    // MARK: - Creation Options Sheet

    private var creationOptionsSheet: some View {
        NavigationStack {
            List {
                Button {
                    showCreationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showNewProjectSheet = true
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create New Project")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Generate a default SwiftUI project structure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "plus.rectangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                    }
                }

                Button {
                    showCreationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showImportPicker = true
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import From ZIP")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Extract a ZIP archive into a new project")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "archivebox.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                }

                Button {
                    showCreationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showGitHubImportSheet = true
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import From GitHub")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Download a repository archive from GitHub")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.purple)
                            .font(.title3)
                    }
                }
            }
            .navigationTitle("Create Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreationSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - GitHub Import Sheet

    private var gitHubImportSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Repository URL")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("https://github.com/owner/repo", text: $githubImportURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)

                if isImporting {
                    ProgressView("Importing repository...")
                        .padding()
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Import From GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        githubImportURL = ""
                        showGitHubImportSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importFromGitHub()
                    }
                    .disabled(githubImportURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func contextMenu(for project: Project) -> some View {
        Button {
            projectToRename = project
            renameText = project.name
            showRenameSheet = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            Task {
                do { _ = try await MainActor.run { try projectManager.duplicateProject(project) } }
                catch { showError(error) }
            }
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Button {
            exportProject(project)
        } label: {
            Label("Export As ZIP", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            Task {
                do { try await MainActor.run { try projectManager.deleteProject(project) } }
                catch { showError(error) }
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var newProjectSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "swift")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Name")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("Project App Name", text: $newProjectName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newProjectName = ""
                        showNewProjectSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var renameSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Name")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("Project Name", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Rename Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRenameSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename") { renameProject() }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let project = try projectManager.createProject(name: name)
            newProjectName = ""
            showNewProjectSheet = false
            projectManager.openProject(project)
        } catch {
            newProjectName = ""
            showNewProjectSheet = false
            showError(error)
        }
    }

    private func importFromGitHub() {
        let url = githubImportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        isImporting = true
        Task {
            do {
                let project = try await GitHubImporter.shared.importRepository(from: url)
                await MainActor.run {
                    isImporting = false
                    githubImportURL = ""
                    showGitHubImportSheet = false
                    projectManager.openProject(project)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    showGitHubImportSheet = false
                    showError(error)
                }
            }
        }
    }

    private func renameProject() {
        guard let project = projectToRename else { return }
        do {
            try projectManager.renameProject(project, to: renameText)
            showRenameSheet = false
        } catch {
            showRenameSheet = false
            showError(error)
        }
    }

    private func handleZipImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    let project = try await ZipImporter.shared.importZip(at: url)
                    await MainActor.run { projectManager.openProject(project) }
                } catch {
                    await MainActor.run { showError(error) }
                }
            }
        case .failure(let error):
            showError(error)
        }
    }

    private func exportProject(_ project: Project) {
        Task {
            do {
                let url = try await ZipImporter.shared.exportZip(for: project)
                await MainActor.run {
                    exportURL = url
                    showShareSheet = true
                }
            } catch {
                await MainActor.run { showError(error) }
            }
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - Project List Row (for list layout)

struct ProjectListRowView: View {
    let project: Project
    var showIcon: Bool = true
    var showPreview: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if showIcon {
                Image(systemName: "swift")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 32)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.caption2)
                        Text("\(project.fileCount) File\(project.fileCount == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(project.lastOpened, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if showPreview, let firstFile = project.files.first(where: { !$0.isDirectory }) {
                    Text(firstFile.name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Project Card

struct ProjectCardView: View {
    let project: Project
    var showIcon: Bool = true
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showIcon {
                    Image(systemName: "swift")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(project.lastOpened, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                    Text("\(project.fileCount) File\(project.fileCount == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(height: 140)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(0.3), radius: isHovered ? 16 : 8, y: 4)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
