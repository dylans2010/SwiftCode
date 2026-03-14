import SwiftUI

struct PerformanceMonitorView: View {
    var body: some View {
        List {
            Text("CPU Usage: 5%")
            Text("FPS: 60")
        }
        .navigationTitle("Performance Monitor")
    }
}
