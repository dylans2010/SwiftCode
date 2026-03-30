import SwiftUI

public struct AssistMainView: View {
    @StateObject private var manager = AssistManager.shared
    @State private var inputText: String = ""
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Modern Dark Background
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with execution status
                    headerArea

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(manager.messages) { message in
                                    AssistChatBubble(message: message)
                                }

                                if let plan = manager.session.currentPlan {
                                    AssistExecutionTimelineView(plan: plan)

                                    // If any step has a diff or modified content, show it
                                    ForEach(plan.steps) { step in
                                        if let result = step.result, let content = result.data?["content"], step.toolId == "file_read" {
                                            VStack(alignment: .leading) {
                                                Text("File Preview: \(step.input["path"] ?? "")")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.secondary)
                                                Text(content)
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.3))
                                                    .cornerRadius(8)
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }

                                if manager.isProcessing {
                                    thinkingIndicator
                                }
                            }
                            .padding()
                            .id("Bottom")
                        }
                        .onChange(of: manager.messages.count) {
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
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
    }

    private var thinkingIndicator: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.orange)
            Text("Planning next steps…")
                .font(.caption)
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("What should I build next?", text: $inputText, axis: .vertical)
                .padding(12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                .lineLimit(1...6)
                .foregroundStyle(.white)

            Button {
                let text = inputText
                inputText = ""
                Task { await manager.sendMessage(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.orange)
            }
            .disabled(inputText.isEmpty || manager.isProcessing)
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
        .background(Color.white.opacity(0.05))
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
        case .user: return Color.orange.opacity(0.85)
        case .assistant: return Color.white.opacity(0.12)
        case .system: return Color.blue.opacity(0.2)
        }
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(message.role.rawValue.capitalized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.content)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
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
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
