import SwiftUI

struct ChatAIInterfaceView: View {
    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isTyping = false

    private let storageKey = "com.swiftcode.chatHistory"

    struct ChatMessage: Identifiable, Codable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date

        init(role: String, content: String) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                        }

                        if isTyping {
                            HStack {
                                Text("AI Is Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    loadHistory()
                }
                .onChange(of: messages.count) { _ in
                    saveHistory()
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("Chat", text: $input)
                    .textFieldStyle(.roundedBorder)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(input.isEmpty || isTyping)
            }
            .padding()
        }
    }

    private func sendMessage() {
        let userMsg = ChatMessage(role: "user", content: input)
        messages.append(userMsg)
        let prompt = input
        input = ""
        isTyping = true

        Task {
            do {
                let response = try await LLMService.shared.generateResponse(prompt: prompt, useContext: true)
                let aiMsg = ChatMessage(role: "assistant", content: response)
                messages.append(aiMsg)
            } catch {
                let errorMsg = ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)")
                messages.append(errorMsg)
            }
            isTyping = false
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decoded
        }
    }
}

struct ChatBubble: View {
    let message: ChatAIInterfaceView.ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer() }

            Text(message.content)
                .padding(12)
                .background(message.role == "user" ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(message.role == "user" ? .white : .primary)
                .cornerRadius(16)

            if message.role != "user" { Spacer() }
        }
    }
}
