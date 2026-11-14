import SwiftUI
import SwiftCodeSDK

@MainActor
public struct GitBranchesView: View {
    public let branches: [GitBranch]
    public var onCheckout: ((GitBranch) -> Void)?
    public var onMerge: ((GitBranch) -> Void)?
    public var onDelete: ((GitBranch) -> Void)?
    public var onNewBranch: (() -> Void)?

    public init(
        branches: [GitBranch],
        onCheckout: ((GitBranch) -> Void)? = nil,
        onMerge: ((GitBranch) -> Void)? = nil,
        onDelete: ((GitBranch) -> Void)? = nil,
        onNewBranch: (() -> Void)? = nil
    ) {
        self.branches = branches
        self.onCheckout = onCheckout
        self.onMerge = onMerge
        self.onDelete = onDelete
        self.onNewBranch = onNewBranch
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Git Branches Directory", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { onNewBranch?() }) {
                    Label("New Branch", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            if branches.isEmpty {
                                ContentUnavailableView(
                                    "No Branches Found",
                                    systemImage: "arrow.triangle.branch",
                                    description: Text("No local branches tracked.")
                                )
                                .frame(height: 150)
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(branches, id: \.name) { branch in
                                        HStack {
                                            Image(systemName: "arrow.triangle.branch")
                                                .foregroundStyle(branch.isCurrent ? Color.accentColor : .secondary)
                                            Text(branch.name)
                                                .fontWeight(branch.isCurrent ? .bold : .regular)
                                            if branch.isCurrent {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                            Spacer()
                                            if branch.isRemote {
                                                Text("remote")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(8)
                                        .background(branch.isCurrent ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                                        .cornerRadius(6)
                                        .contextMenu {
                                            Button("Checkout") { onCheckout?(branch) }
                                            Button("Merge into current") { onMerge?(branch) }
                                            Divider()
                                            Button("Delete", role: .destructive) { onDelete?(branch) }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())
                }
            }
        }
        .sourceControlEmbedded()
    }
}
