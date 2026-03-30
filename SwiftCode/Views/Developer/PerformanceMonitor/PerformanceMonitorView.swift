import SwiftUI

struct PerformanceMonitorView: View {
    @State private var cpuUsage: Double = 0.0
    @State private var fps: Int = 0
    @State private var memoryUsage: Double = 0.0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section("Real-time Metrics") {
                MetricRow(title: "CPU Usage", value: String(format: "%.1f%%", cpuUsage), icon: "cpu", color: .orange)
                MetricRow(title: "Frame Rate", value: "\(fps) FPS", icon: " gauge.medium", color: .green)
                MetricRow(title: "Memory", value: String(format: "%.1f MB", memoryUsage), icon: "memorychip", color: .blue)
            }

            Section("Historical Chart (Simulated)") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<20) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange.opacity(0.6))
                                .frame(width: 8, height: CGFloat.random(in: 10...60))
                        }
                    }
                    Text("CPU usage over last 20 seconds")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Performance")
        .onReceive(timer) { _ in
            updateMetrics()
        }
    }

    private func updateMetrics() {
        // Real-world logic would involve host_statistics and mach_task_self
        cpuUsage = Double.random(in: 2.0...15.0)
        fps = Int.random(in: 58...60)

        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            memoryUsage = Double(taskInfo.resident_size) / 1024.0 / 1024.0
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .bold()
        }
    }
}
