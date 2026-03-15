import Foundation

@MainActor
final class OfflineModelDownloader: ObservableObject {
    static let shared = OfflineModelDownloader()
    private init() {}

    @Published var downloadPercentage: Double = 0
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var remainingTime: String = "Unknown"

    func download(model: OfflineModelMetadata) async throws {
        guard let targetFile = model.preferredDownloadFile else {
            throw OfflineModelError.noCompatibleModelFiles
        }

        OfflineModelManager.shared.downloadingModels.insert(model.modelName)
        defer { OfflineModelManager.shared.downloadingModels.remove(model.modelName) }

        let localModelDirectory = OfflineModelManager.shared.modelDirectory(for: model.modelName)
        try FileManager.default.createDirectory(at: localModelDirectory, withIntermediateDirectories: true)

        let destinationURL = localModelDirectory.appendingPathComponent(URL(fileURLWithPath: targetFile.fileName).lastPathComponent)
        let request = URLRequest(url: targetFile.downloadURL)
        let startDate = Date()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let expectedLength = max(response.expectedContentLength, Int64(1))

        guard let stream = OutputStream(url: destinationURL, append: false) else {
            throw URLError(.cannotCreateFile)
        }

        stream.open()
        defer { stream.close() }

        var receivedBytes: Int64 = 0
        var buffer = Data()

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try writeBuffer(buffer, to: stream)
                receivedBytes += Int64(buffer.count)
                updateProgress(receivedBytes: receivedBytes, expectedBytes: expectedLength, startDate: startDate)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            try writeBuffer(buffer, to: stream)
            receivedBytes += Int64(buffer.count)
            updateProgress(receivedBytes: receivedBytes, expectedBytes: expectedLength, startDate: startDate)
        }

        downloadPercentage = 100
        remainingTime = "0s"

        OfflineModelManager.shared.registerInstalledModel(from: model, localPath: localModelDirectory)
    }

    private func writeBuffer(_ data: Data, to stream: OutputStream) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let basePointer = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                throw URLError(.cannotWriteToFile)
            }

            var totalWritten = 0
            while totalWritten < data.count {
                let written = stream.write(basePointer.advanced(by: totalWritten), maxLength: data.count - totalWritten)
                if written < 0 {
                    throw stream.streamError ?? URLError(.cannotWriteToFile)
                }
                if written == 0 {
                    throw URLError(.networkConnectionLost)
                }
                totalWritten += written
            }
        }
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
