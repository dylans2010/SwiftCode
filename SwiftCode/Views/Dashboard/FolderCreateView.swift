import SwiftUI

struct FolderCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var folderManager: FolderManager

    @State private var folderName = ""
    @State private var selectedSymbol = "folder.fill"
    @State private var selectedColor = Color.blue
    @State private var symbolSearch = ""

    // Gradient Support
    @State private var useGradient = false
    @State private var gradientColor1 = Color.blue
    @State private var gradientColor2 = Color.purple

    private let symbols: [String] = {
        guard let url = Bundle.main.url(forResource: "sf_symbols_full", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return ["folder.fill", "folder", "shippingbox.fill", "tray.full.fill"] }
        return decoded
    }()

    private var filteredSymbols: [String] {
        if symbolSearch.isEmpty { return Array(symbols.prefix(120)) }
        return symbols.filter { $0.localizedCaseInsensitiveContains(symbolSearch) }.prefix(80).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useGradient {
                    LinearGradient(colors: [gradientColor1.opacity(0.15), gradientColor2.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()
                } else {
                    selectedColor.opacity(0.05).ignoresSafeArea()
                }

                Form {
                    Section("Folder Name") {
                        TextField("iOS Apps", text: $folderName)
                    }

                    Section("SF Symbol") {
                        TextField("Search symbols", text: $symbolSearch)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filteredSymbols, id: \.self) { symbol in
                                    Button {
                                        selectedSymbol = symbol
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.title3)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedSymbol == symbol ? (useGradient ? gradientColor1.opacity(0.2) : selectedColor.opacity(0.2)) : Color.secondary.opacity(0.12))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Style") {
                        Toggle("Use Gradient Background", isOn: $useGradient)

                        if useGradient {
                            ColorPicker("Gradient Start", selection: $gradientColor1, supportsOpacity: false)
                            ColorPicker("Gradient End", selection: $gradientColor2, supportsOpacity: false)
                        } else {
                            ColorPicker("Icon Color", selection: $selectedColor, supportsOpacity: false)
                        }
                    }

                    Section("Preview") {
                        HStack(spacing: 12) {
                            Image(systemName: selectedSymbol)
                                .font(.title2)
                                .foregroundStyle(useGradient ? LinearGradient(colors: [gradientColor1, gradientColor2], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [selectedColor], startPoint: .top, endPoint: .bottom))
                                .frame(width: 44, height: 44)
                                .background(
                                    useGradient ?
                                    AnyShapeStyle(LinearGradient(colors: [gradientColor1.opacity(0.2), gradientColor2.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                    AnyShapeStyle(selectedColor.opacity(0.15)),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )

                            VStack(alignment: .leading) {
                                Text(folderName.isEmpty ? "Untitled Folder" : folderName)
                                    .font(.headline)
                                Text("Ready to create")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Create Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let gColors = useGradient ? [gradientColor1.toHex, gradientColor2.toHex] : nil
                        folderManager.createFolder(
                            name: folderName,
                            symbol: selectedSymbol,
                            colorHex: selectedColor.toHex,
                            gradientColors: gColors
                        )
                        dismiss()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
