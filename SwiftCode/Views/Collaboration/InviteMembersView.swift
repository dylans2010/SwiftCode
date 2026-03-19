import SwiftUI
import MultipeerConnectivity

struct InviteMembersView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @StateObject private var peerManager = PeerSessionManager.shared
    @State private var selectedRoles: [String: CollaborationRole] = [:]
    @State private var searchText = ""

    var body: some View {
        List {
            Section("Nearby Collaborators") {
                if peerManager.nearbyPeers.isEmpty {
                    Text("Searching for users on the local network…")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredPeers, id: \.self) { peer in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                            Text(manager.permissions.memberRoles[peer.displayName]?.rawValue.capitalized ?? "Not added")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("Role", selection: roleBinding(for: peer.displayName)) {
                            ForEach(CollaborationRole.allCases, id: \.self) { role in
                                Text(role.rawValue.capitalized).tag(role)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)

                        Button("Invite") {
                            peerManager.invite(peer)
                            manager.invite(memberID: peer.displayName, role: selectedRoles[peer.displayName] ?? .collaborator, actorID: actorID)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Current Collaborators") {
                ForEach(manager.permissions.memberRoles.keys.sorted(), id: \.self) { memberID in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(memberID)
                                Text(manager.permissions.memberRoles[memberID]?.rawValue.capitalized ?? "Unknown")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if memberID != actorID {
                                Menu("Manage") {
                                    ForEach(CollaborationRole.allCases, id: \.self) { role in
                                        Button("Make \(role.rawValue.capitalized)") {
                                            _ = manager.permissions.assignRole(role, to: memberID, by: actorID)
                                        }
                                    }
                                    Button("Kick User", role: .destructive) {
                                        _ = manager.permissions.removeMember(memberID, by: actorID)
                                    }
                                }
                            }
                        }
                        permissionToggles(for: memberID)
                    }
                }
            }

            Section("Invite Feed") {
                ForEach(manager.invites.invites) { invite in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invite.memberID).font(.headline)
                        Text("\(invite.role.rawValue.capitalized) • \(invite.status.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Invite Members")
        .searchable(text: $searchText)
    }

    private var filteredPeers: [MCPeerID] {
        if searchText.isEmpty { return peerManager.nearbyPeers }
        return peerManager.nearbyPeers.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private func roleBinding(for memberID: String) -> Binding<CollaborationRole> {
        Binding {
            selectedRoles[memberID] ?? .collaborator
        } set: { selectedRoles[memberID] = $0 }
    }

    @ViewBuilder
    private func permissionToggles(for memberID: String) -> some View {
        Toggle("Can Push", isOn: permissionBinding(for: memberID, keyPath: \.versionControl.push))
        Toggle("Can Merge", isOn: permissionBinding(for: memberID, keyPath: \.versionControl.merge))
        Toggle("Can Edit Files", isOn: permissionBinding(for: memberID, keyPath: \.fileSystem.editFiles))
    }

    private func permissionBinding(for memberID: String, keyPath: WritableKeyPath<TransferPermission, Bool>) -> Binding<Bool> {
        Binding {
            manager.permissions.permission(for: memberID)[keyPath: keyPath]
        } set: { newValue in
            var permission = manager.permissions.permission(for: memberID)
            permission[keyPath: keyPath] = newValue
            _ = manager.permissions.updatePermission(permission, for: memberID, by: actorID)
        }
    }
}
