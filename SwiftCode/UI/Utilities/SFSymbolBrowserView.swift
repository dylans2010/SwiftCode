import SwiftUI

// MARK: - SF Symbol Model

struct SFSymbolItem: Identifiable, Hashable {
    let id: String // the symbol name itself
    var name: String { id }
}

// MARK: - Symbol Loader

@MainActor
final class SFSymbolStore: ObservableObject {
    static let shared = SFSymbolStore()
    @Published var allSymbols: [SFSymbolItem] = []

    private init() {
        loadSymbols()
    }

    private func loadSymbols() {
        // Load from bundled JSON file
        guard let url = Bundle.main.url(forResource: "sf_symbols_full", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            // Fallback: a small built-in set if file is missing
            allSymbols = fallbackSymbols.map { SFSymbolItem(id: $0) }
            return
        }
        allSymbols = names.map { SFSymbolItem(id: $0) }
    }

    private let fallbackSymbols = [
        "star", "star.fill", "heart", "heart.fill", "circle", "circle.fill",
        "square", "square.fill", "triangle", "triangle.fill", "pencil",
        "trash", "folder", "folder.fill", "doc", "doc.fill",
        "gear", "gearshape", "gearshape.fill", "bell", "bell.fill",
        "person", "person.fill", "house", "house.fill",
        "magnifyingglass", "plus", "minus", "xmark", "checkmark",
        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
        "bolt", "bolt.fill", "flame", "flame.fill",
        "globe", "map", "location", "location.fill",
        "lock", "lock.fill", "key", "key.fill",
        "wifi", "network", "antenna.radiowaves.left.and.right",
        "camera", "camera.fill", "photo", "photo.fill",
        "swift", "terminal", "terminal.fill",
        "hammer", "hammer.fill", "wrench", "wrench.fill",
        "paintbrush", "paintbrush.fill", "paintpalette", "paintpalette.fill",
        "sun.max", "sun.max.fill", "moon", "moon.fill",
        "cloud", "cloud.fill", "sparkles", "wand.and.stars",
    ]
}

// MARK: - Rendering Mode

enum SymbolRenderingMode: String, CaseIterable, Identifiable {
    case monochrome = "Monochrome"
    case hierarchical = "Hierarchical"
    case palette = "Palette"
    case multicolor = "Multicolor"

    var id: String { rawValue }
}

// MARK: - Symbol Weight

enum SymbolWeightOption: String, CaseIterable, Identifiable {
    case ultraLight = "Ultra Light"
    case thin = "Thin"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"

    var id: String { rawValue }

    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    var swiftName: String {
        switch self {
        case .ultraLight: return ".ultraLight"
        case .thin: return ".thin"
        case .light: return ".light"
        case .regular: return ".regular"
        case .medium: return ".medium"
        case .semibold: return ".semibold"
        case .bold: return ".bold"
        case .heavy: return ".heavy"
        case .black: return ".black"
        }
    }
}

// MARK: - Symbol Scale

enum SymbolScaleOption: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var imageScale: Image.Scale {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }

    var swiftName: String {
        switch self {
        case .small: return ".small"
        case .medium: return ".medium"
        case .large: return ".large"
        }
    }
}

// MARK: - SF Symbol Browser View

struct SFSymbolBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = SFSymbolStore.shared
    @State private var searchText = ""
    @State private var selectedSymbol: SFSymbolItem?
    @State private var showCustomization = false

    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 100), spacing: 8)
    ]

    var filteredSymbols: [SFSymbolItem] {
        if searchText.isEmpty {
            return store.allSymbols
        }
        let query = searchText.lowercased()
        return store.allSymbols.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    TextField("Search \(store.allSymbols.count) symbols…", text: $searchText)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Text("\(filteredSymbols.count) symbols")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                Divider().opacity(0.3)

                // Symbol grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filteredSymbols) { symbol in
                            symbolCell(symbol)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("SF Symbols")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustomization) {
                if let symbol = selectedSymbol {
                    SymbolCustomizationView(symbol: symbol)
                }
            }
        }
    }

    private func symbolCell(_ symbol: SFSymbolItem) -> some View {
        Button {
            selectedSymbol = symbol
            showCustomization = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol.name)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)

                Text(symbol.name)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Symbol Customization View

