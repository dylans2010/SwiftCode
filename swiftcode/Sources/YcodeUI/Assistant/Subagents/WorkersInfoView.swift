import Foundation
import SwiftUI
import YcodeAssistant

@MainActor
public struct WorkersInfoView: View {
    let workerID: UUID

    @Bindable var runtimeState: WorkerRuntimeState
    @Environment(\.dismiss) private var dismiss

    @State private var showingStopSheet = false

    public init(workerID: UUID, runtimeState: WorkerRuntimeState = .shared) {
        self.workerID = workerID
        self.runtimeState = runtimeState
    }

    public var body: some View {
        if let worker = runtimeState.getWorker(id: workerID) {
            VStack(spacing: 0) {
                headerView(for: worker)

                Divider()
                    .opacity(0.5)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        statusSection(worker)
                        activitySection(worker)
                        scopeSection(worker)
                        filesSection(worker)
                        testsSection(worker)
                        verificationSection(worker)
                        if worker.errorState != nil {
                            errorSection(worker)
                        }
                        if worker.handoffState != nil || worker.cancellationReason != nil {
                            handoffSection(worker)
                        }
                        if !worker.dependencies.isEmpty {
                            dependenciesSection(worker)
                        }
                        if !worker.recap.isEmpty {
                            recapSection(worker)
                        }
                        timestampsSection(worker)
                    }
                    .padding(20)
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
            }
            .frame(minWidth: 580, idealWidth: 660, maxWidth: 740, minHeight: 520, idealHeight: 640)
            .sheet(isPresented: $showingStopSheet) {
                WorkerStopConfirmationSheet(worker: worker) {
                    showingStopSheet = false
                }
            }
        } else {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("Worker Not Found")
                        .font(.headline)
                    Text("This worker was completed and removed or does not exist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(32)
            .frame(width: 420, height: 260)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(SpecularBorder(cornerRadius: 14, lineWidth: 1.0, intensity: 0.7))
        }
    }

