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
                    Label("Sync with Peers", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }
                Text("Broadcasts your current state to all connected peers via the local network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Active Transfers") {
                if manager.sync.activeTransfers.isEmpty {
                    Text("No active transfers.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.sync.activeTransfers) { transfer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(transfer.direction) state")
                        ProgressView(value: transfer.progress)
                    }
                }
            }

            if !manager.conflicts.pendingConflicts.isEmpty {
                Section("Detected Conflicts") {
                    ForEach(manager.conflicts.pendingConflicts) { conflict in
                        NavigationLink(destination: ConflictResolverView(manager: manager, actorID: actorID)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conflict.filePath).font(.headline)
                                Text("Resolution required").font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("P2P Sync")
    }
}
