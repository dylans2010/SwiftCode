import SwiftUI

public struct AssistMainView: View {
    @StateObject private var assistManager = AssistManager.shared
    @State private var inputText: String = ""
    @State private var showTools = false
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                VStack(spacing: 0) {
                    AssistHeaderCard(
                        modelName: assistManager.selectedModel.displayName,
                        provider: assistManager.selectedModel.provider,
                        tools: assistManager.availableTools,
                        showTools: $showTools
                    )
                    .padding([.horizontal, .top])

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
                                .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.orange)
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
                ToolbarItem(placement: .principal) {
                    Text("Assist")
                        .font(.headline)
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

private struct AssistHeaderCard: View {
    let modelName: String
    let provider: String
    let tools: [AssistTool]
    @Binding var showTools: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(provider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(showTools ? "Hide Tools" : "Show Tools") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTools.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
            }

            if showTools {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tools) { tool in
                            Text(tool.rawValue)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.18), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
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
