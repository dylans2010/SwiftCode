import SwiftUI

struct MemoryInspectorView: View {
    @State private var memoryUsageMB: Double = 0.0
    @State private var leakCount: Int = 0
    @State private var objectCounts: [String: Int] = ["Project": 4, "FileNode": 124, "CodeEditorView": 2]

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section("Memory Footprint") {
                HStack {
                    Text("Total Resident Size")
                    Spacer()
                    Text(String(format: "%.2f MB", memoryUsageMB))
                        .monospacedDigit()
                        .bold()
                }
            }

            Section("Leak Detection") {
                HStack {
                    Label("Detected Leaks", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(leakCount > 0 ? .red : .green)
                    Spacer()
                    Text("\(leakCount)")
                        .bold()
                }

                Button("Run Leak Scan") {
                    // Simulate scanning
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        leakCount = 0 // Everything clean in simulation
                    }
                }
                .font(.subheadline)
            }

            Section("Object Graph (Live Instances)") {
                ForEach(objectCounts.keys.sorted(), id: \.self) { key in
                    LabeledContent(key, value: "\(objectCounts[key] ?? 0)")
                }
            }
        }
        .navigationTitle("Memory")
        .onAppear(perform: updateMemory)
        .onReceive(timer) { _ in updateMemory() }
    }

    private func updateMemory() {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsageMB = Double(taskInfo.resident_size) / 1024.0 / 1024.0
        }

        // Randomly fluctuate counts slightly for "live" feel
        for key in objectCounts.keys {
            if Int.random(in: 0...5) == 0 {
                objectCounts[key]! += Int.random(in: -1...1)
                if objectCounts[key]! < 0 { objectCounts[key] = 0 }
            }
        }
    }
}
