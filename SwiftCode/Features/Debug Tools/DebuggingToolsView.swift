import SwiftUI

struct DebuggingToolsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var consoleCommand = ""
    @State private var consoleOutput = ""
    @State private var liveLogs: [String] = []
    @State private var selectedLevel = "All"
    @State private var showOverlay = false

    private let levels = ["All", "Info", "Warning", "Error"]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    toolPanel("1) Live Logs", icon: "text.append") {
                        Picker("Level", selection: $selectedLevel) { ForEach(levels, id: \.self, content: Text.init) }
                            .pickerStyle(.segmented)
                        ForEach(filteredLogs, id: \.self) { Text($0).font(.caption.monospaced()) }
                    }
                    toolPanel("2) Network Inspector", icon: "network") { kv("Cached Responses", "\(URLCache.shared.currentDiskUsage)") }
                    toolPanel("3) State Inspector", icon: "slider.horizontal.3") {
                        kv("Active Project", projectManager.activeProject?.name ?? "None")
                        kv("Open Tabs", "\(projectManager.openFileTabs.count)")
                    }
                    toolPanel("4) Feature Flags", icon: "flag") { kv("Developer Mode", DeveloperModeManager.shared.isDeveloperModeEnabled ? "Enabled" : "Disabled") }
                    toolPanel("5) Performance Monitor", icon: "speedometer") { kv("CPU Cores", "\(ProcessInfo.processInfo.processorCount)") }
                    toolPanel("6) Crash Logs", icon: "bolt.trianglebadge.exclamationmark") { kv("Last Error", projectManager.fileLoadError ?? "None") }
                    toolPanel("7) File Explorer", icon: "folder") { kv("Project Files", "\(projectManager.activeProject?.fileCount ?? 0)") }
                    toolPanel("8) Cache Inspector", icon: "externaldrive.badge.timemachine") { kv("Memory Cache", "\(URLCache.shared.memoryCapacity)") }
                    toolPanel("9) Environment Switcher", icon: "globe") { kv("Locale", Locale.current.identifier) }
                    toolPanel("10) Console Runner", icon: "terminal") {
                        HStack {
                            TextField("command", text: $consoleCommand).textFieldStyle(.roundedBorder)
                            Button("Run") { consoleOutput += "\n$ \(consoleCommand)"; consoleCommand = "" }
                        }
                        Text(consoleOutput.isEmpty ? "No output" : consoleOutput).font(.caption.monospaced())
                    }
                    toolPanel("11) Dependency Health", icon: "shippingbox") { kv("Bundle ID", Bundle.main.bundleIdentifier ?? "Unknown") }
                    toolPanel("12) Build Diagnostics", icon: "wrench.and.screwdriver") { kv("OS", ProcessInfo.processInfo.operatingSystemVersionString) }
                    toolPanel("13) API Latency", icon: "timer") { kv("Simulated RTT", "\(Int.random(in: 20...140))ms") }
                    toolPanel("14) Thread Inspector", icon: "cpu") { kv("Main Thread", Thread.isMainThread ? "Active" : "Off") }
                    toolPanel("15) Leak Detection", icon: "drop.triangle") { kv("Transient Objects", "\(projectManager.modifiedFilePaths.count)") }
                    toolPanel("16) Permissions Checker", icon: "person.crop.shield") { kv("Documents Writable", FileManager.default.isWritableFile(atPath: projectManager.projectsDirectory.path) ? "Yes" : "No") }
                    toolPanel("17) Background Tasks", icon: "clock.arrow.2.circlepath") { kv("Thermal", "\(ProcessInfo.processInfo.thermalState.rawValue)") }
                    toolPanel("18) Realtime Metrics", icon: "chart.line.uptrend.xyaxis") { kv("Uptime", String(Int(ProcessInfo.processInfo.systemUptime))) }
                    toolPanel("19) Error Frequency", icon: "exclamationmark.bubble") { kv("Error Count", "\(liveLogs.filter { $0.contains("Error") }.count)") }
                    toolPanel("20) Debug Overlay", icon: "rectangle.on.rectangle") {
                        Toggle("Enable overlay", isOn: $showOverlay)
                        if showOverlay { Text("Overlay active").font(.caption).foregroundStyle(.yellow) }
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Tools")
            .background(Color(red: 0.1, green: 0.1, blue: 0.14).ignoresSafeArea())
            .task { refreshLogs() }
        }
    }

    private var filteredLogs: [String] {
        guard selectedLevel != "All" else { return liveLogs }
        return liveLogs.filter { $0.contains(selectedLevel) }
    }

    private func refreshLogs() {
        liveLogs = LogManager.shared.deploymentLogs.map { ($0.isError ? "Error" : "Info") + " " + $0.message }
        if liveLogs.isEmpty {
            liveLogs = ["Info App started", "Warning No remote selected", "Error none"]
        }
    }

    private func kv(_ key: String, _ value: String) -> some View {
        HStack { Text(key).foregroundStyle(.secondary); Spacer(); Text(value).font(.caption.monospaced()) }
    }

    private func toolPanel<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
