import SwiftUI

struct ModelDownloadProgressView: View {
    let request: OfflineModelDownloader.DownloadRequest
    let onFinished: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var downloader = OfflineModelDownloader.shared

    @State private var hasStarted = false

    init(request: OfflineModelDownloader.DownloadRequest, onFinished: (() async -> Void)? = nil) {
        self.request = request
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Downloading \(request.displayName)")
                .font(.headline)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: downloader.downloadPercentage, total: 100)
                    .progressViewStyle(.linear)

                HStack {
                    Text("\(Int(downloader.downloadPercentage))%")
                    Spacer()
                    Text(downloader.downloadSpeed)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Current File: \(downloader.currentFileName.isEmpty ? "Preparing..." : downloader.currentFileName)")
                Text("Time Remaining: \(downloader.remainingTime)")
                Text("Data Remaining: \(ByteCountFormatter.string(fromByteCount: downloader.remainingBytes, countStyle: .file))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let errorMessage = downloader.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if downloader.isDownloading {
                    Button("Cancel Download") {
                        downloader.cancelActiveDownload()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(downloader.isCompleted || downloader.errorMessage != nil || downloader.isCancelled ? "Close" : "Hide") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            downloader.prepare(request: request)
            await downloader.startPreparedDownload()

            if downloader.isCompleted {
                await onFinished?()
            }
        }
    }
}