    @ViewBuilder
    private func headerView(for worker: Worker) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(statusColor(for: worker.status).opacity(0.15))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(statusColor(for: worker.status).opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: worker.status.sfSymbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(statusColor(for: worker.status))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(worker.name)
                        .font(.system(.title3, weight: .bold))

                    Text(worker.status.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(statusColor(for: worker.status))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(statusColor(for: worker.status).opacity(0.12), in: Capsule())
                }

                Text(worker.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if worker.status.isActive || worker.status == .standby {
                Button(role: .destructive) {
                    showingStopSheet = true
                } label: {
                    Label("Stop / Reassign", systemImage: "stop.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help("Halt this worker and either preserve work or reassign remaining scope")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func statusSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "info.circle.fill",
            iconColor: .blue,
            title: "Status & Runtime",
            badge: worker.status.rawValue,
            badgeColor: statusColor(for: worker.status),
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Status", value: worker.status.rawValue, valueColor: statusColor(for: worker.status), isMonospaced: true)
                infoRow(label: "Phase", value: worker.currentPhase.rawValue, isMonospaced: true)
                infoRow(label: "Review State", value: worker.reviewState.rawValue, valueColor: reviewColor(for: worker.reviewState), isMonospaced: true)

                if !worker.modelUsed.isEmpty {
                    infoRow(label: "Model", value: worker.modelUsed, isMonospaced: true)
                }

                if !worker.skillsUsed.isEmpty {
                    HStack(alignment: .center) {
                        Text("Skills")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(worker.skillsUsed, id: \.self) { skill in
                                    Text(skill)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                        }
                    }
                }

                infoRow(label: "Worker ID", value: worker.id.uuidString.prefix(12) + "...", isMonospaced: true)
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "bolt.fill",
            iconColor: .cyan,
            title: "Current Activity",
            badge: "\(Int(worker.progressFraction * 100))%",
            badgeColor: worker.status == .failed ? .red : .blue,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Action")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text(worker.currentAction.isEmpty ? "Idle / Waiting" : worker.currentAction)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Execution Progress")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(worker.progressFraction * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(worker.status == .failed ? .red : .blue)
                    }

                    ProgressView(value: worker.progressFraction)
                        .tint(worker.status == .failed ? .red : (worker.status == .completed ? .green : .blue))
                }

                if let lastCompleted = worker.progress.lastCompleted, !lastCompleted.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Last Completed")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(lastCompleted)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let nextPlan = worker.progress.nextPlan, !nextPlan.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Next Step")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(nextPlan)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func scopeSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "scope",
            iconColor: .indigo,
            title: "Assignment & Scope",
            badge: worker.role,
            badgeColor: .indigo,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task Objective")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(worker.task)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Scope & Constraints")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(worker.scope)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func filesSection(_ worker: Worker) -> some View {
        let count = worker.fileChanges.count
        WorkerSectionCard(
            icon: "doc.badge.gearshape.fill",
            iconColor: .teal,
            title: "Files (\(count))",
            badge: count > 0 ? "+\(worker.totalLinesAdded) / -\(worker.totalLinesRemoved)" : "0 files",
            badgeColor: count > 0 ? .teal : .secondary,
            initiallyExpanded: count > 0
        ) {
            VStack(alignment: .leading, spacing: 6) {
                if worker.fileChanges.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("No files modified yet by this worker.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(worker.fileChanges) { change in
                        HStack(spacing: 8) {
                            Image(systemName: change.changeType.sfSymbolName)
                                .font(.caption)
                                .foregroundStyle(fileColor(for: change.changeType))
                                .frame(width: 16)

                            Text(change.path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            HStack(spacing: 3) {
                                Text("+\(change.linesAdded)")
                                    .foregroundStyle(.green)
                                Text("/")
                                    .foregroundStyle(.secondary)
                                Text("-\(change.linesRemoved)")
                                    .foregroundStyle(.red)
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func testsSection(_ worker: Worker) -> some View {
        let total = worker.testsRun.count
        let passed = worker.testsRun.filter(\.passed).count
        let allPassed = total > 0 && passed == total
        WorkerSectionCard(
            icon: "checkmark.seal.fill",
            iconColor: .green,
            title: "Tests (\(total))",
            badge: total > 0 ? "\(passed)/\(total) passed" : "None",
            badgeColor: total > 0 ? (allPassed ? .green : .red) : .secondary,
            initiallyExpanded: total > 0
        ) {
            VStack(alignment: .leading, spacing: 6) {
                if worker.testsRun.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(.secondary)
                        Text("No tests executed yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(worker.testsRun) { test in
                        HStack(spacing: 8) {
                            Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(test.passed ? .green : .red)
                                .frame(width: 16)

                            Text(test.testName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            Text(String(format: "%.2fs", test.duration))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (test.passed ? Color.green : Color.red).opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func verificationSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "checkmark.shield.fill",
            iconColor: .purple,
            title: "Verification & Results",
            badge: worker.verificationState,
            badgeColor: .purple,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Verification State", value: worker.verificationState, isMonospaced: true)

                if let result = worker.result {
                    Divider().opacity(0.4)

                    infoRow(label: "Build Result", value: result.buildResult, valueColor: result.buildResult.lowercased().contains("succeed") ? .green : .orange, isMonospaced: true)
                    infoRow(label: "Verification Result", value: result.verificationResult, valueColor: result.verificationResult.lowercased().contains("pass") || result.verificationResult.lowercased().contains("succeed") ? .green : .orange, isMonospaced: true)
                    infoRow(label: "Execution Duration", value: "\(Int(result.executionDuration)) seconds", isMonospaced: true)

                    if !result.knownIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("Known Issues (\(result.knownIssues.count))")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                            ForEach(result.knownIssues, id: \.self) { issue in
                                Text("• \(issue)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func errorSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "exclamationmark.triangle.fill",
            iconColor: .red,
            title: "Error Diagnostics",
            badge: worker.errorState?.recoverable == true ? "Recoverable" : "Fatal Error",
            badgeColor: .red,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if let error = worker.errorState {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.title3)
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(error.message)
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                .foregroundStyle(.red)

                            if let details = error.details, !details.isEmpty {
                                Text(details)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 6) {
                                Text(error.recoverable ? "Recoverable Failure" : "Unrecoverable Fatal Error")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(error.recoverable ? .orange : .red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((error.recoverable ? Color.orange : Color.red).opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func handoffSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "arrow.triangle.branch",
            iconColor: .orange,
            title: "Handoff & Reassignment",
            badge: worker.handoffState?.mode.rawValue ?? (worker.cancellationReason != nil ? "Cancelled" : "Pending"),
            badgeColor: .orange,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 6) {
                if let handoff = worker.handoffState {
                    infoRow(label: "Handoff Reason", value: handoff.reason)
                    infoRow(label: "Mode", value: handoff.mode.rawValue, isMonospaced: true)
                    if !handoff.completedWork.isEmpty {
                        infoRow(label: "Completed Scope", value: "\(handoff.completedWork.count) items", isMonospaced: true)
                    }
                    if let replacementID = handoff.replacementWorkerID {
                        infoRow(label: "Replacement Worker", value: String(replacementID.uuidString.prefix(8)), valueColor: .blue, isMonospaced: true)
                    }
                } else if let cancellation = worker.cancellationReason {
                    HStack(spacing: 8) {
                        Image(systemName: "slash.circle.fill")
                            .foregroundStyle(.red)
                        Text("Cancelled: \(cancellation)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func dependenciesSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "point.3.connected.trianglepath.dotted",
            iconColor: .mint,
            title: "Dependencies (\(worker.dependencies.count))",
            badge: "\(worker.dependencies.count)",
            badgeColor: .mint,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(worker.dependencies, id: \.self) { depID in
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.mint)

                        if let depWorker = runtimeState.getWorker(id: depID) {
                            Text(depWorker.name)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)

                            Text(depWorker.role)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(depWorker.status.rawValue)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(statusColor(for: depWorker.status))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(for: depWorker.status).opacity(0.12), in: Capsule())
                        } else {
                            Text(depID.uuidString.prefix(8))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("External")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func recapSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "sparkles",
            iconColor: .yellow,
            title: "Recap & Highlights",
            badge: "\(worker.recap.count) items",
            badgeColor: .yellow,
            initiallyExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(worker.recap, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .padding(.top, 2)
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func timestampsSection(_ worker: Worker) -> some View {
        WorkerSectionCard(
            icon: "clock.fill",
            iconColor: .secondary,
            title: "Timeline & Activity",
            badge: nil,
            initiallyExpanded: false
        ) {
            VStack(alignment: .leading, spacing: 6) {
                timestampRow("Created", worker.createdAt, icon: "plus.circle")
                if let started = worker.startedAt {
                    timestampRow("Started", started, icon: "play.circle")
                }
                if let completed = worker.completedAt {
                    timestampRow("Completed", completed, icon: "checkmark.circle")
                }
                timestampRow("Last Updated", worker.updatedAt, icon: "arrow.clockwise.circle")
            }
        }
    }

    private func timestampRow(_ label: String, _ date: Date, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Spacer()

            Text(date, style: .time)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)

            Text(date, style: .date)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(label: String, value: String, valueColor: Color = .primary, isMonospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(.caption, design: .monospaced) : .caption)
                .foregroundStyle(valueColor)
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

    private func fileColor(for type: FileChangeType) -> Color {
        switch type {
        case .created: return .green
        case .modified: return .blue
        case .deleted: return .red
        case .renamed: return .orange
        }
    }
}

// MARK: - Reusable Liquid Glass Section Card

@MainActor
private struct WorkerSectionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var badge: String? = nil
    var badgeColor: Color = .secondary
    var initiallyExpanded: Bool = true
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool

    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        badge: String? = nil,
        badgeColor: Color = .secondary,
        initiallyExpanded: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.badge = badge
        self.badgeColor = badgeColor
        self.initiallyExpanded = initiallyExpanded
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.content = content
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .opacity(0.35)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                content()
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 24, height: 24)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(badgeColor.opacity(0.12), in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            SpecularBorder(cornerRadius: 12, lineWidth: 1.0, intensity: 0.65)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1.5)
    }
}
