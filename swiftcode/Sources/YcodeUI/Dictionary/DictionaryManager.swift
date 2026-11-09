import Foundation
import SwiftUI
import os
import YcodeAssistant

private let logger = Logger(subsystem: "com.swiftcode.dictionary", category: "DictionaryManager")

public enum DictionaryErrorState: Identifiable, Equatable {
    public var id: String {
        switch self {
        case .invalidJSON: return "invalidJSON"
        case .networkFailure(let desc): return "networkFailure:\(desc)"
        case .modelUnavailable: return "modelUnavailable"
        case .timeout: return "timeout"
        case .emptyResponse: return "emptyResponse"
        }
    }

    case invalidJSON(rawText: String)
    case networkFailure(String)
    case modelUnavailable
    case timeout
    case emptyResponse
}

@Observable
@MainActor
public final class DictionaryManager: Sendable {
    public static let shared = DictionaryManager()

    public private(set) var history: [DictionaryHistoryItem] = []
    public var currentResult: CodingDictionaryResult? = nil
    public var isLoading: Bool = false
    public var errorState: DictionaryErrorState? = nil

    private var activeTask: Task<Void, Never>? = nil
    private var lastQuery: String = ""

    private let historyDefaultsKey = "com.swiftcode.dictionary.history"

    private init() {
        loadHistory()
    }

    public func loadHistory() {
        logger.log("Loading search history from UserDefaults.")
        if let data = UserDefaults.standard.data(forKey: historyDefaultsKey),
           let decoded = try? JSONDecoder().decode([DictionaryHistoryItem].self, from: data) {
            self.history = decoded
            logger.log("Loaded \(decoded.count) history items.")
        } else {
            logger.log("No existing history found.")
        }
    }

    public func saveHistory() {
        logger.log("Saving search history to UserDefaults.")
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyDefaultsKey)
            logger.log("Saved \(self.history.count) history items.")
        } else {
            logger.error("Failed to encode history items.")
        }
    }

    public func addToHistory(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        history.removeAll { $0.query.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }

        let newItem = DictionaryHistoryItem(query: trimmed)
        history.insert(newItem, at: 0)
        saveHistory()
    }

    public func togglePin(id: UUID) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].isPinned.toggle()
            saveHistory()
        }
    }

    public func deleteHistoryItem(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    public func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    public func cancelSearch() {
        if activeTask != nil {
            logger.log("Cancelling active search task.")
            activeTask?.cancel()
            activeTask = nil
            isLoading = false
        }
    }

    public func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isLoading && lastQuery == trimmed {
            logger.log("Ignoring duplicate request for '\(trimmed)'")
            return
        }

        cancelSearch()

        isLoading = true
        errorState = nil
        lastQuery = trimmed

        addToHistory(query: trimmed)

        activeTask = Task {
            logger.log("Starting local dictionary search for query: '\(trimmed)'")

            if let result = await LocalDictionaryEngine.shared.answer(query: trimmed) {
                self.currentResult = result
                self.errorState = nil
            } else {
                logger.log("No local matches found for '\(trimmed)'.")
                self.errorState = .emptyResponse
            }

            self.isLoading = false
        }
    }


    private func extractJSON(from text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[firstBrace...lastBrace])
    }
}