struct SymbolCustomizationView: View {
    let symbol: SFSymbolItem
    @Environment(\.dismiss) private var dismiss

    @State private var renderingMode: SymbolRenderingMode = .monochrome
    @State private var weight: SymbolWeightOption = .regular
    @State private var scale: SymbolScaleOption = .large
    @State private var primaryColor: Color = .blue
    @State private var secondaryColor: Color = .orange
    @State private var copiedText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live Preview
                    livePreview
                        .padding(.top, 12)

                    Divider().opacity(0.3)

                    // Rendering Mode
                    settingsSection("Rendering Mode") {
                        Picker("Mode", selection: $renderingMode) {
                            ForEach(SymbolRenderingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Weight
                    settingsSection("Weight") {
                        Picker("Weight", selection: $weight) {
                            ForEach(SymbolWeightOption.allCases) { w in
                                Text(w.rawValue).tag(w)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Scale
                    settingsSection("Scale") {
                        Picker("Scale", selection: $scale) {
                            ForEach(SymbolScaleOption.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Colors (shown for palette mode)
                    if renderingMode == .palette {
                        settingsSection("Colors") {
                            HStack(spacing: 16) {
                                VStack(spacing: 4) {
                                    Text("Primary").font(.caption2).foregroundStyle(.secondary)
                                    ColorPicker("", selection: $primaryColor)
                                        .labelsHidden()
                                }
                                VStack(spacing: 4) {
                                    Text("Secondary").font(.caption2).foregroundStyle(.secondary)
                                    ColorPicker("", selection: $secondaryColor)
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    Divider().opacity(0.3)

                    // Code snippet
                    settingsSection("SwiftUI Code") {
                        Text(generatedCode)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = generatedCode
                            showCopiedFeedback("Code Copied!")
                        } label: {
                            Label("Copy Code", systemImage: "doc.on.doc")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            UIPasteboard.general.string = "Image(systemName: \"\(symbol.name)\")"
                            showCopiedFeedback("Insert Snippet Copied!")
                        } label: {
                            Label("Insert Into Editor", systemImage: "square.and.pencil")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            UIPasteboard.general.string = symbol.name
                            showCopiedFeedback("Name Copied!")
                        } label: {
                            Label("Copy Symbol Name", systemImage: "character.textbox")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.purple, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if let text = copiedText {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                .padding()
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle(symbol.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Live Preview

    private var livePreview: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Group {
                switch renderingMode {
                case .monochrome:
                    Image(systemName: symbol.name)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(primaryColor)
                case .hierarchical:
                    Image(systemName: symbol.name)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(primaryColor)
                case .palette:
                    Image(systemName: symbol.name)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(primaryColor, secondaryColor)
                case .multicolor:
                    Image(systemName: symbol.name)
                        .symbolRenderingMode(.multicolor)
                }
            }
            .font(.system(size: 64, weight: weight.fontWeight))
            .imageScale(scale.imageScale)
            .frame(width: 120, height: 120)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Code Generation

    private var generatedCode: String {
        var code = "Image(systemName: \"\(symbol.name)\")\n"
        switch renderingMode {
        case .monochrome:
            code += "    .symbolRenderingMode(.monochrome)\n"
        case .hierarchical:
            code += "    .symbolRenderingMode(.hierarchical)\n"
        case .palette:
            code += "    .symbolRenderingMode(.palette)\n"
            code += "    .foregroundStyle(.blue, .orange)\n"
        case .multicolor:
            code += "    .symbolRenderingMode(.multicolor)\n"
        }
        if weight != .regular {
            code += "    .fontWeight(\(weight.swiftName))\n"
        }
        if scale != .large {
            code += "    .imageScale(\(scale.swiftName))\n"
        }
        return code
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showCopiedFeedback(_ text: String) {
        withAnimation {
            copiedText = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation {
                    copiedText = nil
                }
            }
        }
    }
}
