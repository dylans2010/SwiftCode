import SwiftUI

struct AIAssistantView: View {
    @StateObject private var controller = ChatController.shared
    @State private var showHistory = false
    @State private var showAgentInterface = false
    @State private var showNewAgentUI = false

    var body: some View {
        NavigationStack {
            Group {
                if AppSettings.shared.appleIntelligenceEnabled && DeviceUtilityManager.shared.isAppleIntelligenceSupported() {
                    OnDeviceAIView(controller: controller)
                } else {
                    AICoreView()
                }
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chat History") { showHistory = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Agent Mode (Legacy)") { showAgentInterface = true }
                        Button("Agent Mode (New)") { showNewAgentUI = true }
                    } label: {
                        Label("Agent", systemImage: "cpu")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                ChatHistorySheet(messages: controller.messages)
            }
            .sheet(isPresented: $showAgentInterface) {
                NavigationStack {
                    AgentInterfaceView()
                        .navigationTitle("Agent Interface")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showNewAgentUI) {
                NavigationStack { AgentNewView() }
                    .presentationDetents([.large])
            }
        }
    }
}

private struct ChatHistorySheet: View {
    let messages: [ChatMessage]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if messages.isEmpty {
                    Text("No messages yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.role == .assistant ? "Assistant" : "You")
                                .font(.caption)
                                .foregroundStyle(message.role == .assistant ? .secondary : Color.accentColor)
                            Text(message.content)
                            Text(Self.timestampFormatter.string(from: message.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
