import SwiftUI

struct ModelDownloadProgressView: View {
    let modelName: String
    @ObservedObject var downloader = OfflineModelDownloader.shared

    var body: some View {
        VStack(spacing: 15) {
            Text(modelName)
                .font(.headline)

            ProgressView(value: downloader.downloadPercentage, total: 100)
                .progressViewStyle(.linear)

            HStack {
                Text("\(Int(downloader.downloadPercentage))%")
                Spacer()
                Text(downloader.downloadSpeed)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Remaining: \(downloader.remainingTime)")
                .font(.caption2)

            if downloader.downloadPercentage >= 100 {
                Text("Download Complete")
                    .foregroundColor(.green)
                    .bold()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
