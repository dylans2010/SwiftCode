import SwiftUI

public struct AssistMainView: View {
    @StateObject private var manager = AssistManager.shared
    @State private var inputText: String = ""
    @State private var isEnhancingPrompt = false
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.35), .purple.opacity(0.30), .pink.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(Color(uiColor: .systemBackground).opacity(0.78))

                VStack(spacing: 0) {
                    // Header with execution status
                    headerArea

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(manager.messages) { message in
                                    AssistChatBubble(message: message)
                                }

                                AssistPlannerView()

                                if let error = manager.lastError {
                                    AssistErrorBubble(error: error)
                                }

                                if manager.isProcessing {
                                    thinkingIndicator
                                }
                            }
                            .padding()
                            .blur(radius: manager.takeoverReason != nil ? 10 : 0)
                            .overlay {
                                if let reason = manager.takeoverReason {
                                    AssistUserTakeover(
                                        reason: reason,
                                        onResume: {
                                            manager.takeoverReason = nil
                                            // Resume logic would go here, currently it just clears the UI block
                                        },
                                        onAbort: {
                                            manager.takeoverReason = nil
                                            manager.clearChat()
                                        }
                                    )
                                }
                            }
                            .id("Bottom")
                        }
                        .onChange(of: manager.messages.count, initial: false) { _, _ in
                            withAnimation { proxy.scrollTo("Bottom", anchor: .bottom) }
                        }
                    }

                    // Bottom Tool Feed & Input
                    VStack(spacing: 12) {
                        if !manager.logger.logs.isEmpty {
                            MiniLogFeed(logger: manager.logger)
                        }

                        inputArea
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("SwiftCode Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { manager.clearChat() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { AssistSettingsView() }
            }
        }
    }

    private var headerArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(manager.isProcessing ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(manager.isProcessing ? "Agent Active" : "Agent Ready")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(manager.selectedModel.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(manager.isProcessing ? "Agent executing tools..." : "Planning next steps...")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                if let lastLog = manager.logger.logs.last {
                    Text(lastLog.message)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            Button {
                expandPrompt()
            } label: {
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
            }
            .disabled(inputText.isEmpty || manager.isProcessing)

            ZStack {
                TextField("What should I build next?", text: $inputText, axis: .vertical)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...6)
                    .disabled(manager.isProcessing || isEnhancingPrompt)

                if isEnhancingPrompt {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.purple)
                                Text("Enhancing prompt with Apple Intelligence...")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 16)
                        )
                        .overlay(
                            LinearGradient(
                                colors: [.blue.opacity(0.35), .purple.opacity(0.35), .pink.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .blendMode(.plusLighter)
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: isEnhancingPrompt)
                

            Button {
                let text = inputText
                inputText = ""
                Task {
                    await manager.sendMessage(text)
                }
            } label: {
                Group {
                    if manager.isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                }
                .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.primary)
            }
            .disabled(inputText.isEmpty || manager.isProcessing)
        }
    }

    private func expandPrompt() {
        let currentPrompt = inputText
        guard !currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isEnhancingPrompt = true
        }
        Task {
            let enhancedPrompt = await PromptEnhancer.enhancePrompt(userInput: currentPrompt)
            await MainActor.run {
                inputText = enhancedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    isEnhancingPrompt = false
                }
            }
        }
    }
}

struct AssistExecutionTimelineView: View {
    let plan: AssistExecutionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(plan.goal, systemImage: "target")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.steps) { step in
                    HStack(spacing: 12) {
                        statusIcon(for: step.status)
                            .foregroundStyle(statusColor(for: step.status))

                        VStack(alignment: .leading) {
                            Text(step.description)
                                .font(.subheadline)
                            Text(step.toolId)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusIcon(for status: AssistExecutionStatus) -> Image {
        switch status {
        case .pending: return Image(systemName: "circle")
        case .running: return Image(systemName: "arrow.triangle.2.circlepath")
        case .completed: return Image(systemName: "checkmark.circle.fill")
        case .failed: return Image(systemName: "xmark.circle.fill")
        case .skipped: return Image(systemName: "slash.circle")
        }
    }

    private func statusColor(for status: AssistExecutionStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .orange
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

private struct AssistChatBubble: View {
    let message: AssistMessage

    private var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return Color.primary.opacity(0.12)
        case .assistant: return Color.secondary.opacity(0.12)
        case .system: return Color.blue.opacity(0.16)
        }
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(message.role.rawValue.capitalized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.content)
                .font(.body)
                
                .padding(12)
                .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct ToolResultPreview: View {
    let step: AssistExecutionStep
    let data: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.caption)
                Text(step.toolId)
                    .font(.caption.bold().monospaced())
                Spacer()
                Text(step.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let content = data[AssistToolDataKey.content] {
                CodePreview(title: "File: \(step.input["path"] ?? "content")", content: content)
            } else if let explanation = data[AssistToolDataKey.explanation] {
                Text(explanation)
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            } else if let results = data[AssistToolDataKey.searchResults] {
                CodePreview(title: "Search Results", content: results)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CodePreview: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Text(content)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
            }
        }
    }
}

struct AssistErrorBubble: View {
    let error: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Execution Error")
                    .font(.caption.bold())
                Text(error)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MiniLogFeed: View {
    @ObservedObject var logger: AssistLogger

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(logger.logs.suffix(2)) { log in
                HStack {
                    Text(log.toolId ?? "system")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .background(Color.orange.opacity(0.2))
                    Text(log.message)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
