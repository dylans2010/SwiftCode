import SwiftUI

struct MetricsDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    MetricCard(title: "Active Users", value: "1,240", icon: "person.3.fill", color: .blue)
                    MetricCard(title: "Total Commits", value: "42,891", icon: "arrow.triangle.branch", color: .green)
                }

                HStack(spacing: 16) {
                    MetricCard(title: "API Calls / min", value: "156", icon: "network", color: .orange)
                    MetricCard(title: "Avg. AI Tokens", value: "1.2k", icon: "cpu", color: .purple)
                }

                GroupBox("Response Time (ms)") {
                    VStack {
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(0..<10) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                                    .frame(width: 20, height: CGFloat.random(in: 40...120))
                            }
                        }
                        .frame(height: 140)

                        Text("24h aggregate latency distribution")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Metrics Dashboard")
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
