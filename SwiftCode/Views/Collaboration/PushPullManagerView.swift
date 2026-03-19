import SwiftUI

struct PushPullManagerView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @State private var selectedBranchID: UUID?
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Branch Sync") {
                Picker("Branch", selection: Binding(get: {
                    selectedBranchID ?? manager.branches.currentBranch.id
                }, set: { newValue in
                    selectedBranchID = newValue
                    manager.branches.switchBranch(to: newValue, actorID: actorID)
                })) {
                    ForEach(manager.branches.branches) { branch in
                        Text(branch.name).tag(branch.id)
                    }
                }
                Button {
                    statusMessage = "Sync In Progress..."
                    Task {
                        await manager.syncCurrentBranch(actorID: actorID)
                        statusMessage = "Sync Complete."
                    }
                } label: {
                    Label("Sync Branch Across Peers", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }
                Text("Push and pull run through the active collaboration backend with live conflict detection and routing into the resolver.")
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
                        HStack {
                            Text("\(transfer.direction) \(transfer.branchName)")
                            Spacer()
                            Text("\(Int(transfer.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: transfer.progress)
                    }
                }
            }

            if !manager.pendingConflicts.isEmpty {
                Section("Detected Conflicts") {
                    ForEach(manager.pendingConflicts) { conflict in
                        NavigationLink {
                            ConflictResolverView(manager: manager, actorID: actorID)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conflict.filePath).font(.headline)
                                Text(conflict.localChange).font(.caption)
                                Text(conflict.remoteChange).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle("Push / Pull")
        .onAppear {
            selectedBranchID = manager.branches.currentBranch.id
        }
    }
}
