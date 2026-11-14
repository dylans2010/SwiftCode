import YcodeIDECore
import SwiftUI

@MainActor
public struct NSForcePushView: View {
    public var repository: GitRepository
    @Environment(\.dismiss) private var dismiss

    @State private var useForceWithLease = true
    @State private var isPushing = false
    @State private var errorMessage: String?
    @State private var didPush = false

    public init(repository: GitRepository) {
        self.repository = repository
    }

    private var currentBranch: String { repository.currentBranch() ?? "HEAD" }
    private var remoteName: String {
        (try? repository.remotes().first?.name) ?? "origin"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Force Push", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Force-pushing rewrites history on the remote. Anyone else working on \(currentBranch) will need to re-sync.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text("Branch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentBranch)
                    .font(.subheadline.monospaced())
            }

            HStack {
                Text("Remote")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(remoteName)
                    .font(.subheadline.monospaced())
            }

            Toggle("Use force with lease (Safer)", isOn: $useForceWithLease)
            Text("Force with lease refuses when the remote moved since your last fetch; plain force overwrites unconditionally.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if didPush {
                Label("Pushed \(currentBranch) to \(remoteName).", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Force Push") {
                    Task { await forcePush() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .disabled(isPushing)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func forcePush() async {
        isPushing = true
        errorMessage = nil
        didPush = false
        defer { isPushing = false }
        let repo = repository
        let remote = remoteName
        let branch = currentBranch
        let lease = useForceWithLease
        do {
            try await Task.detached {
                try repo.push(remote: remote, branch: branch,
                              force: true, forceLease: lease)
            }.value
            didPush = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
