import SwiftUI

struct WorkspaceProfilesView: View {
    @StateObject private var manager = WorkspaceProfilesManager.shared
    @State private var draft = WorkspaceProfile.empty

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Form {
                    Section("Create Workspace Profile") {
                        TextField("Workspace name", text: $draft.name)
                        TextField("Build configuration", text: $draft.buildConfiguration)
                        Button("Create Profile", action: createProfile)
                            .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxHeight: 190)

                List {
                    ForEach(manager.profiles) { profile in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(profile.name).font(.headline)
                                if manager.activeProfileID == profile.id {
                                    Text("Active")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2), in: Capsule())
                                }
                                Spacer()
                            }
                            Text("Build: \(profile.buildConfiguration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Activate") { manager.switchTo(profile) }
                                Button("Delete", role: .destructive) { manager.delete(profile) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Workspace Profiles")
        }
    }

    private func createProfile() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let config = draft.buildConfiguration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        manager.add(
            .init(
                id: UUID(),
                name: name,
                buildConfiguration: config.isEmpty ? "Debug" : config,
                environmentVariables: [:],
                preferences: [:]
            )
        )
        draft = .empty
    }
}
