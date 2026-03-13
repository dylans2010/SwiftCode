import SwiftUI

struct FoldersView: View {
    let folder: ProjectFolder

    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var folderManager: FolderManager

    private var projects: [Project] {
        folderManager.projects(in: folder, allProjects: projectManager.projects)
    }

    var body: some View {
        List {
            if projects.isEmpty {
                ContentUnavailableView("No Projects", systemImage: "folder", description: Text("Add projects to this folder from the dashboard."))
            } else {
                ForEach(projects) { project in
                    Button {
                        projectManager.openProject(project)
                    } label: {
                        HStack {
                            Image(systemName: "swift")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text(project.name)
                                Text("\(project.fileCount) files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(folder.folderName)
    }
}
