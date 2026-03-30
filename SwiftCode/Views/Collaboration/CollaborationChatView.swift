import SwiftUI

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let authorID: String
    let authorName: String
    let text: String
    let timestamp: Date
    let channel: String
    let snippet: String? // Optional code snippet

    init(authorID: String, authorName: String, text: String, channel: String = "General", snippet: String? = nil) {
        self.id = UUID()
        self.authorID = authorID
        self.authorName = authorName
        self.text = text
        self.timestamp = Date()
        self.channel = channel
        self.snippet = snippet
    }
}

@MainActor
class CollaborationChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []

    func sendMessage(authorID: String, authorName: String, text: String, channel: String, snippet: String? = nil) {
        let msg = ChatMessage(authorID: authorID, authorName: authorName, text: text, channel: channel, snippet: snippet)
        messages.append(msg)
        // In real app, this sends data over PeerSessionManager
    }
}

struct CollaborationChatView: View {
    @StateObject private var chatManager = CollaborationChatManager()
    @ObservedObject var manager: CollaborationManager
    @State private var messageText = ""
    @State private var selectedChannel = "General"

    let channels = ["General", "Files", "PRs"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Channel", selection: $selectedChannel) {
                ForEach(channels, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chatManager.messages.filter { $0.channel == selectedChannel }) { msg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(msg.authorName)
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                                Spacer()
                                Text(msg.timestamp, style: .time)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }

                            Text(msg.text)
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            if let snippet = msg.snippet {
                                Text(snippet)
                                    .font(.system(size: 10, design: .monospaced))
                                    .padding(6)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }

            Divider()

            HStack {
                TextField("Message \(selectedChannel)...", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    chatManager.sendMessage(authorID: manager.creatorID, authorName: "You", text: messageText, channel: selectedChannel)
                    messageText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
        .navigationTitle("Project Chat")
    }
}
