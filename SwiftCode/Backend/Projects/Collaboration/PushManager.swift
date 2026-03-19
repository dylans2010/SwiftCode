import Foundation

public struct PushStatus: Identifiable {
    public let id = UUID()
    public let branchName: String
    public let progress: Double
    public let isComplete: Bool
}

@MainActor
public final class PushManager: ObservableObject {
    @Published public private(set) var activePushes: [PushStatus] = []

    public func simulatePush(branchName: String) async {
        let status = PushStatus(branchName: branchName, progress: 0.0, isComplete: false)
        activePushes.append(status)

        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if let index = activePushes.firstIndex(where: { $0.branchName == branchName }) {
                activePushes[index] = PushStatus(branchName: branchName, progress: Double(i) / 10.0, isComplete: i == 10)
            }
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        activePushes.removeAll { $0.branchName == branchName }
    }
}
