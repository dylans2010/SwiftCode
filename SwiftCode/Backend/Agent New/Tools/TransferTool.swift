import Foundation
import MultipeerConnectivity

@MainActor
final class TransferTool {
    static let shared = TransferTool()
    private init() {}

    func transferCurrentProject(to peerName: String, permission: TransferPermission) async throws -> String {
        let project = try AgentPermissionAuthority.shared.authorize(scope: .allowAgentToInitiateTransfers, actor: "TransferTool")
        guard let peer = PeerSessionManager.shared.nearbyPeers.first(where: { $0.displayName == peerName }) else {
            throw NSError(domain: "TransferTool", code: 404, userInfo: [NSLocalizedDescriptionKey: "Peer not found: \(peerName)"])
        }
        try await ProjectTransferManager.shared.startTransfer(project: project, to: peer, permission: permission)
        return "Started transfer of \(project.name) to \(peerName)"
    }
}
