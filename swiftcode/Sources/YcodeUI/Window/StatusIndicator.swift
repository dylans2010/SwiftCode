import YcodeIDECore
import SwiftUI

struct StatusIndicator: View {
    let state: LocalProcessDebugSession.State

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var color: Color {
        switch state {
        case .running:
            return .green
        case .terminated(let code):
            return code == 0 ? .gray : .red
        }
    }

    private var label: String {
        switch state {
        case .running:
            return "Running"
        case .terminated(let code):
            return code == 0 ? "Exited" : "Exited (\(code))"
        }
    }
}
