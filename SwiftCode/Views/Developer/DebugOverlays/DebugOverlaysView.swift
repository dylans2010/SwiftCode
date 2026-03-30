import SwiftUI

struct DebugOverlaysView: View {
    @AppStorage("com.swiftcode.debug.showFPS") private var showFPS = false
    @AppStorage("com.swiftcode.debug.showNetworkActivity") private var showNetworkActivity = false
    @AppStorage("com.swiftcode.debug.showLayoutBounds") private var showLayoutBounds = false
    @AppStorage("com.swiftcode.debug.slowAnimations") private var slowAnimations = false
    @AppStorage("com.swiftcode.debug.showAgentThought") private var showAgentThought = false

    var body: some View {
        List {
            Section("Visual Overlays") {
                Toggle("Show FPS Counter", isOn: $showFPS)
                Toggle("Show Network Activity Overlay", isOn: $showNetworkActivity)
                Toggle("Show Agent Thought Process", isOn: $showAgentThought)
            }

            Section("System Debugging") {
                Toggle("Show UI Layout Bounds", isOn: $showLayoutBounds)
                Toggle("Slow Animations (UI Debug)", isOn: $slowAnimations)
            }

            Section("Color Scheme") {
                Button("Reset UI Theme") { }
            }
        }
        .navigationTitle("Debug Overlays")
    }
}
