import SwiftUI

@MainActor
final class AppleDocumentationCache: ObservableObject {
    static let shared = AppleDocumentationCache()
    @Published var content = ""

    func load(path: String) async {
        let base = "https://developer.apple.com/documentation"
        let url = URL(string: "\(base)/\(path)")!
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("docs-\(path.replacingOccurrences(of: "/", with: "_")).txt")

        if let cached = try? String(contentsOf: cacheURL) {
            content = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(decoding: data, as: UTF8.self)
            try? html.write(to: cacheURL, atomically: true, encoding: .utf8)
            content = html
        } catch {
            content = "Failed to load documentation for \(path)."
        }
    }
}

struct DocumentationBrowserView: View {
    @StateObject private var cache = AppleDocumentationCache.shared
    @State private var query = "swiftui"

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search API (e.g. SwiftUI/View)", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { Task { await cache.load(path: query.lowercased()) } }
                }
                .padding()

                ScrollView {
                    Text(cache.content.isEmpty ? "Search Apple documentation." : cache.content)
                        .font(.caption)
                        .textSelection(.enabled)
                        .padding()
                }
            }
            .navigationTitle("Documentation Browser")
        }
    }
}
