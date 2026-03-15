import Foundation

@MainActor
final class OfflineModelDownloader: ObservableObject {
    static let shared = OfflineModelDownloader()
    private init() {}

    @Published var downloadPercentage: Double = 0
    @Published var bytesDownloaded: Int64 = 0
    @Published var totalBytesToDownload: Int64 = 0
    @Published var bytesRemaining: Int64 = 0
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var remainingTime: String = "Unknown"
    @Published var currentFileName: String = ""
    @Published var isDownloading = false

    private var activeTask: URLSessionDownloadTask?
    private var activeSession: URLSession?
    private var activeDelegate: DownloadTaskDelegate?

    var dataRemainingDescription: String {
        ByteCountFormatter.string(fromByteCount: bytesRemaining, countStyle: .file)
    }

    var downloadedDescription: String {
        ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }

    var totalDescription: String {
        ByteCountFormatter.string(fromByteCount: totalBytesToDownload, countStyle: .file)
    }

    func download(model: OfflineModelMetadata) async throws {
        if model.files.isEmpty {
            throw OfflineModelError.noCompatibleModelFiles
        }

        resetProgress()
        isDownloading = true
        defer {
            isDownloading = false
            activeTask = nil
            activeSession = nil
            activeDelegate = nil
        }

        OfflineModelManager.shared.downloadingModels.insert(model.modelName)
        defer { OfflineModelManager.shared.downloadingModels.remove(model.modelName) }

        _ = try OfflineModelsStorage.shared.offlineModelsDirectory(createIfNeeded: true)
        let localModelDirectory = try OfflineModelsStorage.shared.modelDirectory(for: model.modelName, createIfNeeded: true)
        try ensureWritableDirectory(localModelDirectory)

        let totalBytes = model.modelSizeBytes > 0 ? model.modelSizeBytes : model.files.reduce(0) { $0 + $1.sizeBytes }
        try verifyStorageCapacity(requiredBytes: totalBytes)

        totalBytesToDownload = totalBytes
        var totalReceivedBytes: Int64 = 0
        let startDate = Date()

        print("[OfflineModelDownloader] Starting download for \(model.modelName)")
        for file in model.files {
            currentFileName = file.fileName
            let _ = try await downloadFile(
                file: file,
                modelFolderName: OfflineModelsStorage.shared.sanitizedFolderName(from: model.modelName),
                alreadyReceivedBytes: totalReceivedBytes,
                totalExpectedBytes: totalBytes,
                startDate: startDate
            )

            totalReceivedBytes += file.sizeBytes
            updateProgress(receivedBytes: totalReceivedBytes, expectedBytes: totalBytes, startDate: startDate)
        }

        downloadPercentage = 100
        bytesDownloaded = totalBytes
        bytesRemaining = 0
        remainingTime = "0s"
        currentFileName = "Completed"
        print("[OfflineModelDownloader] Completed download for \(model.modelName)")

        let installedMetadata = InstalledOfflineModelMetadata(
            modelName: model.modelName,
            modelSourceURL: model.modelURL.absoluteString,
            addedOn: Date(),
            totalSize: totalBytes,
            tokenCount: 0,
            downloadedFiles: model.files.map(\.fileName),
            modelVersion: "main"
        )
        try OfflineModelsStorage.shared.writeMetadata(installedMetadata, modelDirectory: localModelDirectory)
        OfflineModelManager.shared.registerInstalledModel(from: model, localPath: localModelDirectory)
    }

    func cancelCurrentDownload() {
        guard isDownloading else { return }
        print("[OfflineModelDownloader] Cancelling active download")
        activeTask?.cancel()
    }

    private func resetProgress() {
        downloadPercentage = 0
        bytesDownloaded = 0
        totalBytesToDownload = 0
        bytesRemaining = 0
        downloadSpeed = "0 KB/s"
        remainingTime = "Unknown"
        currentFileName = ""
    }


