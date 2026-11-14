import Foundation


public actor DecompilerProjectManager {
    public static let shared = DecompilerProjectManager()

    public init() {}

    
    public func create(name: String, session: DecompilerSession? = nil) async throws -> DecompilerProject {
        let fm = FileManager.default
        let base = try fm.url(for: .documentDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true)
            .appendingPathComponent("SwiftCode/DecompilerProjects", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        let bundle = base.appendingPathComponent("\(sanitize(name)).scdecomp", isDirectory: true)
        try? fm.removeItem(at: bundle)
        for sub in ["Binaries", "Cache/Metadata", "Cache/Disassembly", "Cache/Decompilation",
                    "Cache/Graphs", "Exports", "Reports", "Resources"] {
            try fm.createDirectory(at: bundle.appendingPathComponent(sub, isDirectory: true),
                                   withIntermediateDirectories: true)
        }

        var manifest = ProjectManifest(name: name)
        if let session, let image = await session.binary() {
            manifest.binaries = [image.identity]
            manifest.activeBinaryID = image.identity.stableID
            manifest.selectedSlices[image.identity.stableID] = await session.selectedSliceIndex
            
            let dest = bundle.appendingPathComponent("Binaries/\(image.identity.stableID).bin")
            try? fm.copyItem(at: URL(fileURLWithPath: image.identity.originalLocation), to: dest)
        }
        if let session {
            manifest.selectedMode = await session.mode.rawValue
            manifest.analysisConfiguration = await session.configuration
        }

        let project = DecompilerProject(bundleURL: bundle, manifest: manifest)
        try saveManifest(project)
        return project
    }

    
    public func open(url: URL) throws -> DecompilerProject {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw DecompilerError.invalidRequest("not a project bundle: \(url.path)")
        }
        let manifestURL = url.appendingPathComponent("Project.json")
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder.decompiler.decode(ProjectManifest.self, from: data)
        guard manifest.schemaVersion <= DecompilerCapabilities.projectSchemaVersion else {
            throw DecompilerError.persistenceFailure("project schema \(manifest.schemaVersion) is newer than supported \(DecompilerCapabilities.projectSchemaVersion)")
        }
        return DecompilerProject(bundleURL: url, manifest: manifest)
    }

    public func saveManifest(_ project: DecompilerProject) throws {
        var manifest = project.manifest
        manifest.modifiedAt = Date()
        let encoder = JSONEncoder.decompiler
        let data = try encoder.encode(manifest)
        try data.write(to: project.manifestURL, options: .atomic)
    }

    
    public func syncManifest(_ project: DecompilerProject, session: DecompilerSession) async throws -> DecompilerProject {
        var manifest = project.manifest
        manifest.modifiedAt = Date()
        if let image = await session.binary() {
            if !manifest.binaries.contains(image.identity) { manifest.binaries.append(image.identity) }
            manifest.activeBinaryID = image.identity.stableID
            manifest.selectedSlices[image.identity.stableID] = await session.selectedSliceIndex
        }
        manifest.selectedMode = await session.mode.rawValue
        manifest.analysisConfiguration = await session.configuration
        var updated = project
        updated.manifest = manifest
        try saveManifest(updated)
        return updated
    }

    @discardableResult
    public func save(_ project: DecompilerProject, session: DecompilerSession) async throws -> DecompilerProject {
        let synced = try await syncManifest(project, session: session)
        try await AnalysisPersistence.save(store: await session.analysisStore(), project: synced,
                                           image: await session.binary())
        return synced
    }

    public func validate(_ project: DecompilerProject) -> [String] {
        var problems: [String] = []
        if !FileManager.default.fileExists(atPath: project.manifestURL.path) {
            problems.append("missing Project.json")
        }
        if project.binaryURL == nil {
            problems.append("no readable binary for active slice")
        }
        return problems
    }

    private func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_. "))
        let cleaned = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let s = String(cleaned).trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "Untitled" : s
    }
}

extension JSONEncoder {
    static var decompiler: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var decompiler: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
