import Foundation










public struct DecompileAssistAssetLoader: Sendable {

    
    public static let promptBudget = 12_000

    
    private static let requiredAssets = ["IDENTITY", "SOUL", "SYSTEM", "MEMORY", "SECURITY"]

    private let directories: [URL]

    public init() {
        var dirs: [URL] = []

        if let moduleResources = Bundle.module.resourceURL {
            dirs.append(moduleResources.appendingPathComponent("SystemAssets/DecompileAssist", isDirectory: true))
        }
        if let mainResources = Bundle.main.resourceURL {
            dirs.append(mainResources.appendingPathComponent("SystemAssets/DecompileAssist", isDirectory: true))
            dirs.append(mainResources.appendingPathComponent("Decompiler/SystemAssets/DecompileAssist", isDirectory: true))
            
            
            dirs.append(mainResources)
        }
        
        
        let sourceFile = URL(fileURLWithPath: #filePath)
        let decompilerRoot = sourceFile
            .deletingLastPathComponent() 
            .deletingLastPathComponent() 
            .deletingLastPathComponent() 
        dirs.append(decompilerRoot.appendingPathComponent("Resources/SystemAssets/DecompileAssist", isDirectory: true))

        var seen = Set<String>()
        self.directories = dirs.filter { dir in
            let key = dir.standardizedFileURL.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return FileManager.default.fileExists(atPath: dir.path)
        }
    }

    
    public func asset(named name: String) -> String? {
        for dir in directories {
            let url = dir.appendingPathComponent("\(name).md")
            if let text = try? String(contentsOf: url, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }

    
    
    
    
    
    
    
    public func corePrompt(
        mode: DecompilerSession.Mode,
        architecture: BinaryArchitecture?,
        format: BinaryFormat?
    ) throws -> String {
        var missing: [String] = []
        var required: [(String, String)] = []
        for name in Self.requiredAssets {
            guard let text = asset(named: name) else {
                missing.append("\(name).md")
                continue
            }
            required.append((name, text))
        }
        guard missing.isEmpty else {
            throw DecompilerError.engineUnavailable(
                "Decompile Assist system assets missing: \(missing.joined(separator: ", "))"
            )
        }

        
        var optional: [(String, String)] = []
        func addOptional(_ name: String) {
            if let text = asset(named: name) {
                optional.append((name, text))
            }
        }
        addOptional(mode == .friendly ? "FRIENDLY_MODE" : "MASTER_MODE")
        if let format {
            switch format {
            case .machO: addOptional("MACHO")
            case .elf: addOptional("ELF")
            case .pe: addOptional("PE")
            case .unknown: break
            }
        }
        if let architecture {
            switch architecture {
            case .arm64, .arm64_32: addOptional("ARM64")
            case .x86_64: addOptional("X86_64")
            default: break
            }
        }
        addOptional("DECOMPILATION")
        addOptional("TOOLS")
        addOptional("OUTPUT_FORMAT")
        addOptional("EVIDENCE")
        addOptional("LIMITATIONS")

        func render(_ docs: [(String, String)]) -> String {
            docs.map { "## \($0.0)\n\n\($0.1)" }.joined(separator: "\n\n---\n\n")
        }
        func totalLength(_ docs: [(String, String)]) -> Int {
            body.count + (docs.isEmpty ? 0 : 4 + render(docs).count)
        }

        var body = render(required)
        var keptOptional: [(String, String)] = []

        
        
        
        
        for doc in optional {
            if totalLength(keptOptional + [doc]) <= Self.promptBudget {
                keptOptional.append(doc)
                continue
            }
            let remaining = Self.promptBudget - totalLength(keptOptional) - 64
            if remaining > 400, doc.1.count > remaining {
                keptOptional.append((doc.0, String(doc.1.prefix(remaining)) + "\n\n…(truncated)"))
            }
            break
        }

        if !keptOptional.isEmpty {
            body += "\n\n---\n\n" + render(keptOptional)
        }
        return body
    }
}
