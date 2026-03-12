import SwiftUI

struct WorkspaceProfilesView: View {
    @StateObject private var manager = WorkspaceProfilesManager.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.profiles) { profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text(profile.buildConfiguration).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Activate") { manager.switchTo(profile) }
                    }
                }
            }
            .navigationTitle("Workspace Profiles")
            .toolbar {
                Button("New") { manager.add(.template) }
            }
        }
    }
}
