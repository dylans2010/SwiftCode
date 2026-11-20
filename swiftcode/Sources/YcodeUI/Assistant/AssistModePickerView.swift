import SwiftUI
import YcodeAssistant

public struct AssistModePicker: View {
    public let selection: AssistMode
    public let isEnabled: Bool
    public let onSelect: (AssistMode) -> Void

    public init(selection: AssistMode, isEnabled: Bool, onSelect: @escaping (AssistMode) -> Void) {
        self.selection = selection
        self.isEnabled = isEnabled
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(AssistMode.allCases, id: \.self) { mode in
                let selected = mode == selection
                Button {
                    onSelect(mode)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 9, weight: .semibold))
                        Text(mode.displayName)
                            .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                    }
                    .foregroundStyle(selected ? Color.white : Color.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: Color.accentColor.opacity(0.22), radius: 5, y: 2)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .help("\(mode.displayName) mode — \(mode.shortDescription)")
                .accessibilityLabel("\(mode.displayName) mode")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.055), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.52)
        .fixedSize()
        .animation(.spring(duration: 0.18), value: selection)
    }
}
