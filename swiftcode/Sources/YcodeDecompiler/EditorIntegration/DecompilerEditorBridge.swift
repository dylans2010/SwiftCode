import Foundation

public protocol DecompilerEditorHandoff: AnyObject, Sendable {
    @MainActor func openProject(at url: URL) async throws
    @MainActor func openFile(at url: URL, line: Int?) async
}

public enum DecompilerEditorBridge {
    @MainActor public static var handoff: (any DecompilerEditorHandoff)?

    @MainActor public static func register(_ value: (any DecompilerEditorHandoff)?) {
        handoff = value
    }

    @MainActor public static var isAvailable: Bool { handoff != nil }

    @MainActor public static func openReconstructedProject(_ project: ReconstructedProject) async -> Bool {
        guard let handoff else { return false }
        do {
            try await handoff.openProject(at: project.rootURL)
            return true
        } catch {
            return false
        }
    }

    @MainActor public static func openSourceLocation(address: DecompilerAddress,
                                                     in project: ReconstructedProject) async -> Bool {
        guard let handoff else { return false }
        guard let entry = project.source.sourceMap.entry(forAddress: address.value)
            ?? project.source.sourceMap.entry(containing: address.value) else { return false }
        await handoff.openFile(at: project.rootURL.appendingPathComponent(entry.file), line: entry.line)
        return true
    }

    @MainActor public static func openAssemblyDiagnostic(_ diagnostic: AssemblyDiagnostic,
                                                         in project: ReconstructedProject) async -> Bool {
        guard let handoff, let file = diagnostic.file else { return false }
        await handoff.openFile(at: project.rootURL.appendingPathComponent(file), line: diagnostic.line)
        return true
    }
}
