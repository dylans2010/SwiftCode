import SwiftUI
import SwiftCodeSDK
import YcodeIDECore
import YcodeIDEShell

@MainActor
public struct GitChangesView: View {
    @State var viewModel: GitViewModel
    @State private var commitMessage = ""

    public init(viewModel: GitViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Git Workspace Changes", systemImage: "plus.minus.circle")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { Task { await viewModel.refreshStatus() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button("Stage All") {
                        if let status = viewModel.status {
                            let unstaged = status.files.filter { !$0.isStaged }
                            for file in unstaged {
                                Task { await viewModel.stage(file) }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)

                    Button("Unstage All") {
                        if let status = viewModel.status {
                            let staged = status.files.filter { $0.isStaged }
                            for file in staged {
                                Task { await viewModel.unstage(file) }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    if let status = viewModel.status {
                        if Preferences.shared.showStagedUnstagedSplit {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Staged Changes", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(status.files.filter { $0.isStaged }.count) files")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }

                                let staged = status.files.filter { $0.isStaged }
                                if staged.isEmpty {
                                    Text("No staged changes. Stage files below to prepare for commit.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(staged, id: \.path) { file in
                                            HStack {
                                                GitFileRowView(file: file)
                                                Spacer()
                                                Button("Unstage") {
                                                    Task { await viewModel.unstage(file) }
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                            .padding(6)
                                            .background(Color.secondary.opacity(0.04))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())

                        GroupBox {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Unstaged Changes", systemImage: "exclamationmark.circle.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(status.files.filter { !$0.isStaged }.count) files")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }

                                let unstaged = status.files.filter { !$0.isStaged }
                                if unstaged.isEmpty {
                                    Text("No unstaged changes in the working tree.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(unstaged, id: \.path) { file in
                                            HStack {
                                                GitFileRowView(file: file)
                                                Spacer()
                                                Button("Stage") {
                                                    Task { await viewModel.stage(file) }
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(Color.accentColor)
                                                .controlSize(.small)
                                            }
                                            .padding(6)
                                            .background(Color.secondary.opacity(0.04))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                        } else {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Label("All Changes", systemImage: "plus.minus.circle")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text("\(status.files.count) files")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                    }
                                    if status.files.isEmpty {
                                        Text("No changes in the working tree.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 8)
                                    } else {
                                        VStack(spacing: 8) {
                                            ForEach(status.files, id: \.path) { file in
                                                HStack {
                                                    GitFileRowView(file: file)
                                                    Spacer()
                                                    if file.isStaged {
                                                        Button("Unstage") {
                                                            Task { await viewModel.unstage(file) }
                                                        }
                                                        .buttonStyle(.bordered)
                                                        .controlSize(.small)
                                                    } else {
                                                        Button("Stage") {
                                                            Task { await viewModel.stage(file) }
                                                        }
                                                        .buttonStyle(.borderedProminent)
                                                        .tint(Color.accentColor)
                                                        .controlSize(.small)
                                                    }
                                                }
                                                .padding(6)
                                                .background(Color.secondary.opacity(0.04))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Commit Changes", systemImage: "pencil.and.outline")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            TextEditor(text: $commitMessage)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 100)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )

                            Button("Commit to Local Branch") {
                                Task {
                                    guard let url = viewModel.repositoryURL else { return }
                                    try? await GitService.shared.commit(message: commitMessage, repositoryURL: url)
                                    commitMessage = ""
                                    await viewModel.refreshStatus()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentColor)
                            .controlSize(.large)
                            .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
