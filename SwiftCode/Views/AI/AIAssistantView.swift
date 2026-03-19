import SwiftUI

struct AIAssistantView: View {
    @StateObject private var controller = ChatController.shared
    @State private var showHistory = false
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewAgentUI = true
                    } label: {
                        Label("Workspace", systemImage: "square.grid.2x2.fill")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                ChatHistorySheet(messages: controller.messages)
            }
            .sheet(isPresented: $showNewAgentUI) {
                NavigationStack {
                    AgentNewView()
                }
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
            ZStack {
                AssistantTheme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AssistantSectionHeader(
                            eyebrow: "Conversation history",
                            title: "Recent AI sessions",
                            subtitle: "Review prior prompts and responses without exposing any sensitive keys or settings."
                        )

                        if messages.isEmpty {
                            ContentUnavailableView(
                                "No Messages Yet",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("Start a conversation to build your assistant history.")
                            )
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .assistantGlassCard()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    ChatMessageBubble(message: message)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
