import SwiftUI

struct RemoteLogStreamView: View {
    @StateObject private var logService = ConnectLogService.shared

    @State private var isPaused = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                logControlsBar

                logListView
            }
            .padding()
        }
        .navigationTitle("Live Mac Logs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !logService.isSubscribed {
                try? await logService.subscribe()
            }
        }
    }

    private var logControlsBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter logs...", text: $logService.filterQuery)
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)

                if !logService.filterQuery.isEmpty {
                    Button {
                        logService.filterQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button {
                    isPaused.toggle()
                } label: {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(isPaused ? .green : .orange)
                .controlSize(.small)

                Button("Clear") {
                    logService.clearLogs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Menu {
                    Button("All Levels") { logService.selectedLogLevelFilter = nil }
                    Divider()
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue.capitalized) {
                            logService.selectedLogLevelFilter = level
                        }
                    }
                } label: {
                    Label(logService.selectedLogLevelFilter?.rawValue.capitalized ?? "All Levels", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
        }
    }

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(logService.filteredLogs) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)

                            Text(entry.level.rawValue.uppercased())
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(logLevelColor(entry.level))
                                .frame(width: 45, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("[\(entry.source)] \(entry.category)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Text(entry.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .id(entry.id)
                    }
                }
            }
            .onChange(of: logService.logs.count) {
                if !isPaused, let last = logService.filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .fault: return .purple
        }
    }
}
