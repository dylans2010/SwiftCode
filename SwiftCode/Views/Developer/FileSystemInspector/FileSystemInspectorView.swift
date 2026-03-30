import SwiftUI

struct FileSystemInspectorView: View {
    @State private var currentURL: URL
    @State private var items: [URL] = []

    init() {
        _currentURL = State(initialValue: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
    }

    var body: some View {
        List {
            Section(header: Text(currentURL.path)) {
                if currentURL.path != "/" && currentURL.path != NSHomeDirectory() {
                    Button {
                        goUp()
                    } label: {
                        Label(".. (Parent Directory)", systemImage: "arrow.up.doc")
                    }
                }

                ForEach(items, id: \.self) { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                    if isDir {
                        Button {
                            currentURL = url
                            loadItems()
                        } label: {
                            HStack {
                                Label(url.lastPathComponent, systemImage: "folder.fill")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Label(url.lastPathComponent, systemImage: "doc")
                                .font(.subheadline)
                            Text(fileSize(for: url))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        try? FileManager.default.removeItem(at: items.first(where: { $0 == items[0] })!) // Fix later
                        loadItems()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("File System")
        .onAppear(perform: loadItems)
        .toolbar {
            Button {
                loadItems()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private func loadItems() {
        if let contents = try? FileManager.default.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles) {
            items = contents.sorted { a, b in
                let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if aDir != bDir { return aDir }
                return a.lastPathComponent < b.lastPathComponent
            }
        }
    }

    private func goUp() {
        currentURL = currentURL.deletingLastPathComponent()
        loadItems()
    }

    private func fileSize(for url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
