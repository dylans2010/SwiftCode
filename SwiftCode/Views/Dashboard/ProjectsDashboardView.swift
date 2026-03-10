import SwiftUI
import UniformTypeIdentifiers

struct ProjectsDashboardView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var showImportPicker = false
    @State private var showRenameSheet = false
    @State private var projectToRename: Project?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedProject: Project?
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 20)
    ]

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
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(projectManager.projects) { project in
                                ProjectCardView(project: project)
                                    .onTapGesture { projectManager.openProject(project) }
                                    .contextMenu { contextMenu(for: project) }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("SwiftCode")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
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
            .sheet(isPresented: $showRenameSheet) { renameSheet }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
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
            Text("Create a new project or import a zip archive\nto get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    showNewProjectSheet = true
                } label: {
                    Label("New Project", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.orange.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }

                Button {
                    showImportPicker = true
                } label: {
                    Label("Import Zip", systemImage: "archivebox.fill")
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.blue.opacity(0.6), in: Capsule())
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
                showImportPicker = true
            } label: {
                Label("Import", systemImage: "archivebox.fill")
            }
            Button {
                showNewProjectSheet = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
        }
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
            Label("Export as ZIP", systemImage: "square.and.arrow.up")
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
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "swift")
                    .font(.title2)
                    .foregroundStyle(.orange)
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
                    Text("\(project.fileCount) file\(project.fileCount == 1 ? "" : "s")")
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
