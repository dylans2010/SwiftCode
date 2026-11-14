import SwiftUI
import YcodeAssistant
import YcodeIDECore

public struct AssistSidebarView: View {
    @State private var manager = AssistManager.shared
    @State private var history = AssistConversationHistory.shared
    @State private var inputText: String = ""
    @State private var attachedFiles: [AgentFileContext] = []
    @State private var showTodoList: Bool = true
    @State private var showConversationsSheet: Bool = false
    @State private var showCustomModelPicker: Bool = false
    @State private var showingFilePickerSheet: Bool = false
    @State private var showSpeechUI: Bool = false
    @State private var isProcessingFiles: Bool = false

    public init() {}

    private var currentModelShortName: String {
        AssistModelRouter.shared.currentRuntimeModel?.displayName ?? "GPT-5"
    }

    public var body: some View {
        VStack(spacing: 0) {
            AssistModernHeaderView(
                showTodoList: $showTodoList,
                onOpenHistory: {
                    showConversationsSheet = true
                },
                onNewTask: {
                    attachedFiles = []
                    inputText = ""
                    manager.clearChat()
                    let newID = UUID()
                    history.activeConversationID = newID
                }
            )

            Divider().opacity(0.3)

            ZStack(alignment: .top) {
                conversationFeed

                if showTodoList {
                    AssistTodoListCard(isPresented: $showTodoList)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }

            Divider().opacity(0.3)

            AssistModernComposerView(
                text: $inputText,
                attachedFiles: $attachedFiles,
                isProcessing: manager.isProcessing,
                currentModelName: currentModelShortName,
                onSend: {
                    submitMessage()
                },
                onAttach: {
                    showingFilePickerSheet = true
                },
                onVoiceInput: {
                    showSpeechUI = true
                },
                onSelectModel: {
                    showCustomModelPicker.toggle()
                }
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showConversationsSheet) {
            AssistConversationsSheet()
        }
        .sheet(isPresented: $showingFilePickerSheet) {
            AddFilesAgentContext(attachedFiles: $attachedFiles, isProcessingFiles: $isProcessingFiles)
        }
        .popover(isPresented: $showSpeechUI, arrowEdge: .bottom) {
            AssistSpeechUI(
                onSend: { text in
                    Task { await manager.sendMessage(text) }
                },
                onInsert: { text in
                    if inputText.isEmpty {
                        inputText = text
                    } else {
                        inputText += " " + text
                    }
                }
            )
        }
        .popover(isPresented: $showCustomModelPicker, arrowEdge: .bottom) {
            AssistCustomModelPickerPopover(
                selectedModelID: currentModelShortName,
                onSelect: { _ in
                    showCustomModelPicker = false
                },
                onDismiss: {
                    showCustomModelPicker = false
                }
            )
        }
    }

    @ViewBuilder
    private var conversationFeed: some View {
        if manager.messages.isEmpty {
            emptyStateView
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Color.clear.frame(height: showTodoList ? 10 : 0)

                        ForEach(manager.messages) { message in
                            messageBubble(for: message)
                        }

                        if manager.isProcessing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text("Thinking…")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }

                        Color.clear.frame(height: 8).id("BottomID")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .onChange(of: manager.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("BottomID", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            Text("New Conversation")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text("with \(currentModelShortName)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    @ViewBuilder
    private func messageBubble(for message: AssistMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack(spacing: 5) {
                if message.role == .user {
                    Spacer()
                    Text("You")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text("Assist")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }

            if let activity = message.activityGroup, activity.hasContent {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(activity.tools) { tool in
                        let summary = tool.purpose.isEmpty ? tool.toolId : tool.purpose
                        let kind: AssistToolSummaryItem.Kind = tool.toolId.contains("search") ? .search : (tool.toolId.contains("terminal") ? .terminal : .generic)
                        AssistToolSummaryCard(
                            item: AssistToolSummaryItem(
                                type: kind,
                                title: tool.displayLabel ?? tool.toolId,
                                summary: summary,
                                details: tool.result.isEmpty ? nil : tool.result,
                                duration: tool.duration
                            )
                        )
                    }

                    ForEach(activity.files) { file in
                        AssistEditedFileDiffCard(
                            item: AssistEditedFileDiffItem(
                                filename: (file.filePath as NSString).lastPathComponent,
                                path: file.filePath,
                                addedLines: file.addedLines,
                                deletedLines: file.deletedLines,
                                changeKind: file.addedLines > 0 && file.deletedLines == 0 ? .added : .modified,
                                abstract: file.summary.isEmpty ? nil : file.summary,
                                previewContent: file.diffText.isEmpty ? nil : file.diffText
                            )
                        )
                    }
                }
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(
                        message.role == .user
                            ? Color.accentColor.opacity(0.12)
                            : Color.primary.opacity(0.04)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func submitMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        let files = attachedFiles
        attachedFiles = []
        Task {
            await manager.sendMessage(text, attachments: files)
        }
    }
}