    private func ensureWritableDirectory(_ directoryURL: URL) throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw OfflineModelError.cannotCreateDirectory(path: directoryURL.path, underlyingError: error)
        }

        guard FileManager.default.isWritableFile(atPath: directoryURL.path) else {
            throw OfflineModelError.noWritePermission(path: directoryURL.path)
        }
    }

    private func verifyStorageCapacity(requiredBytes: Int64) throws {
        guard
            let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
            let availableBytes = values.volumeAvailableCapacityForImportantUsage
        else {
            return
        }

        if Int64(availableBytes) < requiredBytes {
            throw OfflineModelError.insufficientStorage(requiredBytes: requiredBytes, availableBytes: Int64(availableBytes))
        }
    }

    private func downloadFile(
        file: OfflineModelFile,
        modelFolderName: String,
        alreadyReceivedBytes: Int64,
        totalExpectedBytes: Int64,
        startDate: Date
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadTaskDelegate(
                modelFolderName: modelFolderName,
                relativeFilePath: file.fileName,
                onProgress: { bytesWritten, expectedToWrite in
                    let expectedBytes = expectedToWrite > 0 ? expectedToWrite : file.sizeBytes
                    let received = alreadyReceivedBytes + bytesWritten
                    self.updateProgress(receivedBytes: received, expectedBytes: max(totalExpectedBytes, alreadyReceivedBytes + expectedBytes), startDate: startDate)
                },
                onComplete: { finalizedURL, response, error in
                    self.activeTask = nil
                    self.activeSession = nil
                    self.activeDelegate = nil

                    if let error {
                        if (error as NSError).code == NSURLErrorCancelled {
                            continuation.resume(throwing: OfflineModelError.downloadCancelled)
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    guard let finalizedURL, let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    continuation.resume(returning: finalizedURL)
                }
            )

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: file.downloadURL)
            self.activeDelegate = delegate
            self.activeSession = session
            self.activeTask = task
            task.resume()
        }
    }

    private func updateProgress(receivedBytes: Int64, expectedBytes: Int64, startDate: Date) {
        let normalizedExpectedBytes = max(expectedBytes, 1)
        let progress = min(100.0, (Double(receivedBytes) / Double(normalizedExpectedBytes)) * 100)
        downloadPercentage = progress
        bytesDownloaded = receivedBytes
        bytesRemaining = max(normalizedExpectedBytes - receivedBytes, 0)
        totalBytesToDownload = normalizedExpectedBytes

        let elapsed = max(Date().timeIntervalSince(startDate), 0.1)
        let bytesPerSecond = Double(receivedBytes) / elapsed
        downloadSpeed = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"

        let remainingBytes = max(Double(normalizedExpectedBytes - receivedBytes), 0)
        if bytesPerSecond > 0 {
            let seconds = Int(remainingBytes / bytesPerSecond)
            remainingTime = "\(seconds)s"
        } else {
            remainingTime = "Unknown"
        }
    }
}

private final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate {
    private let modelFolderName: String
    private let relativeFilePath: String
    private let onProgress: @MainActor (Int64, Int64) -> Void
    private let onComplete: @MainActor (URL?, URLResponse?, Error?) -> Void
    private var finalizedURL: URL?
    private var response: URLResponse?
    private var fileMoveError: Error?

    init(
        modelFolderName: String,
        relativeFilePath: String,
        onProgress: @escaping @MainActor (Int64, Int64) -> Void,
        onComplete: @escaping @MainActor (URL?, URLResponse?, Error?) -> Void
    ) {
        self.modelFolderName = modelFolderName
        self.relativeFilePath = relativeFilePath
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        response = downloadTask.response

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let offlineModelsDirectory = documentsDirectory.appendingPathComponent("Offline Models", isDirectory: true)
        let modelDirectory = offlineModelsDirectory.appendingPathComponent(modelFolderName, isDirectory: true)
        let destinationURL = modelDirectory.appendingPathComponent(relativeFilePath)

        do {
            try FileManager.default.createDirectory(at: offlineModelsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: location, to: destinationURL)
            finalizedURL = destinationURL
        } catch {
            fileMoveError = OfflineModelError.failedToMoveDownloadedFile(
                from: location.path,
                to: destinationURL.path,
                underlyingError: error
            )
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            onProgress(totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            let completionError = error ?? fileMoveError
            onComplete(finalizedURL, response, completionError)
        }
        session.finishTasksAndInvalidate()
    }
}
