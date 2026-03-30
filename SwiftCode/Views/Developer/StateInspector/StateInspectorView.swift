import SwiftUI

struct StateInspectorView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var expandedSections: Set<String> = ["Projects", "Active Project"]

    var body: some View {
        List {
            Section {
                toggleHeader(title: "Projects (\(projectManager.projects.count))", id: "Projects")
                if expandedSections.contains("Projects") {
                    ForEach(projectManager.projects) { project in
                        VStack(alignment: .leading) {
                            Text(project.name)
                                .font(.subheadline.bold())
                            Text(project.id.uuidString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                toggleHeader(title: "Active Project", id: "Active Project")
                if expandedSections.contains("Active Project") {
                    if let active = projectManager.activeProject {
                        LabeledContent("Name", value: active.name)
                        LabeledContent("ID", value: active.id.uuidString)
                        LabeledContent("Files", value: "\(active.fileCount)")
                        LabeledContent("GitHub Repo", value: active.githubRepo ?? "None")
                        LabeledContent("Last Opened", value: active.lastOpened.formatted())
                    } else {
                        Text("No active project")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }

            Section("Device Info") {
                LabeledContent("Name", value: UIDevice.current.name)
                LabeledContent("System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                LabeledContent("Model", value: UIDevice.current.model)
            }
        }
        .navigationTitle("State Inspector")
    }

    private func toggleHeader(title: String, id: String) -> some View {
        Button {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
            } else {
                expandedSections.insert(id)
            }
        } label: {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: expandedSections.contains(id) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
