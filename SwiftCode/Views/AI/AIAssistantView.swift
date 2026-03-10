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
    @State private var agentIterationCount = 0
    @State private var showCustomModelSheet = false
    @State private var customModelDraft = ""
    private let maxAgentIterations = 15

    var body: some View {
        VStack(spacing: 0) {
            // Header
            assistantHeader

            Divider().opacity(0.3)

            // Mode picker
            modePicker

            Divider().opacity(0.3)

            // Agent iteration banner (only in agent mode while loading)
            if selectedMode == .agent && isLoading && agentIterationCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "cpu.fill")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text("Agent loop · iteration \(agentIterationCount)/\(maxAgentIterations)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.08))

                Divider().opacity(0.3)
            }

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
        .sheet(isPresented: $showCustomModelSheet) {
            customModelSheet
        }
    }

    // MARK: - Subviews

    private var assistantHeader: some View {
        HStack {
            Image(systemName: selectedMode == .agent ? "cpu.fill" : "sparkles")
                .foregroundStyle(selectedMode == .agent ? .cyan : .purple)
            Text(selectedMode == .agent ? "AI Agent" : "AI Assistant")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()

            // Context toggle (hidden in agent mode – agent uses its own tools)
            if selectedMode != .agent {
                Button {
                    includeContext.toggle()
                } label: {
                    Label(includeContext ? "With Context" : "No Context",
                          systemImage: includeContext ? "doc.text.fill" : "doc.text")
                        .font(.caption)
                        .foregroundStyle(includeContext ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation { messages.removeAll(); agentIterationCount = 0 }
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
                .tint(selectedMode == .agent ? .cyan : .purple)
            Text(selectedMode == .agent ? "Agent thinking…" : "Thinking…")
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
                    // Custom model option
                    Divider()
                    if !settings.customModel.isEmpty {
                        Button {
                            settings.selectedModel = settings.customModel
                        } label: {
                            HStack {
                                Text("Custom: \(settings.customModel)")
                                    .lineLimit(1)
                                if settings.selectedModel == settings.customModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Button {
                        customModelDraft = settings.customModel
                        showCustomModelSheet = true
                    } label: {
                        Label("Set Custom Model…", systemImage: "plus.circle")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentModelName)
                            .font(.caption2)
                            .foregroundStyle(settings.isUsingCustomModel ? .cyan : .purple)
                            .lineLimit(1)
                        if settings.isUsingCustomModel {
                            Image(systemName: "cpu.fill")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                    }
                }
                Spacer()
            }

            // Agent mode hint strip
            if selectedMode == .agent {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.cyan.opacity(0.8))
                    Text("Agent can read & write files, generate code, and use \(AgentTool.all.count) tools autonomously.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text(selectedMode == .agent ? "What should the agent do?" : "Ask the AI…")
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
                        .foregroundStyle(isLoading ? .red : (inputText.isEmpty ? .secondary : (selectedMode == .agent ? .cyan : .purple)))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading)
            }
        }
        .padding(12)
    }

    // MARK: - Custom Model Sheet

    private var customModelSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter any valid OpenRouter model ID. You can browse all available models at openrouter.ai/models.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("e.g. mistralai/mistral-7b-instruct", text: $customModelDraft)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                // Popular model suggestions
                Text("Popular models:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach([
                        "mistralai/mistral-7b-instruct",
                        "mistralai/mixtral-8x7b-instruct",
                        "qwen/qwen-2.5-72b-instruct",
                        "cohere/command-r-plus",
                        "perplexity/llama-3.1-sonar-large-128k-online",
                        "microsoft/phi-3-medium-128k-instruct"
                    ], id: \.self) { modelId in
                        Button {
                            customModelDraft = modelId
                        } label: {
                            Text(modelId)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    customModelDraft == modelId
                                        ? Color.cyan.opacity(0.2)
                                        : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .foregroundStyle(customModelDraft == modelId ? .cyan : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(red: 0.1, green: 0.1, blue: 0.14))
            .navigationTitle("Custom AI Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCustomModelSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Model") {
                        let trimmed = customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        settings.customModel   = trimmed
                        settings.selectedModel = trimmed
                        showCustomModelSheet   = false
                    }
                    .disabled(customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !isLoading else { return }
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        if selectedMode == .agent {
            runAgentLoop(userPrompt: prompt)
        } else {
            runSingleChat(userPrompt: prompt)
        }
    }

    // MARK: - Standard (non-agent) Chat

    private func runSingleChat(userPrompt: String) {
        var fullPrompt = userPrompt
        if includeContext, let node = projectManager.activeFileNode {
            fullPrompt = "File: \(node.path)\n\n```swift\n\(projectManager.activeFileContent)\n```\n\n\(userPrompt)"
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
                    await MainActor.run { streamingResponse += token }
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

    // MARK: - Agent Loop

    private func runAgentLoop(userPrompt: String) {
        messages.append(AIMessage(role: "user", content: userPrompt))
        inputText = ""
        isLoading = true
        agentIterationCount = 0
        streamingResponse = ""

        Task {
            await executeAgentLoop()
        }
    }

    private func executeAgentLoop() async {
        let systemPrompt = AgentToolService.buildSystemPrompt()

        for iteration in 1...maxAgentIterations {
            await MainActor.run {
                agentIterationCount = iteration
                streamingResponse   = ""
            }

            // Build the API-compatible message list
            let apiMessages = buildAgentAPIMessages()

            var assistantReply = ""
            do {
                try await OpenRouterService.shared.streamChat(
                    messages: apiMessages,
                    model: settings.selectedModel,
                    systemPrompt: systemPrompt
                ) { token in
                    await MainActor.run {
                        streamingResponse += token
                        assistantReply     = streamingResponse
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError    = true
                    streamingResponse   = ""
                    isLoading           = false
                    agentIterationCount = 0
                }
                return
            }

            // Capture final streamed text
            assistantReply = await MainActor.run { streamingResponse }
            await MainActor.run {
                if !assistantReply.isEmpty {
                    messages.append(AIMessage(role: "assistant", content: assistantReply))
                }
                streamingResponse = ""
            }

            // Parse and execute tool calls
            let toolCalls = parseToolCalls(from: assistantReply)
            guard !toolCalls.isEmpty else {
                // No more tool calls – agent is done
                await MainActor.run { isLoading = false; agentIterationCount = 0 }
                return
            }

            for call in toolCalls {
                // Add a visual tool-call indicator
                let paramSummary = call.parameters.isEmpty
                    ? ""
                    : call.parameters.map { "\($0.key): \"\($0.value)\"" }.joined(separator: ", ")
                await MainActor.run {
                    messages.append(
                        AIMessage(role: "tool_call",
                                  content: "🔧 **\(call.name)**(\(paramSummary))")
                    )
                }

                // Execute the tool
                let result = await AgentToolService.shared.execute(
                    toolName: call.name,
                    parameters: call.parameters,
                    projectManager: projectManager
                )

                // Add the result as a tool_result message (sent back to AI as "user")
                let resultText = """
                    <tool_result>
                    {"tool": "\(call.name)", "success": \(!result.isError), "result": \(jsonStringLiteral(result.result))}
                    </tool_result>
                    """
                await MainActor.run {
                    messages.append(AIMessage(role: "tool_result", content: resultText))
                }
            }
        }

        // Exceeded max iterations
        await MainActor.run {
            messages.append(AIMessage(role: "assistant",
                content: "⚠️ Reached the maximum of \(maxAgentIterations) agent iterations."))
            isLoading           = false
            agentIterationCount = 0
        }
    }

    /// Build the list of messages sent to the API, collapsing tool roles into user/assistant.
    private func buildAgentAPIMessages() -> [AIMessage] {
        messages.compactMap { msg in
            switch msg.role {
            case "user", "assistant":
                return msg
            case "tool_result":
                // Send back to the AI as a "user" turn
                return AIMessage(id: msg.id, role: "user", content: msg.content, timestamp: msg.timestamp)
            default:
                // "tool_call" display messages are visual-only, not sent to API
                return nil
            }
        }
    }

    /// Parse `<tool_call>…</tool_call>` JSON blocks from an AI response.
    private func parseToolCalls(from text: String) -> [AgentToolCall] {
        var calls: [AgentToolCall] = []
        var remaining = text

        while let start = remaining.range(of: "<tool_call>"),
              let end   = remaining.range(of: "</tool_call>",
                                          range: start.upperBound..<remaining.endIndex) {
            let jsonStr = String(remaining[start.upperBound..<end.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = jsonStr.data(using: .utf8),
               let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = obj["name"] as? String {
                let params = obj["parameters"] as? [String: Any] ?? [:]
                calls.append(AgentToolCall(name: name, parameters: params))
            }

            remaining = String(remaining[end.upperBound...])
        }

        return calls
    }

    /// Escape a string for embedding as a JSON string literal value.
    private func jsonStringLiteral(_ text: String) -> String {
        if let data   = try? JSONSerialization.data(withJSONObject: text),
           let result = String(data: data, encoding: .utf8) {
            return result
        }
        // Fallback: manual escaping
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }


    private func insertCodeToEditor(_ code: String) {
        projectManager.activeFileContent = code
        projectManager.saveCurrentFile(content: code)
    }

    private var currentModelName: String {
        if let preset = OpenRouterModel.defaults.first(where: { $0.id == settings.selectedModel }) {
            return preset.name
        }
        // Truncate long custom IDs for display
        let id = settings.selectedModel
        return id.count > 28 ? "…" + id.suffix(25) : id
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: AIMessage
    let onInsertCode: (String) -> Void

    private var isUser: Bool       { message.role == "user" }
    private var isToolCall: Bool   { message.role == "tool_call" }
    private var isToolResult: Bool { message.role == "tool_result" }

    var body: some View {
        Group {
            if isToolCall {
                // Tool-call indicator row
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(message.content.hasPrefix("🔧 ")
                         ? String(message.content.dropFirst(3))
                         : message.content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.9))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else if isToolResult {
                // Tool-result compact row
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Tool result received")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            } else {
                // Standard user / assistant bubble
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
