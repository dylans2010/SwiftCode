import SwiftUI

struct ModelDownloadProgressView: View {
    let modelName: String
    let modelLink: String?
    let metadata: OfflineModelMetadata?
    let onComplete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var downloader = OfflineModelDownloader.shared
    @State private var errorMessage: String?
    @State private var hasStarted = false

    private var titleText: String {
        if let metadata {
            return metadata.modelName
        }
        return modelName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Downloading \(titleText)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if let modelLink {
                Text(modelLink)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressView(value: downloader.downloadPercentage, total: 100)
                .progressViewStyle(.linear)

            HStack {
                Text("\(Int(downloader.downloadPercentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(downloader.downloadedDescription) / \(downloader.totalDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Time Remaining: \(downloader.remainingTime)", systemImage: "clock")
                    .font(.caption)
                Spacer()
                Label("Data Remaining: \(downloader.dataRemainingDescription)", systemImage: "externaldrive")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            if !downloader.currentFileName.isEmpty {
                Text("Current file: \(downloader.currentFileName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                if downloader.isDownloading {
                    Button("Cancel") {
                        downloader.cancelCurrentDownload()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await startDownloadIfNeeded()
        }
    }

    private func startDownloadIfNeeded() async {
        do {
            let selectedMetadata: OfflineModelMetadata
            if let metadata {
                selectedMetadata = metadata
            } else if let modelLink {
                selectedMetadata = try await OfflineModelManager.shared.fetchModelMetadataFromLink(modelLink)
            } else {
                throw OfflineModelError.invalidHuggingFaceURL
            }

            try await OfflineModelDownloader.shared.download(model: selectedMetadata)
            OfflineModelManager.shared.loadInstalledModels()
            await onComplete?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
