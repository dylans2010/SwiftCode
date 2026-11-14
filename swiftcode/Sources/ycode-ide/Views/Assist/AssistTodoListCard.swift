import SwiftUI
import YcodeAssistant

public struct AssistTodoItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var status: TodoStatus
    public var detail: String?

    public enum TodoStatus: String, Sendable, CaseIterable {
        case completed
        case inProgress
        case pending

        public var iconName: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .inProgress: return "arrow.right.circle.fill"
            case .pending: return "circle"
            }
        }

        public var iconColor: Color {
            switch self {
            case .completed: return .green
            case .inProgress: return .blue
            case .pending: return .secondary
            }
        }
    }

    public init(id: UUID = UUID(), title: String, status: TodoStatus = .pending, detail: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
    }
}

public struct AssistTodoListCard: View {
    @State private var planner = TasksAIPlanner.shared
    @Binding public var isPresented: Bool
    @State private var isCollapsed: Bool = false
    @State private var customItems: [AssistTodoItem] = []

    public init(isPresented: Binding<Bool> = .constant(true), customItems: [AssistTodoItem] = []) {
        self._isPresented = isPresented
        self._customItems = State(initialValue: customItems)
    }

    private var activeItems: [AssistTodoItem] {
        if let plan = planner.currentPlan, !plan.steps.isEmpty {
            return plan.steps.map { step in
                let status: AssistTodoItem.TodoStatus
                switch step.status {
                case .completed:
                    status = .completed
                case .running:
                    status = .inProgress
                default:
                    status = .pending
                }
                return AssistTodoItem(
                    id: step.id,
                    title: step.description,
                    status: status,
                    detail: step.toolId
                )
            }
        }
        if !customItems.isEmpty {
            return customItems
        }
        return [
            AssistTodoItem(title: "Analyze workspace structure and dependencies", status: .completed),
            AssistTodoItem(title: "Identify component requirements and contracts", status: .completed),
            AssistTodoItem(title: "Implement feature components and update references", status: .inProgress),
            AssistTodoItem(title: "Run static analysis and test validation", status: .pending)
        ]
    }

    private var completedCount: Int {
        activeItems.filter { $0.status == .completed }.count
    }

    public var body: some View {
        if isPresented {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                if !isCollapsed {
                    Divider().opacity(0.4)
                    listView
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Todo List")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            Text("\(completedCount)/\(activeItems.count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.accentColor)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand Todo List" : "Collapse Todo List")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss Todo Card")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(activeItems) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: item.status.iconName)
                        .font(.system(size: 13, weight: item.status == .inProgress ? .bold : .medium))
                        .foregroundStyle(item.status.iconColor)
                        .frame(width: 16, height: 16)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 12, weight: item.status == .inProgress ? .semibold : .regular))
                            .foregroundStyle(item.status == .completed ? .secondary : .primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let detail = item.detail, !detail.isEmpty, item.status == .inProgress {
                            Text(detail)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 4)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}
