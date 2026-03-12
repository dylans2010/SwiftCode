import Foundation

@MainActor
final class CodeIntelligenceEngine: ObservableObject {
    static let shared = CodeIntelligenceEngine()

    @Published var completions: [String] = []
    @Published var symbols: [String] = []

    func index(content: String) {
        let tokens = content.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
        completions = Array(Set(tokens.map(String.init))).sorted().prefix(20).map { $0 }
        symbols = content
            .split(separator: "\n")
            .filter { $0.contains("func ") || $0.contains("struct ") || $0.contains("class ") }
            .map(String.init)
    }

    func quickDoc(for symbol: String) -> String {
        "Documentation for \(symbol): Inferred from indexed source declarations."
    }
}
