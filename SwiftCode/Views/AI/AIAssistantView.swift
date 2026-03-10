import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var settings: AppSettings

    @State private var messages: [AIMessage] = []
    @State private var inputText = ""
    @State private var selectedMode: AgentMode = .generate
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var includeContext = true
    @State private var streamingResponse = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            assistantHeader

            Divider().opacity(0.3)

            // Mode picker
            modePicker

            Divider().opacity(0.3)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty && streamingResponse.isEmpty {
                            emptyStateView
                        }

                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                onInsertCode: insertCodeToEditor
                            )
                        }

                        if isLoading && !streamingResponse.isEmpty {
                            MessageBubbleView(
                                message: AIMessage(role: "assistant", content: streamingResponse),
                                onInsertCode: insertCodeToEditor
                            )
                            .id("streaming")
                        }

                        if isLoading && streamingResponse.isEmpty {
                            loadingIndicator
                                .id("loading")
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: streamingResponse) { _ in
                    withAnimation { proxy.scrollTo("streaming") }
                }
            }

            Divider().opacity(0.3)

            // Input
            inputArea
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
    }

    // MARK: - Subviews

    private var assistantHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text("AI Assistant")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()

            // Context toggle
            Button {
                includeContext.toggle()
            } label: {
                Label(includeContext ? "With Context" : "No Context",
                      systemImage: includeContext ? "doc.text.fill" : "doc.text")
                    .font(.caption)
                    .foregroundStyle(includeContext ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { messages.removeAll() }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AgentMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMode = mode
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.caption2)
                            Text(mode.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selectedMode == mode
                                ? Color.purple.opacity(0.6)
                                : Color.white.opacity(0.06),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedMode == mode ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedMode.icon)
                .font(.system(size: 36))
                .foregroundStyle(.purple.opacity(0.7))
            Text(selectedMode.rawValue)
                .font(.headline)
                .foregroundStyle(.white)
            Text(selectedMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.purple)
            Text("Thinking...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var inputArea: some View {
        VStack(spacing: 8) {
            // Model selector
            HStack {
                Text("Model:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(OpenRouterModel.defaults) { model in
                        Button {
                            settings.selectedModel = model.id
                        } label: {
                            HStack {
                                Text(model.name)
                                if settings.selectedModel == model.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(currentModelName)
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Ask the AI…")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $inputText)
                        .font(.callout)
                        .frame(minHeight: 60, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                }
                .padding(4)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isLoading ? .red : (inputText.isEmpty ? .secondary : .purple))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading)
            }
        }
        .padding(12)
    }

    // MARK: - Actions

    private func sendMessage() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        var fullPrompt = prompt
        if includeContext, let node = projectManager.activeFileNode {
            fullPrompt = "File: \(node.path)\n\n```swift\n\(projectManager.activeFileContent)\n```\n\n\(prompt)"
        }

        let userMessage = AIMessage(role: "user", content: fullPrompt)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        streamingResponse = ""

        Task {
            do {
                try await OpenRouterService.shared.streamChat(
                    messages: messages,
                    model: settings.selectedModel,
                    systemPrompt: selectedMode.systemPrompt
                ) { token in
                    await MainActor.run {
                        streamingResponse += token
                    }
                }

                await MainActor.run {
                    if !streamingResponse.isEmpty {
                        messages.append(AIMessage(role: "assistant", content: streamingResponse))
                    }
                    streamingResponse = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    streamingResponse = ""
                    isLoading = false
                }
            }
        }
    }

    private func insertCodeToEditor(_ code: String) {
        projectManager.activeFileContent = code
        projectManager.saveCurrentFile(content: code)
    }

    private var currentModelName: String {
        OpenRouterModel.defaults.first { $0.id == settings.selectedModel }?.name ?? settings.selectedModel
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: AIMessage
    let onInsertCode: (String) -> Void

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.top, 4)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                ForEach(parseBlocks(message.content), id: \.id) { block in
                    switch block.type {
                    case .text:
                        Text(block.content)
                            .font(.callout)
                            .foregroundStyle(isUser ? .white : .primary)
                            .padding(10)
                            .background(
                                isUser
                                    ? Color.purple.opacity(0.5)
                                    : Color.white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    case .code(let lang):
                        CodeBlockView(
                            code: block.content,
                            language: lang,
                            onInsert: { onInsertCode(block.content) }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Parse Blocks

    private func parseBlocks(_ content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var remaining = content

        while !remaining.isEmpty {
            if let codeStart = remaining.range(of: "```") {
                let textBefore = String(remaining[remaining.startIndex..<codeStart.lowerBound])
                if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(ContentBlock(type: .text, content: textBefore.trimmingCharacters(in: .whitespaces)))
                }

                remaining = String(remaining[codeStart.upperBound...])
                var lang = ""
                if let newline = remaining.firstIndex(of: "\n") {
                    lang = String(remaining[remaining.startIndex..<newline]).trimmingCharacters(in: .whitespaces)
                    remaining = String(remaining[remaining.index(after: newline)...])
                }

                if let codeEnd = remaining.range(of: "```") {
                    let code = String(remaining[remaining.startIndex..<codeEnd.lowerBound])
                    blocks.append(ContentBlock(type: .code(lang), content: code))
                    remaining = String(remaining[codeEnd.upperBound...])
                } else {
                    blocks.append(ContentBlock(type: .code(lang), content: remaining))
                    remaining = ""
                }
            } else {
                if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(ContentBlock(type: .text, content: remaining))
                }
                remaining = ""
            }
        }

        return blocks
    }
}

struct ContentBlock: Identifiable {
    enum BlockType {
        case text
        case code(String)
    }
    let id = UUID()
    let type: BlockType
    let content: String
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String
    let onInsert: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.06), in: Capsule())
                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onInsert()
                } label: {
                    Label("Insert", systemImage: "arrow.down.doc.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.15, green: 0.15, blue: 0.20))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .padding(10)
            }
            .background(Color(red: 0.11, green: 0.11, blue: 0.15))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
