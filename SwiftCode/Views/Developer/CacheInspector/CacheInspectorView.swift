import SwiftUI

struct CacheInspectorView: View {
    @State private var cacheFiles: [URL] = []
    @State private var totalSize: String = "0 KB"

    var body: some View {
        List {
            Section("Stats") {
                LabeledContent("Total Cache Size", value: totalSize)
                Button("Clear All Cache", role: .destructive) {
                    clearAll()
                }
            }

            Section("Cache Files (\(cacheFiles.count))") {
                if cacheFiles.isEmpty {
                    Text("No cache files found")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(cacheFiles, id: \.self) { url in
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .font(.subheadline.bold())
                            Text(fileSize(for: url))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Cache Inspector")
        .onAppear(perform: loadCache)
    }

    private func loadCache() {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        if let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            cacheFiles = contents
            updateTotalSize()
        }
    }

    private func updateTotalSize() {
        var total: Int64 = 0
        for file in cacheFiles {
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
            total += (attrs?[.size] as? Int64) ?? 0
        }
        totalSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func fileSize(for url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func clearAll() {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        for file in cacheFiles {
            try? FileManager.default.removeItem(at: file)
        }
        loadCache()
    }
}
