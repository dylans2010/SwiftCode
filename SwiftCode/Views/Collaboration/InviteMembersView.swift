import SwiftUI
import MultipeerConnectivity

struct InviteMembersView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @StateObject private var peerManager = PeerSessionManager.shared
    @State private var selectedRole: CollaborationRole = .member

    var body: some View {
        List {
            Section("Nearby Collaborators") {
                if peerManager.nearbyPeers.isEmpty {
                    Text("Searching for peers on the local network…")
                        .foregroundStyle(.secondary)
                }
                ForEach(peerManager.nearbyPeers, id: \.self) { peer in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                            Text(manager.permissions.memberRoles[peer.displayName]?.rawValue.capitalized ?? "Not added")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("Role", selection: $selectedRole) {
                            ForEach(CollaborationRole.allCases, id: \.self) { role in
                                Text(role.rawValue.capitalized).tag(role)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)

                        Button("Invite") {
                            peerManager.invite(peer)
                            manager.invite(memberID: peer.displayName, role: selectedRole, actorID: actorID)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Current Collaborators") {
                ForEach(manager.permissions.memberRoles.keys.sorted(), id: \.self) { memberID in
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
                                Button("Remove", role: .destructive) {
                                    _ = manager.permissions.removeMember(memberID, by: actorID)
                                }
                            }
                        }
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
    }
}
