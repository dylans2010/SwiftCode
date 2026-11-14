import Foundation




public enum ProjectExporter {
    
    
    
    
    
    
    
    
    @discardableResult
    public static func copyBundle(from source: URL, to destination: URL) throws -> URL {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue else {
            throw DecompilerError.invalidRequest("not a project bundle: \(source.path)")
        }
        guard fm.fileExists(atPath: source.appendingPathComponent("Project.json").path) else {
            throw DecompilerError.invalidRequest("missing Project.json in \(source.path)")
        }
        guard destination.pathExtension == DecompilerCapabilities.projectFileExtension else {
            throw DecompilerError.invalidRequest(
                "destination must have .\(DecompilerCapabilities.projectFileExtension) extension")
        }
        if fm.fileExists(atPath: destination.path) {
            var destIsDir: ObjCBool = false
            fm.fileExists(atPath: destination.path, isDirectory: &destIsDir)
            let contents = destIsDir.boolValue
                ? ((try? fm.contentsOfDirectory(atPath: destination.path)) ?? [])
                : []
            guard destIsDir.boolValue && contents.isEmpty else {
                throw DecompilerError.invalidRequest(
                    "destination already exists and is not an empty directory: \(destination.path)")
            }
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
        return destination
    }

    
    
    @discardableResult
    public static func export(project: DecompilerProject, to destination: URL) throws -> URL {
        try copyBundle(from: project.bundleURL, to: destination)
    }

    
    
    public static func validateBundle(at url: URL) -> [String] {
        let fm = FileManager.default
        var problems: [String] = []
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return ["not a directory"]
        }
        if url.pathExtension != DecompilerCapabilities.projectFileExtension {
            problems.append("missing .\(DecompilerCapabilities.projectFileExtension) extension")
        }
        if !fm.fileExists(atPath: url.appendingPathComponent("Project.json").path) {
            problems.append("missing Project.json")
        }
        return problems
    }
}
