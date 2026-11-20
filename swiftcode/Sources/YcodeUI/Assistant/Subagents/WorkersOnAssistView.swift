import SwiftUI
import YcodeAssistant

@MainActor
public struct WorkersOnAssistView: View {
    @Bindable var runtimeState: WorkerRuntimeState

    @State private var selectedWorkerForDetails: Worker? = nil
    @State private var isMainDashboardPresented: Bool = false

    public init(runtimeState: WorkerRuntimeState = .shared) {
        self.runtimeState = runtimeState
    }

    public var body: some View {
        let workers = runtimeState.allWorkers
        if workers.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Header Bar
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 18, height: 18)
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                    }

                    Text("Assist Workers")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)

                    let activeCount = runtimeState.activeWorkers.count
                    if activeCount > 0 {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            Text("\(activeCount) active")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.green.opacity(0.12), in: Capsule())
                    } else {
                        Text("\(workers.count) total")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.secondary.opacity(0.08), in: Capsule())
                    }

                    Spacer()

                    Button {
                        isMainDashboardPresented = true
                    } label: {
                        HStack(spacing: 3) {
                            Text("Dashboard")
                                .font(.system(size: 9, weight: .semibold))
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Open full Workers dashboard")
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

                // Compact Worker Rows
                let displayWorkers = Array(workers.prefix(4))
                ForEach(displayWorkers) { worker in
                    Button {
                        selectedWorkerForDetails = worker
                    } label: {
                        CompactWorkerRow(worker: worker)
                    }
                    .buttonStyle(.plain)
                }

                if workers.count > 4 {
                    Button {
                        isMainDashboardPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("+ \(workers.count - 4) more workers...")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                SpecularBorder(cornerRadius: 12, lineWidth: 1.0, intensity: 0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1.5)
            .sheet(item: $selectedWorkerForDetails) { worker in
                WorkersInfoView(workerID: worker.id, runtimeState: runtimeState)
            }
            .sheet(isPresented: $isMainDashboardPresented) {
                WorkersMainView(runtimeState: runtimeState)
            }
        }
    }
}

// MARK: - Compact Worker Row

@MainActor
private struct CompactWorkerRow: View {
    let worker: Worker
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            statusIcon(for: worker)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(worker.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(worker.role)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !worker.currentAction.isEmpty && worker.status == .working {
                    Text(worker.currentAction)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if worker.status == .working {
                Text("\(Int(worker.progressFraction * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)
            }

            Text(worker.status.rawValue)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor(for: worker.status))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(statusColor(for: worker.status).opacity(0.12), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(isHovered ? .primary : .tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.5)
        .contentShape(Rectangle())
        .background(
            isHovered ? Color.primary.opacity(0.06) : Color.secondary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 0.8)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for worker: Worker) -> some View {
        switch worker.status {
        case .working:
            ProgressView()
                .scaleEffect(0.55)
                .tint(.blue)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .failed, .blocked:
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
        case .standby:
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .cancelled:
            Image(systemName: "slash.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .reviewing:
            Image(systemName: "eye.fill")
                .font(.system(size: 11))
                .foregroundStyle(.purple)
        case .reassigning:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
                .foregroundStyle(.yellow)
        default:
            Image(systemName: "hourglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(for status: WorkerStatus) -> Color {
        switch status {
        case .created, .queued, .starting, .cancelled: return .secondary
        case .assigned, .working: return .blue
        case .reviewing: return .purple
        case .completed: return .green
        case .standby, .reassigning: return .orange
        case .blocked, .failed: return .red
        }
    }
}
