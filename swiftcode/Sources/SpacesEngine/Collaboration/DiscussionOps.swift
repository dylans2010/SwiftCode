import Foundation

public struct DiscussionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct HistoryEntry: Codable, Sendable {
        public var body: String
        public var timestamp: Int64

        public init(body: String, timestamp: Int64) {
            self.body = body
            self.timestamp = timestamp
        }
    }

    public struct Comment: Codable, Sendable {
        public var id: String
        public var path: String
        public var line: Int
        public var author: String
        public var body: String
        public var timestamp: Int64
        public var resolved: Bool
        public var history: [HistoryEntry]

        public init(id: String, path: String, line: Int, author: String, body: String,
                    timestamp: Int64, resolved: Bool, history: [HistoryEntry] = []) {
            self.id = id
            self.path = path
            self.line = line
            self.author = author
            self.body = body
            self.timestamp = timestamp
            self.resolved = resolved
            self.history = history
        }
    }

    public struct DiscussionFile: Codable, Sendable {
        public var comments: [Comment]

        public init(comments: [Comment] = []) { self.comments = comments }
    }

    private func url(for review: String) -> URL {
        repo.metaURL.appendingPathComponent("reviews")
            .appendingPathComponent(review)
            .appendingPathComponent("discussions.json")
    }

    private func loadDiscussions(review: String) throws -> DiscussionFile {
        if let file: DiscussionFile = try CollaborationStore.load(url(for: review)) {
            return file
        }
        return DiscussionFile()
    }

    private func saveDiscussions(_ file: DiscussionFile, review: String) throws {
        try CollaborationStore.save(file, to: url(for: review))
    }

    @discardableResult
    public func addComment(review: String, path: String, line: Int,
                           body: String) throws -> Comment {
        _ = try ReviewOps(repo: repo).review(review)
        guard line >= 1 else {
            throw SpacesError.invalidArgument("comment line must be at least 1")
        }
        guard !path.isEmpty else {
            throw SpacesError.invalidArgument("comment path must not be empty")
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("comment body must not be empty")
        }
        let comment = Comment(id: UUID().uuidString, path: path, line: line,
                              author: repo.identity().name, body: trimmed,
                              timestamp: CollaborationStore.now(), resolved: false)
        return try repo.performTransaction(steps: ["discussion-add:\(review)"]) {
            var file = try loadDiscussions(review: review)
            file.comments.append(comment)
            try saveDiscussions(file, review: review)
            return comment
        }
    }

    public func listComments(review: String) throws -> [Comment] {
        _ = try ReviewOps(repo: repo).review(review)
        return try loadDiscussions(review: review).comments
            .sorted { $0.timestamp < $1.timestamp }
    }

    @discardableResult
    public func editComment(review: String, id: String, body: String) throws -> Comment {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("comment body must not be empty")
        }
        return try repo.performTransaction(steps: ["discussion-edit:\(review)"]) {
            var file = try loadDiscussions(review: review)
            guard let index = file.comments.firstIndex(where: { $0.id == id }) else {
                throw SpacesError.refNotFound("comment \(id)")
            }
            file.comments[index].history.append(
                HistoryEntry(body: file.comments[index].body,
                             timestamp: file.comments[index].timestamp))
            file.comments[index].body = trimmed
            file.comments[index].timestamp = CollaborationStore.now()
            try saveDiscussions(file, review: review)
            return file.comments[index]
        }
    }

    @discardableResult
    public func resolveComment(review: String, id: String) throws -> Comment {
        return try repo.performTransaction(steps: ["discussion-resolve:\(review)"]) {
            var file = try loadDiscussions(review: review)
            guard let index = file.comments.firstIndex(where: { $0.id == id }) else {
                throw SpacesError.refNotFound("comment \(id)")
            }
            file.comments[index].resolved = true
            try saveDiscussions(file, review: review)
            return file.comments[index]
        }
    }
}
