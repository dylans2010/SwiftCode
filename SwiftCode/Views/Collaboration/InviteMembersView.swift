import SwiftUI

struct InviteMembersView: View {
    @ObservedObject var manager: CollaborationManager
    @StateObject private var peerManager = PeerSessionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Available on Network") {
                    if peerManager.nearbyPeers.isEmpty {
                        Text("Searching for nearby users...")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(peerManager.nearbyPeers, id: \.self) { peer in
                            HStack {
                                Text(peer.displayName)
                                Spacer()
                                if manager.permissions.memberRoles[peer.displayName] != nil {
                                    Text("Already Member")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Invite") {
                                        invitePeer(peer)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Section("Invitations Info") {
                    Text("Invited users will be automatically assigned as Members by default. Roles can be adjusted later by the Owner or Admins.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Invite Members")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func invitePeer(_ peer: MCPeerID) {
        // Here we simulate the invitation logic
        peerManager.invite(peer)
        // Auto-assign Member role for simulation purposes
        manager.permissions.assignRole(.member, to: peer.displayName, by: UIDevice.current.name)
    }
}

import MultipeerConnectivity
