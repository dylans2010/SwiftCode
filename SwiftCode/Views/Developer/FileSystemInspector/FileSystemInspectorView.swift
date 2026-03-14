import SwiftUI

struct FileSystemInspectorView: View {
    @State private var files: [URL] = []

    var body: some View {
        List(files, id: \.self) { url in
            VStack(alignment: .leading) {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                Text(url.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("FileSystem Inspector")
        .onAppear(perform: loadFiles)
    }

    private func loadFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let contents = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            files = contents
        }
    }
}
