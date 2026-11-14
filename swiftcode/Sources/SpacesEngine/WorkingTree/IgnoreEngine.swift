import Foundation





public struct IgnoreEngine: Sendable {
    public struct Rule: Sendable {
        public var pattern: String
        public var isNegation: Bool
        public var isDirectoryOnly: Bool
        public var isAnchored: Bool
        public var regex: NSRegularExpression?
        
        public var basePath: String

        
        public func matches(_ path: String, isDirectory: Bool) -> Bool {
            if isDirectoryOnly && !isDirectory { return false }
            let rel = basePath.isEmpty ? path : path
            
            let candidate: String
            if basePath.isEmpty {
                candidate = rel
            } else if rel.hasPrefix(basePath + "/") {
                candidate = String(rel.dropFirst(basePath.count + 1))
            } else {
                return false
            }
            guard let regex else { return false }
            let range = NSRange(candidate.startIndex..., in: candidate)
            return regex.firstMatch(in: candidate, range: range) != nil
        }
    }

    public private(set) var rules: [Rule] = []

    public init() {}

    
    
    
    public static func loadRootRules(worktree: URL) -> IgnoreEngine {
        var engine = IgnoreEngine()
        for name in [RepositoryFormat.ignoreFileName, RepositoryFormat.gitignoreFileName] {
            let url = worktree.appendingPathComponent(name)
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                engine.addRules(from: text, basePath: "")
            }
        }
        return engine
    }

    public mutating func addRules(from text: String, basePath: String) {
        for rawLine in text.components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasSuffix("\r") { line.removeLast() }
            var isNegation = false
            if line.hasPrefix("!") { isNegation = true; line.removeFirst() }
            var isDirOnly = false
            if line.hasSuffix("/") { isDirOnly = true; line.removeLast() }
            var isAnchored = false
            if line.hasPrefix("/") { isAnchored = true; line.removeFirst() }
            guard !line.isEmpty else { continue }

            
            var pattern = ""
            var i = line.startIndex
            let chars = Array(line)
            var idx = 0
            while idx < chars.count {
                let c = chars[idx]
                if c == "*" {
                    if idx + 1 < chars.count && chars[idx + 1] == "*" {
                        
                        if idx + 2 < chars.count && chars[idx + 2] == "/" {
                            pattern += "(?:.*/)?"
                            idx += 3
                        } else {
                            pattern += ".*"
                            idx += 2
                        }
                    } else {
                        pattern += "[^/]*"
                        idx += 1
                    }
                } else if c == "?" {
                    pattern += "[^/]"
                    idx += 1
                } else {
                    pattern += NSRegularExpression.escapedPattern(for: String(c))
                    idx += 1
                }
                i = line.index(after: i) 
            }
            
            let body = isAnchored ? pattern : "(?:.*/)?" + pattern
            let regexText = "^" + body + (isDirOnly ? "/?$" : "(?:/.*)?$")
            let regex = try? NSRegularExpression(pattern: regexText)
            rules.append(Rule(pattern: line, isNegation: isNegation,
                              isDirectoryOnly: isDirOnly, isAnchored: isAnchored,
                              regex: regex, basePath: basePath))
        }
    }

    
    public mutating func addFile(at url: URL, relativeTo worktree: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let base = (try? Self.relativePath(url.deletingLastPathComponent(), to: worktree)) ?? ""
        addRules(from: text, basePath: base)
    }

    
    
    public func isIgnored(_ path: String, isDirectory: Bool) -> Bool {
        var ignored = false
        for rule in rules {
            if rule.matches(path, isDirectory: isDirectory) {
                ignored = !rule.isNegation
            }
        }
        return ignored
    }

    
    public static func isAlwaysIgnored(_ path: String) -> Bool {
        path == RepositoryFormat.metadataDirectoryName
            || path.hasPrefix(RepositoryFormat.metadataDirectoryName + "/")
    }

    private static func relativePath(_ url: URL, to base: URL) throws -> String {
        let b = base.standardizedFileURL.path
        let f = url.standardizedFileURL.path
        guard f.hasPrefix(b) else { return "" }
        var rel = String(f.dropFirst(b.count))
        if rel.hasPrefix("/") { rel.removeFirst() }
        return rel
    }
}
