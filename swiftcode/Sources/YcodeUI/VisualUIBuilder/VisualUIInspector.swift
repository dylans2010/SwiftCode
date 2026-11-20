import SwiftUI

public struct VisualUIInspector: View {
    @Bindable var document: VisualUIDocument

    public var body: some View {
        VStack(spacing: 0) {
            Text("PROPERTIES INSPECTOR")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)

            Divider()

            if let selectedID = document.scene.selectedNodeIDs.first,
               let node = document.scene.findNode(byID: selectedID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GroupBox("Identity") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Name:")
                                        .frame(width: 80, alignment: .leading)
                                    TextField("Name", text: Binding(
                                            get: { node.name },
                                            set: { node.name = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack {
                                    Text("Type:")
                                        .frame(width: 80, alignment: .leading)
                                    Text(node.type.rawValue)
                                        .bold()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(.liquidGlass)

                        GroupBox("Content") {
                            VStack(alignment: .leading, spacing: 8) {
                                if node.type == .text || node.type == .button || node.type == .label || node.type == .textField || node.type == .secureField {
                                    HStack {
                                        Text("Text:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("Content text", text: Binding(
                                            get: { node.properties["textValue"] ?? "" },
                                            set: { node.properties["textValue"] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }

                                if node.type == .sfSymbol || node.type == .label {
                                    HStack {
                                        Text("Symbol:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("SF Symbol Name", text: Binding(
                                            get: { node.properties["sfSymbolName"] ?? "sparkles" },
                                            set: { node.properties["sfSymbolName"] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }

                                if node.type == .webView || node.type == .asyncImage {
                                    HStack {
                                        Text("URL:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("https://...", text: Binding(
                                            get: { node.properties["url"] ?? "" },
                                            set: { node.properties["url"] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(.liquidGlass)

                        GroupBox("Styling") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Padding:")
                                    Spacer()
                                    TextField("0", text: Binding(
                                        get: { node.properties["padding"] ?? "8" },
                                        set: { node.properties["padding"] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                }

                                HStack {
                                    Text("Corner Radius:")
                                    Spacer()
                                    TextField("0", text: Binding(
                                        get: { node.properties["cornerRadius"] ?? "0" },
                                        set: { node.properties["cornerRadius"] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                }

                                HStack {
                                    Text("Foreground:")
                                    Spacer()
                                    TextField("Hex Code", text: Binding(
                                        get: { node.properties["foregroundColor"] ?? "#007AFF" },
                                        set: { node.properties["foregroundColor"] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 90)
                                }

                                HStack {
                                    Text("Background:")
                                    Spacer()
                                    TextField("Hex Code", text: Binding(
                                        get: { node.properties["backgroundColor"] ?? "#FFFFFF" },
                                        set: { node.properties["backgroundColor"] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 90)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(.liquidGlass)

                        GroupBox("Layout Constraints") {
                            VStack(alignment: .leading, spacing: 8) {
                                if [.vStack, .hStack, .grid, .lazyVGrid, .lazyHGrid].contains(node.type) {
                                    HStack {
                                        Text("Spacing:")
                                        Spacer()
                                        TextField("8", text: Binding(
                                            get: { node.properties["spacing"] ?? "8" },
                                            set: { node.properties["spacing"] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    }
                                    Picker("Align:", selection: Binding(
                                        get: { node.properties["alignment"] ?? "Center" },
                                        set: { node.properties["alignment"] = $0 }
                                    )) {
                                        Text("Leading").tag("Leading")
                                        Text("Center").tag("Center")
                                        Text("Trailing").tag("Trailing")
                                    }
                                    .pickerStyle(.segmented)
                                }

                                HStack {
                                    Text("Width:")
                                    Spacer()
                                    TextField("Auto", text: Binding(
                                        get: { node.properties["width"] ?? "" },
                                        set: { node.properties["width"] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                }

                                HStack {
                                    Text("Height:")
                                    Spacer()
                                    TextField("Auto", text: Binding(
                                        get: { node.properties["height"] ?? "" },
                                        set: { node.properties["height"] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(.liquidGlass)

                        GroupBox("Typography & Transform") {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Font:", selection: Binding(
                                    get: { node.properties["fontPreset"] ?? "Body" },
                                    set: { node.properties["fontPreset"] = $0 }
                                )) {
                                    ForEach(["Large Title", "Title 1", "Headline", "Body", "Subhead", "Footnote"], id: \.self) { f in
                                        Text(f).tag(f)
                                    }
                                }

                                HStack {
                                    Text("Opacity")
                                    Slider(value: Binding(
                                        get: { Double(node.properties["opacity"] ?? "1.0") ?? 1.0 },
                                        set: { node.properties["opacity"] = String(format: "%.2f", $0) }
                                    ), in: 0.05...1.0)
                                }

                                HStack {
                                    Text("Rotate")
                                    Slider(value: Binding(
                                        get: { Double(node.properties["rotation"] ?? "0") ?? 0 },
                                        set: { node.properties["rotation"] = "\(Int($0))" }
                                    ), in: -180...180)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(.liquidGlass)

                        GroupBox("Accessibility") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("VoiceOver Label", text: Binding(
                                    get: { node.properties["accessibilityLabel"] ?? "" },
                                    set: { node.properties["accessibilityLabel"] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)

                                TextField("VoiceOver Hint", text: Binding(
                                    get: { node.properties["accessibilityHint"] ?? "" },
                                    set: { node.properties["accessibilityHint"] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                            .padding(.vertical, 4)
                        }
                        .groupBoxStyle(.liquidGlass)

                    }
                    .padding(8)
                }
            } else {
                ContentUnavailableView {
                    Label("No Selection", systemImage: "hand.point.up.left")
                } description: {
                    Text("Select an element in the canvas or scene tree to inspect properties.")
                }
            }
        }
    }

}
