import SwiftUI
import YcodeAssistant

@MainActor
public struct WorkersMainView: View {
    @Bindable var runtimeState: WorkerRuntimeState
    @Environment(\.dismiss) private var dismiss

    private let closeAction: (() -> Void)?

    @State private var filterMode: FilterMode = .all
    @State private var selectedWorkerForDetails: Worker? = nil
    @State private var workerToStop: Worker? = nil

    public enum FilterMode: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case attention = "Needs Attention"

        public var id: String { rawValue }
    }

    public init(runtimeState: WorkerRuntimeState = .shared, onClose: (() -> Void)? = nil) {
        self.runtimeState = runtimeState
        self.closeAction = onClose
    }

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            metricsBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            filterBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.4)

            ScrollView {
                if filteredWorkers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredWorkers) { worker in
                            WorkerCardView(
                                worker: worker,
                                onSelectDetails: {
                                    selectedWorkerForDetails = worker
                                },
                                onStop: {
                                    workerToStop = worker
                                }
                            )
                        }
                    }
                    .padding(14)
                }
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        }
        .frame(minWidth: 540, idealWidth: 620, maxWidth: 720, minHeight: 460, idealHeight: 540, maxHeight: 680)
        .sheet(item: $selectedWorkerForDetails) { worker in
            WorkersInfoView(workerID: worker.id, runtimeState: runtimeState)
        }
        .sheet(item: $workerToStop) { worker in
            WorkerStopConfirmationSheet(worker: worker) {
                workerToStop = nil
            }
        }
        .onExitCommand { close() }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.blue.opacity(0.2), .indigo.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                    )
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Assist Workers")
                        .font(.system(.title3, weight: .bold))

                    if !runtimeState.activeWorkers.isEmpty {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("\(runtimeState.activeWorkers.count) Running")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }

                Text("\(runtimeState.allWorkers.count) total registered · Parallel subagent execution system")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                close()
            } label: {
                Text("Done")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close the Workers dashboard (Esc)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    private var metricsBar: some View {
        HStack(spacing: 10) {
            metricTile(label: "Active", count: runtimeState.activeWorkers.count, color: .blue, icon: "bolt.fill")
            metricTile(label: "Completed", count: runtimeState.completedWorkers.count, color: .green, icon: "checkmark.circle.fill")
            metricTile(label: "Attention", count: attentionCount, color: .red, icon: "exclamationmark.triangle.fill")
            metricTile(label: "Standby", count: runtimeState.standbyWorkers.count, color: .orange, icon: "pause.circle.fill")
        }
    }

    private func metricTile(label: String, count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            SpecularBorder(cornerRadius: 10, lineWidth: 1.0, intensity: 0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    private var filterBar: some View {
        HStack {
            Picker("Filter Mode", selection: $filterMode) {
                ForEach(FilterMode.allCases) { mode in
                    Text(filterTitle(for: mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 420)

            Spacer()
        }
    }

    private func filterTitle(for mode: FilterMode) -> String {
        switch mode {
        case .all:
            return "All (\(runtimeState.allWorkers.count))"
        case .active:
            return "Active (\(runtimeState.activeWorkers.count))"
        case .completed:
            return "Done (\(runtimeState.completedWorkers.count))"
        case .attention:
            return "Attention (\(attentionCount))"
        }
    }

    private var attentionCount: Int {
        runtimeState.allWorkers.filter {
            $0.status == .failed || $0.status == .blocked || $0.status == .reassigning || $0.reviewState == .rejected || $0.reviewState == .repairRequired
        }.count
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: runtimeState.allWorkers.isEmpty ? "person.3.sequence" : "tray")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 4) {
                Text(runtimeState.allWorkers.isEmpty ? "No Workers Active" : "No Matching Workers")
                    .font(.headline)

                Text(runtimeState.allWorkers.isEmpty ? "Assist automatically launches parallel subagents to complete tasks, run tests, and verify code." : "No workers match the \"\(filterMode.rawValue)\" filter criteria.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(SpecularBorder(cornerRadius: 14, lineWidth: 1.0, intensity: 0.6))
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private var filteredWorkers: [Worker] {
        switch filterMode {
        case .all:
            return runtimeState.allWorkers
        case .active:
            return runtimeState.activeWorkers
        case .completed:
            return runtimeState.completedWorkers
        case .attention:
            return runtimeState.allWorkers.filter {
                $0.status == .failed || $0.status == .blocked || $0.status == .reassigning || $0.reviewState == .rejected || $0.reviewState == .repairRequired
            }
        }
    }
}

// MARK: - Worker Card Row View

@MainActor
private struct WorkerCardView: View {
    let worker: Worker
    let onSelectDetails: () -> Void
    let onStop: () -> Void

    @State private var isHovered: Bool = false
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main clickable row header
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)

                        ZStack {
                            Circle()
                                .fill(statusColor(for: worker.status).opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: worker.status.sfSymbolName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(statusColor(for: worker.status))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(worker.name)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(.primary)

                                Text(worker.role)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }

                            Text(worker.task)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(Int(worker.progressFraction * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(worker.status == .failed ? .red : .blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(worker.status.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor(for: worker.status))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(statusColor(for: worker.status).opacity(0.12), in: Capsule())
                    }
                }
                .buttonStyle(.plain)

                if worker.status.isActive || worker.status == .standby {
                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help("Stop or reassign worker")
                }

                Button {
                    onSelectDetails()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open detailed inspector")
            }
            .padding(12)

            // Expanded details
            if isExpanded {
                Divider()
                    .opacity(0.35)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 10) {
                    if !worker.currentAction.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(worker.currentAction)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    ProgressView(value: worker.progressFraction)
                        .tint(worker.status == .failed ? .red : (worker.status == .completed ? .green : .blue))

                    HStack(spacing: 8) {
                        Label("\(worker.fileChanges.count) files", systemImage: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if worker.totalLinesAdded > 0 || worker.totalLinesRemoved > 0 {
                            Text("+\(worker.totalLinesAdded) / -\(worker.totalLinesRemoved)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }

                        Label("\(worker.testsRun.count) tests", systemImage: "checkmark.seal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(worker.reviewState.rawValue)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(reviewColor(for: worker.reviewState))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(reviewColor(for: worker.reviewState).opacity(0.1), in: Capsule())
                    }

                    if let error = worker.errorState {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text(error.message)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    if let result = worker.result {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Build: \(result.buildResult) · Verify: \(result.verificationResult)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            onSelectDetails()
                        } label: {
                            Label("Full Inspector", systemImage: "arrow.up.right.and.arrow.down.left.rectangle")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if worker.status.isActive || worker.status == .standby {
                            Button(role: .destructive) {
                                onStop()
                            } label: {
                                Label("Stop / Reassign", systemImage: "stop.circle")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }

                        Spacer()

                        if !worker.scope.isEmpty {
                            Text("Scope: \(worker.scope)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            SpecularBorder(cornerRadius: 12, lineWidth: 1.0, intensity: isHovered ? 0.9 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 5 : 2, x: 0, y: isHovered ? 2 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
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

    private func reviewColor(for review: WorkerReviewState) -> Color {
        switch review {
        case .notReviewed: return .secondary
        case .reviewing: return .purple
        case .accepted: return .green
        case .rejected: return .red
        case .repairRequired: return .orange
        }
    }
}
