import SwiftUI

struct FolderCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var folderManager: FolderManager

    @State private var folderName = ""
    @State private var selectedSymbol = "folder.fill"
    @State private var selectedColor = Color.blue
    @State private var symbolSearch = ""

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
                                                .fill(selectedSymbol == symbol ? selectedColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Icon Color") {
                    ColorPicker("Folder Color", selection: $selectedColor, supportsOpacity: false)
                }

                Section("Preview") {
                    HStack(spacing: 12) {
                        Image(systemName: selectedSymbol)
                            .font(.title2)
                            .foregroundStyle(selectedColor)
                            .frame(width: 44, height: 44)
                            .background(selectedColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
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
            .navigationTitle("Create Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        folderManager.createFolder(
                            name: folderName,
                            symbol: selectedSymbol,
                            colorHex: selectedColor.toHex
                        )
                        dismiss()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
