import SwiftUI

public struct VisualUIExportView: View {
    @Environment(\.dismiss) private var dismiss
    let document: VisualUIDocument

    @State private var activeTab: VisualUIFramework = .swiftUI
    @State private var generatedCode = ""
    @State private var showCopiedAlert = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Target Framework", selection: $activeTab) {
                    ForEach(VisualUIFramework.allCases) { framework in
                        Text(framework.rawValue).tag(framework)
                    }
                }
                .pickerStyle(.segmented)
                .padding(16)
                .onChange(of: activeTab) { _, newValue in
                    updateGeneratedCode(for: newValue)
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(generatedCode)
                            .font(.system(.body, design: .monospaced))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(style: .standard, cornerRadius: 12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    }
                    .padding(16)
                }

                Divider()

                HStack(spacing: 16) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        saveCodeFile()
                    } label: {
                        Label("Save .swift File…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button {
                        exportPreview(asFormat: "PNG")
                    } label: {
                        Label("Export PNG Preview…", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Spacer()
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .navigationTitle("Export Production-Ready Code")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateGeneratedCode(for: activeTab)
            }
            .alert("Success", isPresented: $showCopiedAlert) {
                Button("OK") {}
            } message: {
                Text("Content copied to clipboard successfully!")
            }
        }
        .frame(width: 700, height: 550)
    }

    private func updateGeneratedCode(for framework: VisualUIFramework) {
        generatedCode = VisualUICodeGenerator.generate(document: document, framework: framework)
    }

    private func saveCodeFile() {
        let panel = NSSavePanel()
        let artName = document.scene.artboards.first { $0.id == document.scene.activeArtboardID }?.name ?? "GeneratedView"
        panel.nameFieldStringValue = "\(VisualUICodeGenerator.sanitizedTypeName(artName))View.swift"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? generatedCode.write(to: url, atomically: true, encoding: .utf8)
        VisualUISettings.shared.addLog("Saved \(activeTab.rawValue) source to \(url.path).")
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(generatedCode, forType: .string)
        showCopiedAlert = true
        VisualUISettings.shared.addLog("Copied generated \(activeTab.rawValue) code to system clipboard.")
    }

    @MainActor
    private func exportPreview(asFormat format: String) {
        guard let artboard = document.scene.artboards.first(where: { $0.id == document.scene.activeArtboardID })
                ?? document.scene.artboards.first else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(VisualUICodeGenerator.sanitizedTypeName(artboard.name)).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let preview = VisualUIRenderer(rootNode: artboard.rootNode, document: document)
            .frame(width: 393, height: 760)
            .background(Color.white)
        let renderer = ImageRenderer(content: preview)
        renderer.scale = 2.0
        if let img = renderer.nsImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
        VisualUISettings.shared.addLog("Exported artboard preview as \(format) to \(url.lastPathComponent).")
    }
}
