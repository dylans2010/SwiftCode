import Foundation

@MainActor
final class OfflineModelDownloader: ObservableObject {
    static let shared = OfflineModelDownloader()
    private init() {}

    @Published var downloadPercentage: Double = 0
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var remainingTime: String = "Unknown"

    func download(model: OfflineModelMetadata) async throws {
        // Implementation of background download with progress updates
        // This is a placeholder for the complex URLSessionDownloadDelegate implementation
        OfflineModelManager.shared.downloadingModels.insert(model.modelName)

        for i in 1...100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            downloadPercentage = Double(i)
            downloadSpeed = "2.5 MB/s"
            remainingTime = "\(100 - i)s"
        }

        // Create directory and dummy file
        let dir = OfflineModelManager.shared.modelDirectory(for: model.modelName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "dummy".write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        OfflineModelManager.shared.registerInstalledModel(from: model, localPath: dir)
        OfflineModelManager.shared.downloadingModels.remove(model.modelName)
    }
}
