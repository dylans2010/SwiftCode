import SwiftUI

struct AgentPlanView: View {
    let plan: [AgentPlanStep]
    let currentIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution Plan")
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plan.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            stepIcon(for: step.status, index: index)
                            if index < plan.count - 1 {
                                Rectangle()
                                    .fill(index < currentIndex ? Color.green : Color.secondary.opacity(0.3))
                                    .frame(width: 2, height: 20)
                            }
                        }

                        Text(step.description)
                            .font(.subheadline)
                            .foregroundColor(index == currentIndex ? .primary : .secondary)
                            .padding(.top, 2)

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func stepIcon(for status: AgentStepStatus, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(statusColor(status))
                .frame(width: 24, height: 24)

            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            } else if status == .running {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private func statusColor(_ status: AgentStepStatus) -> Color {
        switch status {
        case .pending: return .secondary.opacity(0.5)
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
