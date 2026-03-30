import SwiftUI

struct NetworkInspectorView: View {
    @StateObject private var logger = InternalLoggingManager.shared
    @State private var selectedLog: NetworkRequestLog?

    var body: some View {
        List(logger.networkLogs.reversed()) { log in
            Button {
                selectedLog = log
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.method)
                            .font(.caption.bold())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(log.url)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                    HStack {
                        if let code = log.statusCode {
                            Text("\(code)")
                                .font(.caption2.bold())
                                .foregroundColor(code < 400 ? .green : .red)
                        } else {
                            Text("Pending")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        if let duration = log.duration {
                            Text(String(format: "%.2fms", duration * 1000))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(log.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Network Inspector")
        .toolbar {
            Button("Clear") {
                logger.clearLogs()
            }
        }
        .sheet(item: $selectedLog) { log in
            NetworkRequestDetailView(log: log)
        }
    }
}

struct NetworkRequestDetailView: View {
    let log: NetworkRequestLog
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("URL", value: log.url)
                    LabeledContent("Method", value: log.method)
                    LabeledContent("Status", value: log.statusCode != nil ? "\(log.logStatusCode!)" : "N/A")
                    LabeledContent("Time", value: log.timestamp.formatted())
                    if let duration = log.duration {
                        LabeledContent("Duration", value: String(format: "%.2fms", duration * 1000))
                    }
                }

                if let headers = log.requestHeaders, !headers.isEmpty {
                    Section("Request Headers") {
                        ForEach(headers.keys.sorted(), id: \.self) { key in
                            LabeledContent(key, value: headers[key] ?? "")
                        }
                    }
                }

                if let body = log.requestBody, !body.isEmpty {
                    Section("Request Body") {
                        Text(body)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                if let headers = log.responseHeaders, !headers.isEmpty {
                    Section("Response Headers") {
                        ForEach(headers.keys.sorted(), id: \.self) { key in
                            LabeledContent(key, value: headers[key] ?? "")
                        }
                    }
                }

                if let body = log.responseBody, !body.isEmpty {
                    Section("Response Body") {
                        Text(body)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension NetworkRequestLog {
    var logStatusCode: Int? { statusCode }
}
