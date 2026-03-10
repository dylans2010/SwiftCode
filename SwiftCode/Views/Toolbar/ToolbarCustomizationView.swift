import SwiftUI

struct ToolbarCustomizationView: View {
    @StateObject private var toolbarManager = ToolbarManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Enabled Tools") {
                    ForEach(toolbarManager.enabledTools) { tool in
                        toolRow(tool)
                    }
                    .onMove { from, to in
                        toolbarManager.moveTool(from: from, to: to)
                    }
                }

                Section("All Tools") {
                    ForEach(toolbarManager.tools) { tool in
                        HStack {
                            Image(systemName: tool.icon)
                                .foregroundStyle(tool.isEnabled ? .orange : .secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                Text(tool.category)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { tool.isEnabled },
                                set: { _ in toolbarManager.toggleTool(id: tool.id) }
                            ))
                            .labelsHidden()
                        }
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        toolbarManager.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("Customize Toolbar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toolRow(_ tool: ToolbarTool) -> some View {
        HStack {
            Image(systemName: tool.icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(tool.name)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
        }
    }
}
