import SwiftUI

struct CrashDebuggerView: View {
    @State private var recentCrashes: [CrashLog] = [
        CrashLog(timestamp: Date().addingTimeInterval(-3600), reason: "EXC_BAD_ACCESS", stackTrace: "0  SwiftCode 0x0000000100001234 main + 56\n1  libdyld.dylib 0x0000000180001234 start + 4")
    ]

    var body: some View {
        List {
            Section("Actions") {
                Button("Simulate Crash", role: .destructive) {
                    // In a production debug tool, this might trigger a crash on a background thread
                    // to test crash reporting, but for safety in the sandbox we just log it.
                    let log = CrashLog(timestamp: Date(), reason: "Manual Simulation", stackTrace: Thread.callStackSymbols.joined(separator: "\n"))
                    recentCrashes.insert(log, at: 0)
                }
            }

            Section("Recent Reports") {
                if recentCrashes.isEmpty {
                    Text("No recent crashes")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(recentCrashes) { log in
                        NavigationLink {
                            CrashDetailView(log: log)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(log.reason)
                                    .font(.subheadline.bold())
                                Text(log.timestamp.formatted())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Crash Logs")
    }
}

struct CrashLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let reason: String
    let stackTrace: String
}

struct CrashDetailView: View {
    let log: CrashLog

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reason")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(log.reason)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Timestamp")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(log.timestamp.formatted())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stack Trace")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(log.stackTrace)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Crash Detail")
    }
}
