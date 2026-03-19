import SwiftUI

struct BranchGraphView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                visualGraphSection

                Divider()

                branchListSection

                recentMergeHistorySection
            }
            .padding()
        }
        .navigationTitle("Branch Graph")
    }

    private var visualGraphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Branch Tree", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                // Drawing lines between branches to simulate a tree
                Canvas { context, size in
                    // Logic to draw lines from source to target merge points
                    let branches = manager.branches.branches
                    for merge in manager.branches.merges {
                        if let sourceIdx = branches.firstIndex(where: { $0.id == merge.sourceBranchID }),
                           let targetIdx = branches.firstIndex(where: { $0.id == merge.targetBranchID }) {

                            let start = CGPoint(x: 100 + CGFloat(sourceIdx) * 40, y: 40)
                            let end = CGPoint(x: 100 + CGFloat(targetIdx) * 40, y: 120)

                            var path = Path()
                            path.move(to: start)
                            path.addCurve(to: end, control1: CGPoint(x: start.x, y: (start.y + end.y) / 2), control2: CGPoint(x: end.x, y: (start.y + end.y) / 2))

                            context.stroke(path, with: .color(.blue.opacity(0.3)), lineWidth: 2)
                        }
                    }
                }
                .frame(height: 160)

                HStack(alignment: .top, spacing: 20) {
                    ForEach(manager.branches.branches) { branch in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(branch.id == manager.branches.currentBranch.id ? Color.orange : Color.blue)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))

                            Text(branch.name)
                                .font(.caption.bold())
                                .rotationEffect(.degrees(-45))
                                .fixedSize()
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.leading, 80)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var branchListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Branches").font(.headline)

            ForEach(manager.branches.branches) { branch in
                HStack {
                    VStack(alignment: .leading) {
                        Text(branch.name).font(.subheadline.bold())
                        if let lastID = branch.lastCommitID,
                           let lastCommit = manager.commits.commits.first(where: { $0.id == lastID }) {
                            Text(lastCommit.message).font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("No commits").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if branch.id == manager.branches.currentBranch.id {
                        Text("Active")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }

                    Button {
                        manager.branches.switchBranch(to: branch.id, actorID: UIDevice.current.name)
                        manager.saveState()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .disabled(branch.id == manager.branches.currentBranch.id)
                }
                .padding()
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var recentMergeHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Merge History").font(.headline)

            if manager.branches.merges.isEmpty {
                Text("No merges yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.branches.merges) { merge in
                    let source = manager.branches.branches.first(where: { $0.id == merge.sourceBranchID })?.name ?? "unknown"
                    let target = manager.branches.branches.first(where: { $0.id == merge.targetBranchID })?.name ?? "unknown"

                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                            .foregroundStyle(.green)
                        Text("\(source) → \(target)")
                            .font(.subheadline)
                        Spacer()
                        Text(merge.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
