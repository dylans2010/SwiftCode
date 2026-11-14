import SwiftUI
import YcodeAssistant

public struct AssistModernHeaderView: View {
    @State private var history = AssistConversationHistory.shared
    @State private var manager = AssistManager.shared
    @Binding public var showTodoList: Bool

    public var onOpenHistory: () -> Void
    public var onNewTask: () -> Void

    public init(
        showTodoList: Binding<Bool> = .constant(true),
        onOpenHistory: @escaping () -> Void = {},
        onNewTask: @escaping () -> Void = {}
    ) {
        self._showTodoList = showTodoList
        self.onOpenHistory = onOpenHistory
        self.onNewTask = onNewTask
    }

    private var currentTaskTitle: String {
        if let activeID = history.activeConversationID,
           let item = history.conversations.first(where: { $0.id == activeID }),
           !item.title.isEmpty {
            return item.title
        }
        if let firstMsg = manager.messages.first(where: { $0.role == .user }),
           !firstMsg.content.isEmpty {
            let truncated = firstMsg.content.components(separatedBy: .newlines).first ?? ""
            if !truncated.isEmpty {
                return String(truncated.prefix(32))
            }
        }
        return "New Assist Task"
    }

    public var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    onNewTask()
                } label: {
                    Label("New Task", systemImage: "square.and.pencil")
                }

                Divider()

                if !history.activeConversations.isEmpty {
                    Text("Recent Tasks").font(.caption).foregroundStyle(.secondary)
                    ForEach(history.activeConversations.prefix(8)) { conv in
                        Button {
                            history.activeConversationID = conv.id
                        } label: {
                            HStack {
                                Text(conv.title)
                                if conv.id == history.activeConversationID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                }

                Button {
                    onOpenHistory()
                } label: {
                    Label("Task History…", systemImage: "clock")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentTaskTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showTodoList.toggle()
                }
            } label: {
                Image(systemName: showTodoList ? "checklist.checked" : "checklist")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(showTodoList ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(showTodoList ? "Hide Todo List" : "Show Todo List")

            Button {
                onOpenHistory()
            } label: {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Task History")

            Button {
                onNewTask()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Assist Task")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
