import SwiftUI

struct ModelDownloadProgressView: View {
    let modelName: String
    @ObservedObject var downloader = OfflineModelDownloader.shared

    var body: some View {
        VStack(spacing: 10) {
            Text("Downloading \(modelName)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            ProgressView(value: downloader.downloadPercentage, total: 100)
                .progressViewStyle(.linear)

            Text("\(Int(downloader.downloadPercentage))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
