import Foundation

enum CollaborationStore {
    static func load<T: Decodable>(_ url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw SpacesError.ioError("cannot decode \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    static func loadRequired<T: Decodable>(_ url: URL, label: String) throws -> T {
        guard let value: T = try load(url) else { throw SpacesError.refNotFound(label) }
        return value
    }

    static func save<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try saveData(encoder.encode(value), to: url)
    }

    static func saveText(_ text: String, to url: URL) throws {
        try saveData(Data(text.utf8), to: url)
    }

    static func saveData(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
    }

    static func listJSONFiles(in dir: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        return names.filter { $0.hasSuffix(".json") }.sorted()
            .map { dir.appendingPathComponent($0) }
    }

    static func now() -> Int64 { Int64(Date().timeIntervalSince1970) }
}

public struct ReviewOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum Status: String, Codable, Sendable, Equatable {
        case open
        case approved
        case changesRequested = "changes-requested"
        case merged
    }

    public struct Approval: Codable, Sendable {
        public var reviewer: String
        public var headRev: String
        public var timestamp: Int64

        public init(reviewer: String, headRev: String, timestamp: Int64) {
            self.reviewer = reviewer
            self.headRev = headRev
            self.timestamp = timestamp
        }
    }

    public struct Review: Codable, Sendable {
        public var id: String
        public var title: String
        public var baseRev: String
        public var headRev: String
        public var author: String
        public var status: Status
        public var created: Int64
        public var approvals: [Approval]

        public init(id: String, title: String, baseRev: String, headRev: String,
                    author: String, status: Status, created: Int64,
                    approvals: [Approval] = []) {
            self.id = id
            self.title = title
            self.baseRev = baseRev
            self.headRev = headRev
            self.author = author
            self.status = status
            self.created = created
            self.approvals = approvals
        }
    }

    public var reviewsDirectory: URL { repo.metaURL.appendingPathComponent("reviews") }

    private func url(for id: String) -> URL {
        reviewsDirectory.appendingPathComponent("\(id).json")
    }

    @discardableResult
    public func createReview(title: String, base: String, head: String) throws -> Review {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("review title must not be empty")
        }
        let baseOID = try repo.resolveRevision(base)
        let headOID = try repo.resolveRevision(head)
        let review = Review(id: UUID().uuidString, title: trimmed,
                            baseRev: baseOID.hex, headRev: headOID.hex,
                            author: repo.identity().name, status: .open,
                            created: CollaborationStore.now())
        try repo.performTransaction(steps: ["review-create:\(review.id)"]) {
            try CollaborationStore.save(review, to: url(for: review.id))
        }
        return review
    }

    public func review(_ id: String) throws -> Review {
        try CollaborationStore.loadRequired(url(for: id), label: "review \(id)")
    }

    public func listReviews() throws -> [Review] {
        var result: [Review] = []
        for file in try CollaborationStore.listJSONFiles(in: reviewsDirectory) {
            if file.lastPathComponent == "policy.json" { continue }
            if let stored: Review = try CollaborationStore.load(file) {
                result.append(stored)
            }
        }
        return result.sorted { $0.created > $1.created }
    }

    public func reviewStatus(_ id: String) throws -> Status {
        try review(id).status
    }

    @discardableResult
    public func updateStatus(_ id: String, to status: Status) throws -> Review {
        try repo.performTransaction(steps: ["review-status:\(id)"]) {
            var stored = try review(id)
            stored.status = status
            try saveReview(stored)
            return stored
        }
    }

    @discardableResult
    public func updateHead(_ id: String, head: String) throws -> Review {
        let headOID = try repo.resolveRevision(head)
        return try repo.performTransaction(steps: ["review-head:\(id)"]) {
            var stored = try review(id)
            stored.headRev = headOID.hex
            try saveReview(stored)
            return stored
        }
    }

    public func saveReview(_ review: Review) throws {
        try CollaborationStore.save(review, to: url(for: review.id))
    }
}
