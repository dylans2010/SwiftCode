import SwiftUI
import SwiftCodeGitHub

@MainActor
struct OrganizationsView: View {
    @State private var organizations: [GitHubOrganization] = []
    @State private var isFetching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("GitHub Organizations", systemImage: "building.2.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Button {
                    fetchOrgs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isFetching)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if isFetching {
                GitHubLoadingView(message: "Loading organizations...")
            } else if organizations.isEmpty {
                GitHubEmptyStateView(
                    title: "No Organizations Found",
                    description: "No GitHub organizations were resolved for your account.",
                    systemImage: "building.2",
                    accentColor: Color.accentColor
                )
            } else {
                List(organizations) { org in
                    HStack(spacing: 16) {
                        Image(systemName: "building.2.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(org.login)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            if let desc = org.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .onAppear {
            fetchOrgs()
        }
    }

    private func fetchOrgs() {
        isFetching = true
        errorMessage = nil
        Task {
            do {
                self.organizations = try await GitHubTokenProvider.service().listOrganizations()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isFetching = false
        }
    }

}
