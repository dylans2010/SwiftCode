import Foundation
import Combine

// MARK: - Code Review Issue

struct CodeReviewIssue: Identifiable, Codable {
    var id: UUID = UUID()
    var lineNumber: Int?
    var severity: Severity
    var category: Category
    var description: String
    var suggestion: String
    var codeSnippet: String?
    var isResolved: Bool = false

    enum Severity: String, Codable, CaseIterable {
        case critical = "Critical"
        case warning  = "Warning"
        case info     = "Info"
        case style    = "Style"

        var color: String { // stored as string for Codable compatibility
            switch self {
            case .critical: return "red"
            case .warning:  return "orange"
            case .info:     return "blue"
            case .style:    return "purple"
            }
        }
        var icon: String {
            switch self {
            case .critical: return "xmark.octagon.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .info:     return "info.circle.fill"
            case .style:    return "paintbrush.fill"
            }
        }
    }

    enum Category: String, Codable, CaseIterable {
        case performance   = "Performance"
        case security      = "Security"
        case correctness   = "Correctness"
        case maintainability = "Maintainability"
        case style         = "Style"
        case documentation = "Documentation"
    }
}

// MARK: - Code Review Result

struct CodeReviewResult: Identifiable, Codable {
    var id: UUID = UUID()
    var fileName: String
    var reviewedAt: Date
    var issues: [CodeReviewIssue]
    var overallScore: Int  // 0-100
    var summary: String
    var model: String

    var criticalCount: Int  { issues.filter { $0.severity == .critical }.count }
    var warningCount: Int   { issues.filter { $0.severity == .warning  }.count }
    var unresolvedCount: Int { issues.filter { !$0.isResolved }.count }
}

// MARK: - Code Review Manager

@MainActor
final class CodeReviewManager: ObservableObject {
    static let shared = CodeReviewManager()

    @Published var reviewResults: [CodeReviewResult] = []
    @Published var isReviewing: Bool = false
    @Published var currentResult: CodeReviewResult?
    @Published var errorMessage: String?

    private static let storageKey = "com.swiftcode.codeReviews"

    // 8000 chars keeps the review prompt within typical model context windows
    // while still covering most Swift source files. Increase if using models with larger context limits.
    private static let maxReviewCodeLength = 8000

    // MARK: - Review

    func reviewCode(
        code: String,
        fileName: String,
        model: String? = nil
    ) async {
        isReviewing = true
        errorMessage = nil
        defer { isReviewing = false }

        let resolvedModel = model ?? AppSettings.shared.selectedModel
        let prompt = buildReviewPrompt(code: code, fileName: fileName)

        do {
            let response = try await OpenRouterService.shared.chat(
                messages: [AIMessage(role: "user", content: prompt)],
                model: resolvedModel,
                systemPrompt: reviewSystemPrompt
            )
            let result = parseReviewResponse(response, fileName: fileName, model: resolvedModel)
            currentResult = result
            reviewResults.insert(result, at: 0)
            if reviewResults.count > 20 { reviewResults = Array(reviewResults.prefix(20)) }
            saveReviews()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mark Resolved

    func markResolved(_ issue: CodeReviewIssue, in result: CodeReviewResult) {
        guard let rIdx = reviewResults.firstIndex(where: { $0.id == result.id }),
              let iIdx = reviewResults[rIdx].issues.firstIndex(where: { $0.id == issue.id }) else { return }
        reviewResults[rIdx].issues[iIdx].isResolved = true
        if currentResult?.id == result.id {
            currentResult = reviewResults[rIdx]
        }
        saveReviews()
    }

    // MARK: - Prompt Builders

    private var reviewSystemPrompt: String {
        """
        You are an expert Swift code reviewer. Analyze the provided Swift code and return a JSON response with this exact structure:
        {
          "score": <0-100>,
          "summary": "<2-3 sentence overall assessment>",
          "issues": [
            {
              "lineNumber": <int or null>,
              "severity": "<Critical|Warning|Info|Style>",
              "category": "<Performance|Security|Correctness|Maintainability|Style|Documentation>",
              "description": "<what is wrong>",
              "suggestion": "<how to fix it>",
              "codeSnippet": "<relevant code snippet or null>"
            }
          ]
        }
        Return only valid JSON, no markdown fences.
        """
    }

    private func buildReviewPrompt(code: String, fileName: String) -> String {
        "Review this Swift file '\(fileName)':\n\n\(code.prefix(Self.maxReviewCodeLength))"
    }

    // MARK: - Parser

    private func parseReviewResponse(_ response: String, fileName: String, model: String) -> CodeReviewResult {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CodeReviewResult(
                fileName: fileName,
                reviewedAt: Date(),
                issues: [CodeReviewIssue(
                    severity: .info,
                    category: .documentation,
                    description: "Review completed (could not parse structured output).",
                    suggestion: response.prefix(500).description
                )],
                overallScore: 75,
                summary: "Review completed.",
                model: model
            )
        }

        let score = json["score"] as? Int ?? 75
        let summary = json["summary"] as? String ?? "Review completed."
        var issues: [CodeReviewIssue] = []

        if let rawIssues = json["issues"] as? [[String: Any]] {
            for raw in rawIssues {
                let severityStr = raw["severity"] as? String ?? "Info"
                let categoryStr = raw["category"] as? String ?? "Maintainability"
                let issue = CodeReviewIssue(
                    lineNumber: raw["lineNumber"] as? Int,
                    severity: CodeReviewIssue.Severity(rawValue: severityStr) ?? .info,
                    category: CodeReviewIssue.Category(rawValue: categoryStr) ?? .maintainability,
                    description: raw["description"] as? String ?? "",
                    suggestion: raw["suggestion"] as? String ?? "",
                    codeSnippet: raw["codeSnippet"] as? String
                )
                issues.append(issue)
            }
        }

        return CodeReviewResult(
            fileName: fileName,
            reviewedAt: Date(),
            issues: issues,
            overallScore: score,
            summary: summary,
            model: model
        )
    }

    // MARK: - Persistence

    func saveReviews() {
        if let data = try? JSONEncoder().encode(reviewResults) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func loadReviews() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([CodeReviewResult].self, from: data) else { return }
        reviewResults = decoded
    }

    func deleteResult(_ result: CodeReviewResult) {
        reviewResults.removeAll { $0.id == result.id }
        if currentResult?.id == result.id { currentResult = nil }
        saveReviews()
    }
}
