import Foundation

@MainActor
final class OfflineModelDownloader: NSObject, ObservableObject {
    static let shared = OfflineModelDownloader()

    struct DownloadRequest: Identifiable, Equatable {
        enum Source: Equatable {
            case metadata(OfflineModelMetadata)
            case directURL(URL)
        }

        let source: Source
        let originalLink: String?

        var id: String {
            switch source {
            case let .metadata(metadata):
                return "metadata::\(metadata.modelName)"
            case let .directURL(url):
                return "url::\(url.absoluteString)"
            }
        }

        var displayName: String {
            switch source {
            case let .metadata(metadata):
                return metadata.modelName
            case let .directURL(url):
                return url.lastPathComponent.isEmpty ? url.host ?? "Model" : url.lastPathComponent
            }
        }
    }

    @Published var activeRequest: DownloadRequest?
    @Published var isDownloading = false
    @Published var isCompleted = false
    @Published var isCancelled = false
    @Published var downloadPercentage: Double = 0
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var remainingTime: String = "Estimating…"
    @Published var currentFileName: String = ""
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var remainingBytes: Int64 = 0
    @Published var errorMessage: String?

    private var session: URLSession?
    private var activeTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var startDate: Date?
    private var destinationURL: URL?
    private var completedBytesBeforeCurrentFile: Int64 = 0

    private override init() {
        super.init()
    }

    func prepare(request: DownloadRequest) {
        activeRequest = request
        resetProgress()
    }

    func startPreparedDownload() async {
        guard let request = activeRequest else { return }

        do {
            try await startDownload(request)
        } catch {
            if Task.isCancelled || (error as? CancellationError) != nil {
                errorMessage = OfflineModelError.downloadCancelled.localizedDescription
        LogManager.shared.logDeployment("Offline model download cancelled", isError: true)
                isCancelled = true
                return
            }

            if let offlineError = error as? OfflineModelError {
                errorMessage = offlineError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }

            LogManager.shared.logDeployment("Offline model download failed: \(errorMessage ?? error.localizedDescription)", isError: true)
        }
    }

    func startDownload(_ request: DownloadRequest) async throws {
        prepare(request: request)

        LogManager.shared.logDeployment("Offline model download prepared: \(request.displayName)")

        switch request.source {
        case let .metadata(metadata):
            try await download(model: metadata)
        case let .directURL(url):
            try await downloadDirectModel(from: url)
        }
    }

    func download(model: OfflineModelMetadata) async throws {
        guard !model.files.isEmpty else {
            throw OfflineModelError.noCompatibleModelFiles
        }

        let modelDirectory = OfflineModelManager.shared.modelDirectory(for: model.modelName)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        OfflineModelManager.shared.downloadingModels.insert(model.modelName)
        defer { OfflineModelManager.shared.downloadingModels.remove(model.modelName) }

        let expectedTotal = resolvedTotalBytes(for: model)
        try ensureSufficientStorage(for: expectedTotal)

        totalBytes = expectedTotal
        downloadedBytes = 0
        remainingBytes = expectedTotal
        downloadPercentage = 0
        isDownloading = true
        isCompleted = false
        isCancelled = false
        errorMessage = nil
        startDate = Date()

        do {
            for file in model.files {
                currentFileName = file.fileName
                let destination = modelDirectory.appendingPathComponent(file.fileName)
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

                completedBytesBeforeCurrentFile = downloadedBytes

                do {
                    _ = try await downloadFile(from: file.downloadURL, to: destination)
                } catch let error as URLError {
                    throw OfflineModelError.downloadFailed(error.localizedDescription)
                } catch {
                    throw error
                }

                let completedFileSize: Int64
                if file.sizeBytes > 0 {
                    completedFileSize = file.sizeBytes
                } else {
                    let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
                    completedFileSize = attributes?[.size] as? Int64 ?? 0
                }

                downloadedBytes = min(totalBytes, completedBytesBeforeCurrentFile + max(completedFileSize, 0))
                recalculateProgress()
            }

            completeDownload()
            OfflineModelManager.shared.registerInstalledModel(from: model, localPath: modelDirectory)
            LogManager.shared.logDeployment("Offline model download completed: \(model.modelName)")
        } catch {
            clearCurrentTaskState()
            isDownloading = false
            throw error
        }
    }

