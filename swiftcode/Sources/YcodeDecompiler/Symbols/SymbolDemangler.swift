import Foundation



public enum SymbolDemangler {
    
    public static func demangle(_ name: String) -> String {
        if name.hasPrefix("_$s") || name.hasPrefix("$s") {
            if let out = swiftDemangle(name) { return out }
        }
        if name.hasPrefix("__Z") || name.hasPrefix("_Z") {
            
            if let out = cxxfiltDemangle(name) { return out }
        }
        
        if name.hasPrefix("_") && !name.hasPrefix("__") {
            return String(name.dropFirst())
        }
        return name
    }

    private static func swiftDemangle(_ name: String) -> String? {
        
        guard let out = runTool("/usr/bin/xcrun", ["swift-demangle", name]) else { return nil }
        for line in out.split(separator: "\n") {
            if let arrow = line.range(of: "--->") {
                let demangled = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
                if !demangled.isEmpty { return demangled }
            }
        }
        return nil
    }

    private static func cxxfiltDemangle(_ name: String) -> String? {
        guard let out = runTool("/usr/bin/c++filt", [name]) else { return nil }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == name ? nil : trimmed
    }

    private static func runTool(_ path: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch { return nil }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
