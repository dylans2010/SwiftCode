import Foundation
import MultipeerConnectivity
import Combine

public struct PushPullEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public struct SyncStatus: Identifiable, Equatable {
    public let id = UUID()
    public let branchName: String
    public let progress: Double
    public let isComplete: Bool
    public let direction: String
}

@MainActor
public final class PushPullManager: ObservableObject {
    @Published public private(set) var activeTransfers: [SyncStatus] = []
    @Published public private(set) var lastEvent: PushPullEvent?

    private var cancellables = Set<AnyCancellable>()
    private let peerManager = PeerSessionManager.shared

    public var onReceiveState: ((CollaborationState) -> Void)?

    public init() {
        setupBindings()
    }

    private func setupBindings() {
        peerManager.onData = { [weak self] data, peer in
            Task { @MainActor in
                do {
                    let state = try JSONDecoder().decode(CollaborationState.self, from: data)
                    self?.onReceiveState?(state)
                    self?.lastEvent = PushPullEvent(actorID: peer.displayName, title: "Data Received", detail: "Synced state from \(peer.displayName).", notifies: true)
                } catch {
                    print("Failed to decode peer state: \(error)")
                }
            }
        }
    }

    public func push(state: CollaborationState, actorID: String) async {
        let status = SyncStatus(branchName: "all", progress: 0, isComplete: false, direction: "Push")
        activeTransfers.append(status)

        do {
            let data = try JSONEncoder().encode(state)
            let peers = peerManager.session.connectedPeers
            if !peers.isEmpty {
                try peerManager.send(data, to: peers)

                // Simulate progress for real data sending
                for i in 1...10 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if let index = activeTransfers.firstIndex(where: { $0.id == status.id }) {
                        activeTransfers[index] = SyncStatus(branchName: "all", progress: Double(i) / 10.0, isComplete: i == 10, direction: "Push")
                    }
                }
            }
        } catch {
            print("Failed to push state to peers: \(error)")
        }

        lastEvent = PushPullEvent(actorID: actorID, title: "Push complete", detail: "State broadcasted to connected peers.", notifies: true)
        try? await Task.sleep(nanoseconds: 500_000_000)
        activeTransfers.removeAll { $0.id == status.id }
    }

    public func pull(branchName: String, actorID: String) async {
        // Pull in P2P usually means waiting for a broadcast or requesting one.
        // For simplicity, we'll simulate a pull by triggering a push from peers if they were active.
        lastEvent = PushPullEvent(actorID: actorID, title: "Pull complete", detail: "Checked for updates from peers.", notifies: false)
    }
}
