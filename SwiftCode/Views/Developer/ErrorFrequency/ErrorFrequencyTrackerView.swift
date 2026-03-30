import SwiftUI

struct ErrorFrequencyTrackerView: View {
    @State private var errors: [ErrorMetric] = [
        ErrorMetric(type: "NetworkTimeout", count: 42, lastSeen: Date()),
        ErrorMetric(type: "InvalidAuthToken", count: 12, lastSeen: Date().addingTimeInterval(-3600)),
        ErrorMetric(type: "FileWritePermissionDenied", count: 5, lastSeen: Date().addingTimeInterval(-7200)),
        ErrorMetric(type: "LLMResponseParsingFailed", count: 28, lastSeen: Date().addingTimeInterval(-100))
    ]

    var body: some View {
        List {
            Section("Frequent Errors") {
                ForEach(errors.sorted(by: { $0.count > $1.count })) { error in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error.type)
                                .font(.subheadline.bold())
                            Text("Last seen: \(error.lastSeen.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(error.count)")
                            .font(.headline)
                            .foregroundStyle(error.count > 30 ? .red : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Section("Stats") {
                LabeledContent("Error Rate", value: "2.4%")
                LabeledContent("Total Crashes (24h)", value: "0")
            }
        }
        .navigationTitle("Error Frequency")
    }
}

struct ErrorMetric: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let lastSeen: Date
}
