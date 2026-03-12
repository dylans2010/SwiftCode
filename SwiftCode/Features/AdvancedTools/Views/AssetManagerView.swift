import SwiftUI

struct AssetManagerView: View {
    @State private var importedAssets: [String] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Button("Import Image") {
                    importedAssets.append("ImportedAsset-\(importedAssets.count + 1).png")
                }
                .buttonStyle(.borderedProminent)

                GroupBox("App Icon Validation") {
                    Text("Missing sizes: 20pt, 29pt, 40pt, 60pt")
                }

                GroupBox("Assets") {
                    ForEach(importedAssets, id: \.self) { asset in
                        HStack {
                            Image(systemName: "photo")
                            Text(asset)
                            Spacer()
                            Button("Resize") {}
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Asset Manager")
        }
    }
}
