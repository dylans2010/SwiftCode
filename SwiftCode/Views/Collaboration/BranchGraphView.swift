import SwiftUI

@MainActor
struct BranchGraphView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        List {
            Section("Branch Graph Visualization") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(manager.branches.branches) { branch in
                            branchCard(branch)
                        }
                    }
                    .padding(.vertical)
                }
            }

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
                    .swipeActions {
                        Button("Switch") {
                            manager.branches.switchBranch(to: branch.id, actorID: UIDevice.current.name)
                        }
                        .tint(.blue)
                    }
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

    private func branchCard(_ branch: Branch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: branch.id == manager.branches.currentBranch.id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(branch.id == manager.branches.currentBranch.id ? .blue : .secondary)
                Text(branch.name).font(.headline)
            }

            if let commitID = branch.lastCommitID,
               let commit = manager.commits.commits.first(where: { $0.id == commitID }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(commit.message).font(.caption).lineLimit(1)
                    Text(commit.authorID).font(.caption2).foregroundStyle(.secondary)
                }
            }

            // Visual indicator of hierarchy
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(.quaternary)
        }
        .padding()
        .frame(width: 150)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}
