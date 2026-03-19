import SwiftUI

struct AgentToolbar: View {
    @Binding var selectedTab: Int
    @ObservedObject private var agentManager = AgentManager.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                AssistantSectionHeader(
                    eyebrow: "Workspace",
                    title: "Agent control center",
                    subtitle: "Swap between autonomous execution and direct chat with faster visual feedback."
                )
                Spacer()
                statusPill
            }

            Picker("Mode", selection: $selectedTab) {
                Text("Agent").tag(0)
                Text("Chat").tag(1)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button {
                    selectedTab = 0
                } label: {
                    Label("Open Agent", systemImage: "bolt.fill")
                }
                .buttonStyle(AssistantSecondaryButtonStyle())

                Button {
                    selectedTab = 1
                } label: {
                    Label("Open Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(AssistantSecondaryButtonStyle())

                if agentManager.executionState.status == .running {
                    Button {
                        // Existing agent runtime does not currently expose cancellation.
                    } label: {
                        Label("Running", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(AssistantPrimaryButtonStyle())
                }
            }
        }
        .padding(20)
        .assistantGlassCard()
    }

    private var statusPill: some View {
        Label(agentManager.executionState.status == .running ? "Executing" : "Idle", systemImage: agentManager.executionState.status == .running ? "waveform.path.ecg" : "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(agentManager.executionState.status == .running ? Color.orange.opacity(0.24) : Color.green.opacity(0.22))
            .clipShape(Capsule())
    }
}
