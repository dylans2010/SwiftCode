import Foundation

/// Owns all open Decompiler sessions. Sessions are independent: context from
/// one binary never leaks into another session or into Decompile Assist.
public actor DecompilerSessionManager {
    public static let shared = DecompilerSessionManager()

    private var sessions: [UUID: DecompilerSession] = [:]
    public private(set) var activeSessionID: UUID?

    public init() {}

    @discardableResult
    public func createSession() -> DecompilerSession {
        let session = DecompilerSession(registry: .shared)
        sessions[session.id] = session
        activeSessionID = session.id
        return session
    }

    public func session(id: UUID) -> DecompilerSession? { sessions[id] }
    public func activeSession() -> DecompilerSession? {
        activeSessionID.flatMap { sessions[$0] }
    }

    public func activate(_ id: UUID) {
        if sessions[id] != nil { activeSessionID = id }
    }

    public func allSessions() -> [DecompilerSession] {
        sessions.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    public func closeSession(_ id: UUID) {
        sessions.removeValue(forKey: id)
        if activeSessionID == id {
            activeSessionID = sessions.keys.first
        }
    }

    /// Open a `.scdecomp` project into a session.
    public func openProject(at url: URL) async throws -> DecompilerSession {
        let project = try await DecompilerProjectManager.shared.open(url: url)
        let session = createSession()
        await session.attachProject(project)
        if let binaryURL = project.binaryURL {
            _ = try await session.importBinary(at: binaryURL, sliceIndex: project.selectedSliceIndex)
        }
        return session
    }

    /// Create a new `.scdecomp` project wrapping an imported binary.
    @discardableResult
    public func newProject(named name: String, binaryAt url: URL) async throws -> DecompilerSession {
        let session = createSession()
        _ = try await session.importBinary(at: url)
        let project = try await DecompilerProjectManager.shared.create(name: name, session: session)
        await session.attachProject(project)
        return session
    }
}
