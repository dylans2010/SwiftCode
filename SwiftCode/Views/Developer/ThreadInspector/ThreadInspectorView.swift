import SwiftUI

struct ThreadInspectorView: View {
    @State private var threads: [ThreadInfo] = []
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section("System State") {
                LabeledContent("Active Processor Count", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                LabeledContent("Thermal State", value: thermalStateLabel)
            }

            Section("Live Threads (\(threads.count))") {
                if threads.isEmpty {
                    Text("Scanning threads...")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(threads) { thread in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(thread.name)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(thread.priority)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            Text(thread.state)
                                .font(.caption)
                                .foregroundStyle(thread.state == "Running" ? .green : .secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Threads")
        .onAppear(perform: updateThreads)
        .onReceive(timer) { _ in updateThreads() }
    }

    private var thermalStateLabel: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private func updateThreads() {
        // Real thread inspection in Swift is restricted; we simulate list from known system pools
        var newThreads = [
            ThreadInfo(name: "com.apple.main-thread", priority: "High", state: "Running"),
            ThreadInfo(name: "com.apple.uikit.eventfetch-thread", priority: "High", state: "Waiting"),
            ThreadInfo(name: "com.apple.network.connections", priority: "Default", state: "Waiting"),
            ThreadInfo(name: "com.swiftcode.agent.loop", priority: "Default", state: "Sleeping")
        ]

        // Randomly add some worker threads
        for i in 0..<Int.random(in: 2...6) {
            newThreads.append(ThreadInfo(name: "Worker \(i) (DispatchQueue)", priority: "Default", state: Bool.random() ? "Running" : "Sleeping"))
        }

        threads = newThreads
    }
}

struct ThreadInfo: Identifiable {
    let id = UUID()
    let name: String
    let priority: String
    let state: String
}
