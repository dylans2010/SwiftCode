import SwiftUI

struct PushPullView: View {
    @ObservedObject var manager: CollaborationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Branch Sync") {
                    Button {
                        Task { await manager.pushes.simulatePush(branchName: manager.branches.currentBranch.name) }
                    } label: {
                        Label("Push Changes to Local Network", systemImage: "arrow.up.circle.fill")
                    }

                    Button {
                        // Simulated Pull
                    } label: {
                        Label("Pull Changes from Collaborators", systemImage: "arrow.down.circle.fill")
                    }
                }

                Section("Ongoing Sync Operations") {
                    if manager.pushes.activePushes.isEmpty {
                        Text("No active transfers")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(manager.pushes.activePushes) { status in
                            VStack(alignment: .leading) {
                                Text("Syncing \(status.branchName)...")
                                ProgressView(value: status.progress)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Push & Pull")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
