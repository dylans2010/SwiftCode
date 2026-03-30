import Foundation

public struct SyncChange: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let branchID: UUID
    public let type: ChangeType
    public let data: Data

    public enum ChangeType: String, Codable {
        case fileUpdate
        case commit
        case prUpdate
    }

    public init(branchID: UUID, type: ChangeType, data: Data) {
        self.id = UUID()
        self.timestamp = Date()
        self.branchID = branchID
        self.type = type
        self.data = data
    }
}

@MainActor
public final class OfflineSyncManager: ObservableObject {
    @Published public private(set) var pendingChanges: [SyncChange] = []
    @Published public var isOnline: Bool = true

    private let persistenceKey = "com.swiftcode.collaboration.offline_queue"

    public init() {
        loadQueue()
    }

    public func queueChange(branchID: UUID, type: SyncChange.ChangeType, data: Data) {
        let change = SyncChange(branchID: branchID, type: type, data: data)
        pendingChanges.append(change)
        saveQueue()

        if isOnline {
            Task {
                await syncNext()
            }
        }
    }

    public func syncNext() async {
        guard !pendingChanges.isEmpty, isOnline else { return }

        // In a real app, this would perform a network request
        // For simulation, we just remove it after a delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        pendingChanges.removeFirst()
        saveQueue()

        if !pendingChanges.isEmpty {
            await syncNext()
        }
    }

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(pendingChanges) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let decoded = try? JSONDecoder().decode([SyncChange].self, from: data) {
            pendingChanges = decoded
        }
    }
}
