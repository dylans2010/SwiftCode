import SwiftUI

struct APILatencyTrackerView: View {
    @State private var latencies: [APIMetric] = [
        APIMetric(endpoint: "/v1/chat/completions", duration: 1.2, timestamp: Date()),
        APIMetric(endpoint: "/repos/{owner}/{repo}", duration: 0.45, timestamp: Date().addingTimeInterval(-60)),
        APIMetric(endpoint: "/user", duration: 0.12, timestamp: Date().addingTimeInterval(-120))
    ]

    var body: some View {
        List {
            Section("Endpoint Latency") {
                ForEach(latencies) { metric in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(metric.endpoint)
                                .font(.caption.bold())
                            Text(metric.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.2fs", metric.duration))
                            .font(.subheadline.bold())
                            .foregroundStyle(latencyColor(metric.duration))
                    }
                }
            }

            Section("Averages") {
                LabeledContent("Avg. AI Response", value: "1.45s")
                LabeledContent("Avg. GitHub API", value: "0.52s")
            }
        }
        .navigationTitle("API Latency")
    }

    private func latencyColor(_ duration: Double) -> Color {
        if duration < 0.5 { return .green }
        if duration < 1.5 { return .orange }
        return .red
    }
}

struct APIMetric: Identifiable {
    let id = UUID()
    let endpoint: String
    let duration: Double
    let timestamp: Date
}
