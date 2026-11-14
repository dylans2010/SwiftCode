import SwiftUI
import YcodeIDEShell

@MainActor
public struct GitPanelView: View {
    @State var viewModel: GitViewModel
    @State private var selectedTab = 0

    public init(viewModel: GitViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Git Workspace Navigation", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Picker("", selection: $selectedTab) {
                    Text("Changes").tag(0)
                    Text("History").tag(1)
                    Text("Branches").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(tabTitle(selectedTab), systemImage: tabIcon(selectedTab))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }

                            switch selectedTab {
                            case 0:
                                GitChangesView(viewModel: viewModel)
                            case 1:
                                GitHistoryView(commits: viewModel.history)
                            case 2:
                                GitBranchesView(
                                    branches: viewModel.branches,
                                    onCheckout: { branch in viewModel.checkout(branch) },
                                    onMerge: { branch in Task { try? await viewModel.merge(branch: branch.name) } },
                                    onDelete: { branch in viewModel.deleteBranch(branch) },
                                    onNewBranch: {
                                        
                                    }
                                )
                            default:
                                EmptyView()
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

    private func tabTitle(_ tab: Int) -> String {
        switch tab {
        case 0: return "Workspace Unstaged Changes"
        case 1: return "Commit History Logs"
        case 2: return "Branch Directory"
        default: return ""
        }
    }

    private func tabIcon(_ tab: Int) -> String {
        switch tab {
        case 0: return "plus.minus.circle"
        case 1: return "clock.arrow.circlepath"
        case 2: return "arrow.triangle.branch"
        default: return ""
        }
    }
}
