import SwiftUI

struct AIAssistantView: View {
    @StateObject private var controller = ChatController()
    @State private var inputText = ""
    @State private var useContext = true
    @State private var showCommandList = false

    private let slashCommands = ["/explain", "/summarize", "/rewrite", "/debug"]

    private var filteredCommands: [String] {
        guard inputText.hasPrefix("/") else { return [] }
        let query = inputText.dropFirst().lowercased()
        if query.isEmpty { return slashCommands }
        return slashCommands.filter { $0.dropFirst().lowercased().contains(query) }
    }

    var body: some View {
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
                    .padding(.vertical, 10)
                }
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
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: inputText) {
                            showCommandList = inputText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
                        }

                    Toggle("Context", isOn: $useContext)
                        .toggleStyle(.switch)
                        .labelsHidden()

                    Button("Send") {
                        let text = inputText
                        inputText = ""
                        showCommandList = false
                        Task {
                            await controller.sendMessage(text, useContext: useContext)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isGenerating)
                }
            }
            .padding(12)
        }
        .animation(.easeInOut(duration: 0.2), value: controller.messages)
        .navigationTitle("AI Assistant")
    }
}
