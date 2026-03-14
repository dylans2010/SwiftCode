import SwiftUI

struct DeploymentLogLine: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let isError: Bool
}

struct DeploymentLogsView: View {
    let logs: [DeploymentLogLine]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(line.timestamp, style: .time)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .leading)

                            Text(line.message)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(line.isError ? .red : .primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(line.id)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .onChange(of: logs.count) { _ in
                if let last = logs.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    DeploymentLogsView(logs: [
        DeploymentLogLine(timestamp: Date(), message: "Preparing repository...", isError: false),
        DeploymentLogLine(timestamp: Date(), message: "Pushing code to GitHub...", isError: false),
        DeploymentLogLine(timestamp: Date(), message: "Failed to push: Remote rejected", isError: true)
    ])
    .frame(height: 300)
    .padding()
}
