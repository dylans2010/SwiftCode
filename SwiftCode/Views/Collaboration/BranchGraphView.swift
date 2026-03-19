import SwiftUI

struct BranchGraphView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        List {
            Section("Branches") {
                ForEach(manager.branches.branches) { branch in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(branch.name, systemImage: branch.id == manager.branches.currentBranch.id ? "arrowshape.turn.up.left.circle.fill" : "arrow.triangle.branch")
                                .font(.headline)
                            Spacer()
                            if let commitID = branch.lastCommitID,
                               let commit = manager.commits.commits.first(where: { $0.id == commitID }) {
                                Text(commit.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No commits yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let merge = manager.branches.merges.first(where: { $0.targetBranchID == branch.id }),
                           let source = manager.branches.branches.first(where: { $0.id == merge.sourceBranchID }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.merge")
                                    .foregroundStyle(.green)
                                Text("Merged from \(source.name) on \(merge.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Recent Merge History") {
                if manager.branches.merges.isEmpty {
                    Text("No merges recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.branches.merges) { merge in
                        let source = manager.branches.branches.first(where: { $0.id == merge.sourceBranchID })?.name ?? "Unknown"
                        let target = manager.branches.branches.first(where: { $0.id == merge.targetBranchID })?.name ?? "Unknown"
                        Label("\(source) → \(target)", systemImage: "arrow.triangle.merge")
                    }
                }
            }
        }
        .navigationTitle("Branch Graph")
    }
}
