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
                    HStack(spacing: 5) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.displayName)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    }
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        if selected {
                            Capsule().fill(Color.accentColor.opacity(0.22))
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
        .background(.quaternary.opacity(0.6), in: Capsule())
        .opacity(isEnabled ? 1 : 0.55)
        .fixedSize()
    }
}
