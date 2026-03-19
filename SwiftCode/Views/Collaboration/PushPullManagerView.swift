import SwiftUI

struct PushPullManagerView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    var body: some View {
        List {
            Section("Branch Sync") {
                Button {
                    Task { await manager.syncCurrentBranch(actorID: actorID) }
                } label: {
                    Label("Sync Current Branch", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }
                Text("Local push/pull operations use the active collaboration backend and automatically register conflicts for visual resolution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Transfers") {
                if manager.pushes.activePushes.isEmpty {
                    Text("No active push or pull operations.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.pushes.activePushes) { transfer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(transfer.direction) \(transfer.branchName)")
                        ProgressView(value: transfer.progress)
                    }
                }
            }

            if !manager.pendingConflicts.isEmpty {
                Section("Detected Conflicts") {
                    ForEach(manager.pendingConflicts) { conflict in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conflict.filePath).font(.headline)
                            Text(conflict.localChange).font(.caption)
                            Text(conflict.remoteChange).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Push / Pull")
    }
}