    func downloadDirectModel(from url: URL) async throws {
        guard url.scheme?.lowercased().hasPrefix("http") == true else {
            throw OfflineModelError.invalidModelURL
        }

        let modelName = guessedModelName(from: url)
        let fileName = resolvedFileName(from: url)
        let modelDirectory = OfflineModelManager.shared.modelDirectory(for: modelName)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let destination = modelDirectory.appendingPathComponent(fileName)
        currentFileName = fileName
        isDownloading = true
        isCompleted = false
        isCancelled = false
        errorMessage = nil
        startDate = Date()

        do {
            _ = try await downloadFile(from: url, to: destination)
            completeDownload()

            let bytes = max(totalBytes, downloadedBytes)
            let metadata = OfflineModelMetadata(
                modelName: modelName,
                providerName: url.host ?? "Direct URL",
                description: "Downloaded from \(url.absoluteString)",
                modelSize: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file),
                modelSizeBytes: bytes,
                tags: ["offline", "direct"],
                downloadCount: 0,
                modelURL: url,
                files: [OfflineModelFile(fileName: fileName, downloadURL: url, sizeBytes: bytes)],
                isQuantized: fileName.lowercased().contains("q")
            )
            OfflineModelManager.shared.registerInstalledModel(from: metadata, localPath: modelDirectory)
            LogManager.shared.logDeployment("Direct model download completed: \(modelName)")
        } catch {
            clearCurrentTaskState()
            isDownloading = false
            throw error
        }
    }

    func cancelActiveDownload() {
        guard isDownloading else { return }

        activeTask?.cancel()
        continuation?.resume(throwing: OfflineModelError.downloadCancelled)
        continuation = nil
        clearCurrentTaskState()

        isDownloading = false
        isCancelled = true
        errorMessage = OfflineModelError.downloadCancelled.localizedDescription
        LogManager.shared.logDeployment("Offline model download cancelled", isError: true)
    }

    private func downloadFile(from sourceURL: URL, to destination: URL) async throws -> URL {
        destinationURL = destination

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.continuation = continuation

            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            self.session = session

            let task = session.downloadTask(with: sourceURL)
            self.activeTask = task
            task.resume()
        }
    }

    private func completeDownload() {
        clearCurrentTaskState()
        downloadPercentage = 100
        remainingTime = "0s"
        remainingBytes = 0
        isDownloading = false
        isCompleted = true
        isCancelled = false
    }

    private func clearCurrentTaskState() {
        session?.invalidateAndCancel()
        session = nil
        activeTask = nil
        destinationURL = nil
        continuation = nil
        completedBytesBeforeCurrentFile = downloadedBytes
    }

    private func resetProgress() {
        downloadPercentage = 0
        downloadSpeed = "0 KB/s"
        remainingTime = "Estimating…"
        currentFileName = ""
        downloadedBytes = 0
        totalBytes = 0
        remainingBytes = 0
        errorMessage = nil
        isCompleted = false
        isCancelled = false
        startDate = nil
    }

    private func resolvedTotalBytes(for model: OfflineModelMetadata) -> Int64 {
        if model.modelSizeBytes > 0 {
            return model.modelSizeBytes
        }
        return model.files.reduce(0) { $0 + max($1.sizeBytes, 0) }
    }

    private func recalculateProgress() {
        guard totalBytes > 0 else {
            downloadPercentage = 0
            remainingBytes = 0
            return
        }

        downloadPercentage = min((Double(downloadedBytes) / Double(totalBytes)) * 100, 100)
        remainingBytes = max(totalBytes - downloadedBytes, 0)

        let elapsed = max(Date().timeIntervalSince(startDate ?? Date()), 0.1)
        let bytesPerSecond = Double(downloadedBytes) / elapsed
        if bytesPerSecond > 0 {
            downloadSpeed = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
            let secondsRemaining = Int(Double(remainingBytes) / bytesPerSecond)
            remainingTime = formatDuration(secondsRemaining)
        } else {
            downloadSpeed = "0 KB/s"
            remainingTime = "Estimating…"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0s" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        return "\(remainingSeconds)s"
    }

    private func guessedModelName(from url: URL) -> String {
        let raw = url.deletingPathExtension().lastPathComponent
        let fallback = "offline-model-\(Int(Date().timeIntervalSince1970))"
        let name = raw.isEmpty ? fallback : raw
        return name.replacingOccurrences(of: "/", with: "_")
    }

    private func resolvedFileName(from url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? "model.bin" : name
    }

    private func ensureSufficientStorage(for requiredBytes: Int64) throws {
        guard requiredBytes > 0 else { return }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let values = try appSupport?.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)

        if available > 0, available < requiredBytes {
            throw OfflineModelError.insufficientStorage(required: requiredBytes, available: available)
        }
    }
}

extension OfflineModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            guard let destinationURL else {
                continuation?.resume(throwing: OfflineModelError.downloadFailed("Missing destination URL"))
                continuation = nil
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)
                continuation?.resume(returning: destinationURL)
            } catch {
                continuation?.resume(throwing: OfflineModelError.downloadFailed(error.localizedDescription))
            }

            continuation = nil
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalBytes

            if expected > 0 {
                let inFlightBytes = max(totalBytesWritten, 0)
                let aggregate = completedBytesBeforeCurrentFile + inFlightBytes

                if totalBytes == 0 {
                    totalBytes = expected
                }

                downloadedBytes = min(max(aggregate, 0), max(totalBytes, aggregate))
                recalculateProgress()
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }

        Task { @MainActor in
            if let urlError = error as? URLError, urlError.code == .cancelled {
                continuation?.resume(throwing: OfflineModelError.downloadCancelled)
            } else {
                continuation?.resume(throwing: OfflineModelError.downloadFailed(error.localizedDescription))
            }
            continuation = nil
        }
    }
}
