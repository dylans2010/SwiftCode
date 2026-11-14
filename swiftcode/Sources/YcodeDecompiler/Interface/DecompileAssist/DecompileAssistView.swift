import Foundation
import SwiftUI







public struct DecompileAssistView: View {
    private let state: DecompilerObservableState
    private let assistSession: DecompileAssistSession

    @State private var input = ""
    @State private var showToolEvents = false

    
    
    
    @MainActor
    public init(state: DecompilerObservableState) {
        self.state = state
        self.assistSession = DecompileAssistSession(decompilerSession: state.session)
    }

    public var body: some View {
        VStack(spacing: 0) {
            messageList
            if !assistSession.toolEvents.isEmpty {
                toolEventBar
            }
            if let error = assistSession.lastError {
                errorRow(error)
            }
            inputBar
        }
        .background(.regularMaterial)
    }

    

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if assistSession.conversation.isEmpty {
                        emptyState
                    } else {
                        ForEach(assistSession.conversation) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if assistSession.isProcessing,
                           let last = assistSession.conversation.last,
                           last.role == .assistant, last.content.isEmpty {
                            typingIndicator
                                .id("typing-indicator")
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: assistSession.conversation.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: assistSession.conversation.last?.content.count ?? 0) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: assistSession.toolEvents.count) { _, _ in
                if showToolEvents { scrollToBottom(proxy) }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = assistSession.conversation.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo("typing-indicator", anchor: .bottom)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Ask about this binary")
                .font(.headline)
            Text("Decompile Assist answers questions using the current analysis — selected functions, symbols, strings, and pseudocode.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            if state.binary == nil {
                Text("Import a binary to begin.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                suggestionChips
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        send(question)
                    } label: {
                        Text(question)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(assistSession.isProcessing)
                    .help("Send: \(question)")
                    .accessibilityLabel("Suggested question: \(question)")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var suggestedQuestions: [String] {
        if state.mode == .master {
            return [
                "Summarize the imports and exports of this binary.",
                "Which functions call the selected address?",
                "List the strings that look like file paths or URLs.",
                "Explain the control flow of the selected function.",
            ]
        }
        return [
            "What does this program do?",
            "Explain the selected function in plain language.",
            "What libraries does it use?",
            "Find anything suspicious in this binary.",
        ]
    }

    private var typingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Decompile Assist is thinking…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    

    private var toolEventBar: some View {
        DisclosureGroup(isExpanded: $showToolEvents) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    
                    ForEach(assistSession.toolEvents.suffix(50)) { event in
                        ToolEventRow(event: event)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .frame(maxHeight: 140)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tool activity")
                    .font(.caption.weight(.medium))
                Text("(\(assistSession.toolEvents.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .padding(.top, 2)
    }

    

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .textSelection(.enabled)
            Spacer(minLength: 4)
            if let lastUser = assistSession.conversation.last(where: { $0.role == .user }) {
                Button("Retry") {
                    send(lastUser.content)
                }
                .controlSize(.small)
                .disabled(assistSession.isProcessing)
                .help("Resend your last message")
                .accessibilityLabel("Retry last message")
            }
            Button {
                assistSession.dismissError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dismiss error")
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.08))
    }

    

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about this binary…", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit { send() }
                .disabled(assistSession.isProcessing)
                .accessibilityLabel("Decompile Assist message")

            if assistSession.isProcessing {
                Button {
                    Task { await assistSession.cancel() }
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop the current response")
                .accessibilityLabel("Stop generating")
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
                .disabled(!canSend)
                .help("Send message")
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !assistSession.isProcessing
    }

    

    
    
    private func send(_ explicit: String? = nil) {
        let text = (explicit ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !assistSession.isProcessing else { return }
        if explicit == nil { input = "" }

        let focus = DecompileAssistFocus(
            functionAddress: state.selectedFunctionAddress?.hexString,
            address: state.selectedAddress?.hexString,
            instructionRange: state.selectedInstructionRange.map {
                "0x" + String($0.lowerBound, radix: 16) + "-0x" + String($0.upperBound, radix: 16)
            }
        )
        Task { @MainActor in
            let context = await DecompileAssistContext.build(session: state.session, focus: focus)
            await assistSession.send(text, context: context)
        }
    }
}





private struct MessageBubble: View {
    let message: DecompileAssistMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.content)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                Text(message.content.isEmpty ? "…" : message.content)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 48)
            }
        case .system:
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}


private struct ToolEventRow: View {
    let event: DecompileAssistToolEvent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(event.toolName)
                .font(.system(.caption, design: .monospaced))
            if !event.detail.isEmpty {
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.toolName): \(event.state.rawValue)\(event.detail.isEmpty ? "" : ", \(event.detail)")")
    }

    private var icon: String {
        switch event.state {
        case .started: return "ellipsis.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch event.state {
        case .started: return .secondary
        case .completed: return .green
        case .failed: return .red
        }
    }
}
