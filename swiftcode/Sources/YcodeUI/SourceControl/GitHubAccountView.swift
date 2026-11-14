import YcodeAssistant
import SwiftCodeGitHub
import SwiftUI

@MainActor
public struct GitHubAccountView: View {
    public var client: GitHubClient
    public var store: SecretStore
    public var onSignOut: () -> Void

    @State private var user: GitHubUser?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignOutConfirm = false
    @State private var isTokenVisible = false
    @State private var isCopied = false
    @State private var localIdentityMessage: String?

    public init(client: GitHubClient, store: SecretStore = defaultSecretStore(), onSignOut: @escaping () -> Void) {
        self.client = client
        self.store = store
        self.onSignOut = onSignOut
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView("Loading account…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let user {
                profileHeader(user: user)
                Divider()
                profileDetails(user: user)
                Divider()
                statsGrid(user: user)
                tokenSection
                if let msg = localIdentityMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirm = true
                    }
                    .buttonStyle(.bordered)

                    Button {
                        useLocalIdentity()
                    } label: {
                        Label("Use Local Identity", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(.bordered)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Could Not Load Account",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(errorMessage)
                )
                if let msg = localIdentityMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                HStack(spacing: 12) {
                    Button("Try Again") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                    Button {
                        useLocalIdentity()
                    } label: {
                        Label("Use Local Identity", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .task { await load() }
        .alert("Sign out of GitHub?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the stored GitHub token from the keychain. You will need to sign in again to use GitHub features.")
        }
    }

    private func profileHeader(user: GitHubUser) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: user.avatarUrl.flatMap(URL.init(string:))) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? user.login)
                    .font(.title2.bold())
                Text("@\(user.login)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func profileDetails(user: GitHubUser) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let company = user.company, !company.isEmpty {
                Label(company, systemImage: "building.2")
            }
            if let location = user.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
            }
            if let blog = user.blog, !blog.isEmpty {
                Label(blog, systemImage: "link")
            }
            if let email = user.email, !email.isEmpty {
                Label(email, systemImage: "envelope")
            }
            if let hireable = user.hireable {
                Label(hireable ? "Available for hire" : "Not looking for work", systemImage: "briefcase")
            }
            if let createdAt = user.createdAt {
                Label("Joined \(createdAt, style: .date)", systemImage: "calendar")
            }
        }
        .font(.subheadline)
    }

    private func statsGrid(user: GitHubUser) -> some View {
        HStack(spacing: 24) {
            stat(value: user.followers, label: "Followers")
            stat(value: user.following, label: "Following")
            stat(value: user.publicRepos, label: "Public Repos")
            stat(value: user.totalPrivateRepos, label: "Private Repos")
        }
    }

    private func stat(value: Int?, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value.map(String.init) ?? "—")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            user = try await client.getAuthenticatedUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var tokenSection: some View {
        let currentToken = store.readString(SecretAccount.githubToken) ?? KeychainService.shared.get(forKey: KeychainService.githubToken) ?? ""
        return Group {
            if !currentToken.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Access Token")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(isTokenVisible ? currentToken : String(repeating: "•", count: min(currentToken.count, 20)))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                        Button {
                            isTokenVisible.toggle()
                        } label: {
                            Label(isTokenVisible ? "Hide" : "View", systemImage: isTokenVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(currentToken, forType: .string)
                            isCopied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                isCopied = false
                            }
                        } label: {
                            Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(isCopied ? Color.accentColor : .primary)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func useLocalIdentity() {
        Task {
            let identity = await GitHubTokenProvider.applyLocalIdentity()
            localIdentityMessage = "Using local Git identity: \(identity.name) <\(identity.email)>"
        }
    }

    private func signOut() {
        try? store.delete(SecretAccount.githubToken)
        onSignOut()
    }
}
