import SwiftUI

struct BranchGraphView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack {
                // Background connections
                Canvas { context, size in
                    drawConnections(in: &context, size: size)
                }

                // Branch nodes
                HStack(spacing: 40) {
                    ForEach(manager.branches.branches) { branch in
                        VStack(spacing: 20) {
                            BranchNodeView(branch: branch, isCurrent: manager.branches.currentBranch.id == branch.id)

                            // Commit history for this branch
                            let commits = manager.commits.commits(for: branch.id)
                            ForEach(commits.prefix(5)) { commit in
                                CommitNodeView(commit: commit)
                            }

                            if commits.count > 5 {
                                Text("...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(40)
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
        .navigationTitle("Branch Graph")
    }

    private func drawConnections(in context: inout GraphicsContext, size: CGSize) {
        // Implementation for drawing Bezier curves between related commits/merges
        // Simplified for this version
    }
}

struct BranchNodeView: View {
    let branch: Branch
    let isCurrent: Bool

    var body: some View {
        VStack {
            Image(systemName: "arrow.triangle.branch")
                .font(.title2)
                .foregroundStyle(isCurrent ? .orange : .blue)
            Text(branch.name)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(10)
        .background(isCurrent ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.orange : Color.blue, lineWidth: 1)
        )
    }
}

struct CommitNodeView: View {
    let commit: Commit

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.5))
            .frame(width: 12, height: 12)
            .overlay(
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .help(commit.message)
    }
}
