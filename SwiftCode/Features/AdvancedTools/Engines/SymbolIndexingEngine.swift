import Foundation

struct IndexedSymbol: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let file: String
    let line: Int
}

@MainActor
final class SymbolIndexingEngine: ObservableObject {
    static let shared = SymbolIndexingEngine()
    @Published var symbols: [IndexedSymbol] = []

    func index(project: Project?) {
        guard let project else { symbols = []; return }
        var output: [IndexedSymbol] = []
        for file in project.files {
            collectSymbols(in: file, results: &output)
        }
        symbols = output
    }

    private func collectSymbols(in node: FileNode, results: inout [IndexedSymbol]) {
        if node.isDirectory {
            node.children.forEach { collectSymbols(in: $0, results: &results) }
        } else if node.name.hasSuffix(".swift") {
            results.append(.init(name: node.name.replacingOccurrences(of: ".swift", with: ""), kind: "file", file: node.path, line: 1))
        }
    }
}
