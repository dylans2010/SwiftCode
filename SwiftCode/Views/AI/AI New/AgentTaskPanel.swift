import SwiftUI

struct AgentTaskPanel: View {
    @ObservedObject var state: AgentExecutionState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Task")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            Text(state.taskDescription)
                .font(.body)
                .foregroundColor(.primary)

            if let error = state.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(statusColor.opacity(0.3), lineWidth: 1))
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            if state.status == .running {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Text(state.status.rawValue.capitalized)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2), in: Capsule())
        .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch state.status {
        case .pending: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}
