import SwiftUI

struct PluginCodeCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = PluginManager.shared

    @State private var pluginName = ""
    @State private var pluginVersion = "1.0.0"
    @State private var pluginDescription = ""
    @State private var pluginAuthor = ""
    @State private var selectedCapabilities: Set<PluginManifest.Capability> = []
    @State private var mainCode = """
import Foundation
import SwiftUI

// Your Plugin Entry Point
struct MyPlugin {
    func run() {
        print("Hello from my plugin!")
    }
}
"""

    var body: some View {
        NavigationStack {
            Form {
                Section("Plugin Metadata") {
                    TextField("Plugin Name", text: $pluginName)
                    TextField("Version", text: $pluginVersion)
                    TextField("Author", text: $pluginAuthor)
                    TextField("Description", text: $pluginDescription, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Capabilities") {
                    ForEach(PluginManifest.Capability.allCases, id: \.self) { capability in
                        Toggle(capability.rawValue.capitalized, isOn: Binding(
                            get: { selectedCapabilities.contains(capability) },
                            set: { isSelected in
                                if isSelected {
                                    selectedCapabilities.insert(capability)
                                } else {
                                    selectedCapabilities.remove(capability)
                                }
                            }
                        ))
                    }
                }

                Section("Implementation (main.swift)") {
                    TextEditor(text: $mainCode)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.none)
                }
            }
            .navigationTitle("Create Plugin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        savePlugin()
                    }
                    .disabled(pluginName.isEmpty || pluginAuthor.isEmpty)
                }
            }
        }
    }

    private func savePlugin() {
        let pluginID = pluginName.lowercased().replacingOccurrences(of: " ", with: "")
        let manifest = PluginManifest(
            id: pluginID,
            name: pluginName,
            version: pluginVersion,
            description: pluginDescription,
            author: pluginAuthor,
            entryPoint: "main.swift",
            capabilities: Array(selectedCapabilities),
            isEnabled: true
        )

        do {
            try manager.createPlugin(manifest: manifest, mainCode: mainCode)
            dismiss()
        } catch {
            print("Error saving plugin: \(error)")
        }
    }
}
