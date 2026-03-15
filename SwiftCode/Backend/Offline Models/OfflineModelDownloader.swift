import Foundation

@MainActor
final class OfflineModelDownloader: ObservableObject {
    static let shared = OfflineModelDownloader()
    private init() {}

    @Published var downloadPercentage: Double = 0
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var remainingTime: String = "Unknown"
    @Published var currentFileName: String = ""

    func download(model: OfflineModelMetadata) async throws {
        if model.files.isEmpty {
            throw OfflineModelError.noCompatibleModelFiles
        }

        OfflineModelManager.shared.downloadingModels.insert(model.modelName)
        defer { OfflineModelManager.shared.downloadingModels.remove(model.modelName) }

        let localModelDirectory = OfflineModelManager.shared.modelDirectory(for: model.modelName)
        try FileManager.default.createDirectory(at: localModelDirectory, withIntermediateDirectories: true)

        let totalBytes = model.modelSizeBytes > 0 ? model.modelSizeBytes : model.files.reduce(0) { $0 + $1.sizeBytes }
        var totalReceivedBytes: Int64 = 0
        let startDate = Date()

        for file in model.files {
            currentFileName = file.fileName
            let destinationURL = localModelDirectory.appendingPathComponent(file.fileName)

            // Create subdirectories if necessary (for files in subfolders)
            let folderURL = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let (localURL, response) = try await URLSession.shared.download(from: file.downloadURL)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: localURL, to: destinationURL)

            totalReceivedBytes += file.sizeBytes
            updateProgress(receivedBytes: totalReceivedBytes, expectedBytes: totalBytes, startDate: startDate)
        }

        downloadPercentage = 100
        remainingTime = "0s"
        currentFileName = "Completed"

        OfflineModelManager.shared.registerInstalledModel(from: model, localPath: localModelDirectory)
    }

    private func updateProgress(receivedBytes: Int64, expectedBytes: Int64, startDate: Date) {
        let progress = min(100.0, (Double(receivedBytes) / Double(expectedBytes)) * 100)
        downloadPercentage = progress

        let elapsed = max(Date().timeIntervalSince(startDate), 0.1)
        let bytesPerSecond = Double(receivedBytes) / elapsed
        downloadSpeed = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"

        let remainingBytes = max(Double(expectedBytes - receivedBytes), 0)
        if bytesPerSecond > 0 {
            let seconds = Int(remainingBytes / bytesPerSecond)
            remainingTime = "\(seconds)s"
        }
    }
}
