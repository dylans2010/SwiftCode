import SwiftUI

struct AgentToolbar: View {
    @Binding var selectedTab: Int
    @ObservedObject private var agentManager = AgentManager.shared

    var body: some View {
        HStack {
            Picker("Mode", selection: $selectedTab) {
                Text("Agent Mode").tag(0)
                Text("Chat Mode").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer()

            if agentManager.executionState.status == .running {
                Button {
                    // In a real system, we'd have a way to cancel
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .foregroundColor(.red)
                }
            }

            Button {
                // Open logs or settings
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .padding()
    }
}
