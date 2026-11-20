import SwiftUI
import YcodeAssistant

@MainActor
public struct WorkersHeaderButton: View {
    @Bindable var runtimeState: WorkerRuntimeState
    @State private var showingDashboard = false
    @State private var isHovered = false

    public init(runtimeState: WorkerRuntimeState = .shared) {
        self.runtimeState = runtimeState
    }

    @ViewBuilder
    public var body: some View {
        if !runtimeState.allWorkers.isEmpty {
            Button {
                showingDashboard = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(runtimeState.activeWorkers.isEmpty ? Color.secondary : Color.blue)

                    Text(buttonTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(runtimeState.activeWorkers.isEmpty ? Color.secondary : Color.primary)

                    if !runtimeState.activeWorkers.isEmpty {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    isHovered ? Color.primary.opacity(0.08) : Color.secondary.opacity(0.08),
                    in: Capsule()
                )
                .overlay(
                    SpecularBorder(cornerRadius: 14, lineWidth: 1.0, intensity: isHovered ? 0.9 : 0.5)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isHovered ? (!runtimeState.activeWorkers.isEmpty ? Color.blue.opacity(0.35) : Color.primary.opacity(0.12)) : Color.primary.opacity(0.06),
                            lineWidth: 1.0
                        )
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .help("Inspect Active Assist Workers")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .sheet(isPresented: $showingDashboard) {
                WorkersMainView(runtimeState: runtimeState)
            }
        } else {
            Button {
                showingDashboard = true
            } label: {
                ZStack {
                    Circle()
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                        .frame(width: 24, height: 24)
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Workers Dashboard (No Active Workers)")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .sheet(isPresented: $showingDashboard) {
                WorkersMainView(runtimeState: runtimeState)
            }
        }
    }

    private var buttonTitle: String {
        let activeCount = runtimeState.activeWorkers.count
        if activeCount > 0 {
            return "Workers · \(activeCount)"
        } else if !runtimeState.allWorkers.isEmpty {
            return "Workers · \(runtimeState.allWorkers.count)"
        } else {
            return "Workers"
        }
    }
}
