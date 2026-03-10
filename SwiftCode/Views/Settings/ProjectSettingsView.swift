import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var githubRepo = ""
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Info") {
                    HStack {
                        Text("Name")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(projectName)
                            .foregroundStyle(.white)
                    }

                    TextField("Description", text: $projectDescription, axis: .vertical)
                        .lineLimit(3)
                }

                Section("GitHub") {
                    TextField("Repository (Owner/Repo)", text: $githubRepo)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let project = projectManager.activeProject {
                    Section("Statistics") {
                        HStack {
                            Text("Files")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(project.fileCount)")
                        }
                        HStack {
                            Text("Created")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(project.createdAt, style: .date)
                        }
                        HStack {
                            Text("Last Opened")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(project.lastOpened, style: .date)
                        }
                    }

                    Section("Storage") {
                        HStack {
                            Text("Location")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(project.directoryURL.path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("Project Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
            .onAppear { loadSettings() }
        }
    }

    private func loadSettings() {
        guard let project = projectManager.activeProject else { return }
        projectName = project.name
        projectDescription = project.description
        githubRepo = project.githubRepo ?? ""
    }

    private func saveSettings() {
        guard let project = projectManager.activeProject,
              let idx = projectManager.projects.firstIndex(where: { $0.id == project.id }) else { return }

        projectManager.projects[idx].description = projectDescription
        projectManager.projects[idx].githubRepo = githubRepo.isEmpty ? nil : githubRepo
        projectManager.activeProject?.description = projectDescription
        projectManager.activeProject?.githubRepo = githubRepo.isEmpty ? nil : githubRepo

        dismiss()
    }
}
