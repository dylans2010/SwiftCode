import SwiftUI

struct AIAssistantView: View {
    @StateObject private var controller = ChatController()
    @State private var inputText = ""
    @State private var useContext = true
    @State private var showCommandList = false
    @State private var showHistory = false
    @State private var showAgentInterface = false

    private let slashCommands = ["/explain", "/summarize", "/rewrite", "/debug"]

    private var filteredCommands: [String] {
        guard inputText.hasPrefix("/") else { return [] }
        let query = inputText.dropFirst().lowercased()
        if query.isEmpty { return slashCommands }
        return slashCommands.filter { $0.dropFirst().lowercased().contains(query) }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !controller.isGenerating
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(controller.messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            if controller.isGenerating {
                                TypingIndicatorBubble()
                                    .id("typing-indicator")
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .onChange(of: controller.messages.count) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(controller.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: controller.isGenerating) {
                        if controller.isGenerating {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    if showCommandList && !filteredCommands.isEmpty {
                        SlashCommandList(commands: filteredCommands) { command in
                            inputText = "\(command) "
                            showCommandList = false
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Message AI (type / for commands)", text: $inputText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onChange(of: inputText) {
                                showCommandList = inputText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
                            }

                        Toggle("Context", isOn: $useContext)
                            .toggleStyle(.switch)
                            .labelsHidden()

                        Button {
                            let text = inputText
                            inputText = ""
                            showCommandList = false
                            Task {
                                await controller.sendMessage(text, useContext: useContext)
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 40, height: 40)
                                .scaleEffect(canSend ? 1.0 : 0.92)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Circle())
                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: canSend)
                        .disabled(!canSend)
                    }
                }
                .padding(12)
                .background(.regularMaterial)
            }
            .animation(.easeInOut(duration: 0.2), value: controller.messages)
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chat History") {
                        showHistory = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Agent Interface") {
                        showAgentInterface = true
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                ChatHistoryView(messages: controller.messages)
            }
            .sheet(isPresented: $showAgentInterface) {
                NavigationStack {
                    AgentInterfaceView()
                        .navigationTitle("Agent Interface")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
            }
        }
    }
}


private struct ChatHistoryView: View {
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
                        ChatHistoryRow(message: message)
                    }
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
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

private struct ChatHistoryRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .assistant ? "Assistant" : "You")
                .font(.caption)
                .foregroundStyle(message.role == .assistant ? .secondary : Color.accentColor)
            Text(message.content)
                .font(.body)
            Text(ChatHistoryView.timestampFormatter.string(from: message.timestamp))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
