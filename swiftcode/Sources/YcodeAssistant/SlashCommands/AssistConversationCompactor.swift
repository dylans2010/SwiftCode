import Foundation
import os

private let logger = Logger(subsystem: "com.swiftcode.app", category: "AssistConversationCompactor")

public struct CompactionResult: Sendable, Codable {
    public let beforeTokens: Int
    public let afterTokens: Int
    public let tokensSaved: Int
    public let percentageSaved: Double
    public let messagesCondensed: Int
    public let summary: String

    public init(
        beforeTokens: Int,
        afterTokens: Int,
        tokensSaved: Int,
        percentageSaved: Double,
        messagesCondensed: Int,
        summary: String
    ) {
        self.beforeTokens = beforeTokens
        self.afterTokens = afterTokens
        self.tokensSaved = tokensSaved
        self.percentageSaved = percentageSaved
        self.messagesCondensed = messagesCondensed
        self.summary = summary
    }
}

@MainActor
public final class AssistConversationCompactor: Sendable {
    public static let shared = AssistConversationCompactor()

    private init() {}

    public func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    public func compactCurrentSession(focusInstructions: String? = nil) async -> CompactionResult {
        logger.info("Executing conversation compaction...")

        let manager = AssistManager.shared
        let originalMessages = manager.messages

        guard originalMessages.count > 2 else {
            let totalTokens = originalMessages.reduce(0) { $0 + estimateTokens($1.content) }
            return CompactionResult(
                beforeTokens: totalTokens,
                afterTokens: totalTokens,
                tokensSaved: 0,
                percentageSaved: 0.0,
                messagesCondensed: 0,
                summary: "Conversation is already compact (\(originalMessages.count) messages)."
            )
        }

        let beforeTokens = originalMessages.reduce(0) { $0 + estimateTokens($1.content) }

        // Keep the latest 2-3 active messages (typically the most recent user turn and partial response)
        let preserveCount = min(3, originalMessages.count)
        let olderMessages = Array(originalMessages.dropLast(preserveCount))
        let recentMessages = Array(originalMessages.suffix(preserveCount))

        // Synthesize structured summary of older messages
        var objectives: [String] = []
        var filesMentioned = Set<String>()
        var keyDecisions: [String] = []
        var errorsResolved: [String] = []
        var pendingItems: [String] = []

        for msg in olderMessages {
            let content = msg.content
            if msg.role == .user {
                let firstLine = content.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !firstLine.isEmpty && !firstLine.hasPrefix("/") && !firstLine.hasPrefix("@") {
                    objectives.append(firstLine)
                }
            } else if msg.role == .assistant {
                // Extract file paths
                let words = content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                for word in words {
                    if (word.hasSuffix(".swift") || word.hasSuffix(".md") || word.hasSuffix(".json") || word.hasSuffix(".yml") || word.hasSuffix(".plist")) && word.count > 6 {
                        let clean = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        if !clean.isEmpty {
                            filesMentioned.insert(clean)
                        }
                    }
                }

                if content.localizedCaseInsensitiveContains("fixed") || content.localizedCaseInsensitiveContains("resolved") || content.localizedCaseInsensitiveContains("repaired") {
                    let lines = content.components(separatedBy: .newlines).filter {
                        $0.localizedCaseInsensitiveContains("error") || $0.localizedCaseInsensitiveContains("fixed") || $0.localizedCaseInsensitiveContains("resolved")
                    }
                    if let first = lines.first {
                        errorsResolved.append(String(first.prefix(120)))
                    }
                }

                if content.localizedCaseInsensitiveContains("decision") || content.localizedCaseInsensitiveContains("architecture") || content.localizedCaseInsensitiveContains("pattern") {
                    let lines = content.components(separatedBy: .newlines).filter {
                        $0.localizedCaseInsensitiveContains("architecture") || $0.localizedCaseInsensitiveContains("pattern") || $0.localizedCaseInsensitiveContains("decided")
                    }
                    if let first = lines.first {
                        keyDecisions.append(String(first.prefix(120)))
                    }
                }
            }
        }

        var summaryLines: [String] = []
        summaryLines.append("### 🗜️ Compacted Conversation Summary")
        if let focus = focusInstructions, !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            summaryLines.append("**Focus Area**: \(focus)")
        }

        if !objectives.isEmpty {
            summaryLines.append("**User Goals & Inquiries**:")
            for obj in objectives.suffix(5) {
                summaryLines.append("- \(obj)")
            }
        }

        if !filesMentioned.isEmpty {
            let fileList = Array(filesMentioned.sorted().prefix(12)).joined(separator: ", ")
            summaryLines.append("**Relevant Files Touched**: \(fileList)")
        }

        if !keyDecisions.isEmpty {
            summaryLines.append("**Architectural Decisions**:")
            for dec in keyDecisions.suffix(3) {
                summaryLines.append("- \(dec)")
            }
        }

        if !errorsResolved.isEmpty {
            summaryLines.append("**Issues Addressed**:")
            for err in errorsResolved.suffix(3) {
                summaryLines.append("- \(err)")
            }
        }

        let summaryText = summaryLines.joined(separator: "\n\n")

        var compactedSystemMessage = AssistMessage(
            role: .system,
            content: "[CONVERSATION COMPACTED BY ASSIST]\n\n\(summaryText)\n\n[Continuity Preserved: All past context summarized above. Proceed directly with next actions.]"
        )
        compactedSystemMessage.providerID = "compactor"

        var newMessages: [AssistMessage] = [compactedSystemMessage]
        newMessages.append(contentsOf: recentMessages)

        manager.messages = newMessages
        manager.saveHistory()

        let afterTokens = newMessages.reduce(0) { $0 + estimateTokens($1.content) }
        let tokensSaved = max(0, beforeTokens - afterTokens)
        let percentageSaved = beforeTokens > 0 ? (Double(tokensSaved) / Double(beforeTokens)) * 100.0 : 0.0

        let result = CompactionResult(
            beforeTokens: beforeTokens,
            afterTokens: afterTokens,
            tokensSaved: tokensSaved,
            percentageSaved: percentageSaved,
            messagesCondensed: olderMessages.count,
            summary: summaryText
        )

        logger.info("Compaction completed: reduced from \(beforeTokens) to \(afterTokens) tokens (-$${\(percentageSaved, format: .fixed(precision: 1))}%).")

        return result
    }
}
