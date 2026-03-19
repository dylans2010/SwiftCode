import SwiftUI
import MultipeerConnectivity

struct InviteMembersView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String
    @StateObject private var peerManager = PeerSessionManager.shared
    @State private var selectedRole: CollaborationRole = .member

    var body: some View {
        List {
            Section("Nearby Peers") {
                if peerManager.nearbyPeers.isEmpty {
                    Text("Searching for peers on the local network…")
                        .foregroundStyle(.secondary)
                }
                ForEach(peerManager.nearbyPeers, id: \.self) { peer in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                            let state = peerManager.peerStates[peer.displayName]
                            Text(stateString(for: state))
                                .font(.caption)
                                .foregroundStyle(stateColor(for: state))
                        }
                        Spacer()

                        if peerManager.peerStates[peer.displayName] == .connected {
                            Picker("Role", selection: $selectedRole) {
                                ForEach(CollaborationRole.allCases, id: \.self) { role in
                                    Text(role.rawValue.capitalized).tag(role)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)

                            Button("Add") {
                                manager.invite(memberID: peer.displayName, role: selectedRole, actorID: actorID)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Connect") {
                                peerManager.invite(peer)
                            }
                            .buttonStyle(.bordered)
                        }
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
                                        manager.saveState()
                                    }
                                }
                                Button("Remove", role: .destructive) {
                                    _ = manager.permissions.removeMember(memberID, by: actorID)
                                    manager.saveState()
                                }
                            }
                        }
                    }
                }
            }

            Section("Invitation History") {
                if manager.invites.invites.isEmpty {
                    Text("No past invitations.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.invites.invites) { invite in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(invite.memberID).font(.headline)
                            Spacer()
                            Text(invite.status.rawValue.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1), in: Capsule())
                        }
                        Text("\(invite.role.rawValue.capitalized) • Invited by \(invite.invitedBy)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Invitations")
    }

    private func stateString(for state: MCSessionState?) -> String {
        switch state {
        case .notConnected: return "Not Connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .none: return "Disconnected"
        @unknown default: return "Unknown"
        }
    }

    private func stateColor(for state: MCSessionState?) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .orange
        default: return .secondary
        }
    }
}
