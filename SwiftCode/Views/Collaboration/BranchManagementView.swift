import SwiftUI

struct BranchManagementView: View {
    @ObservedObject var manager: CollaborationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateBranch = false
    @State private var newBranchName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.branches.branches) { branch in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(branch.name)
                                .font(.headline)
                            if branch.id == manager.branches.currentBranch.id {
                                Text("Current Working Branch")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Spacer()
                        if branch.id != manager.branches.currentBranch.id {
                            Button("Switch") {
                                manager.branches.switchBranch(to: branch.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            manager.branches.deleteBranch(branch.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Branches")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateBranch = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Branch", isPresented: $showCreateBranch) {
                TextField("Branch Name", text: $newBranchName)
                Button("Cancel", role: .cancel) { newBranchName = "" }
                Button("Create") {
                    if !newBranchName.isEmpty {
                        _ = manager.branches.createBranch(name: newBranchName)
                        newBranchName = ""
                    }
                }
            }
        }
    }
}
