import SwiftUI

public struct AssistMainView: View {
    @StateObject private var assistManager = AssistManager.shared
    @State private var inputText: String = ""
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(assistManager.messages) { message in
                                    AssistChatBubble(message: message)
                                }

                                if assistManager.isProcessing {
                                    HStack {
                                        ProgressView().scaleEffect(0.8)
                                        Text("Thinking…").font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding()
                            .id("Bottom")
                        }
                        .onChange(of: assistManager.messages.count) {
                            withAnimation {
                                proxy.scrollTo("Bottom", anchor: .bottom)
                            }
                        }
                    }

                    if let plan = assistManager.currentPlan {
                        AssistPlanView(plan: plan)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Input Area
                    HStack(spacing: 12) {
                        TextField("Ask SwiftCode Assist...", text: $inputText, axis: .vertical)
                            .padding(10)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            .lineLimit(1...5)
                            .foregroundStyle(.white)

                        Button {
                            Task {
                                let text = inputText
                                inputText = ""
                                await assistManager.sendMessage(text)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundStyle(inputText.isEmpty ? .secondary : .orange)
                        }
                        .disabled(inputText.isEmpty || assistManager.isProcessing)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("SwiftCode Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        assistManager.clearChat()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AssistChatBubble: View {
    let message: AssistMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user ? Color.blue.opacity(0.3) : Color.white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .foregroundStyle(.white)
                    .font(.subheadline)

                Text(message.timestamp, style: .time)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            if message.role != .user { Spacer() }
        }
    }
}
