import Foundation
import Darwin

public enum CodeSearchScope: Equatable, Sendable, Hashable {
    case entireProject
    case openFiles
    case currentFolder(URL)
    case customDirectory(URL)

    public var displayName: String {
        switch self {
        case .entireProject: return "Entire Project"
        case .openFiles: return "Open Files"
        case .currentFolder(let url): return "Folder: \(url.lastPathComponent)"
        case .customDirectory(let url): return "Custom: \(url.lastPathComponent)"
        }
    }
}

public struct CodeSearchOptions: Equatable, Sendable {
    public var caseSensitive: Bool
    public var wholeWord: Bool
    public var useRegex: Bool
    public var fileFilters: String
    public var scope: CodeSearchScope
    public var replacementText: String

    public init(
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        useRegex: Bool = false,
        fileFilters: String = "",
        scope: CodeSearchScope = .entireProject,
        replacementText: String = ""
    ) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.useRegex = useRegex
        self.fileFilters = fileFilters
        self.scope = scope
        self.replacementText = replacementText
    }
}

public struct CodeSearchMatch: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let fileName: String
    public let filePath: String
    public let fullURL: URL
    public let lineNumber: Int
    public let lineContent: String
    public let matchRangeInSnippet: Range<String.Index>?
    public let matchedText: String

    public init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        fullURL: URL,
        lineNumber: Int,
        lineContent: String,
        matchRangeInSnippet: Range<String.Index>? = nil,
        matchedText: String
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.fullURL = fullURL
        self.lineNumber = lineNumber
        self.lineContent = lineContent
        self.matchRangeInSnippet = matchRangeInSnippet
        self.matchedText = matchedText
    }
}

public struct CodeSearchFileGroup: Identifiable, Sendable, Equatable {
    public var id: String { filePath }
    public let fileName: String
    public let filePath: String
    public let fullURL: URL
    public let fileIcon: String
    public var matches: [CodeSearchMatch]
    public var isExpanded: Bool

    public init(
        fileName: String,
        filePath: String,
        fullURL: URL,
        fileIcon: String,
        matches: [CodeSearchMatch],
        isExpanded: Bool = true
    ) {
        self.fileName = fileName
        self.filePath = filePath
        self.fullURL = fullURL
        self.fileIcon = fileIcon
        self.matches = matches
        self.isExpanded = isExpanded
    }
}

public struct CodeSearchStats: Equatable, Sendable {
    public let totalMatches: Int
    public let totalFiles: Int

    public init(totalMatches: Int, totalFiles: Int) {
        self.totalMatches = totalMatches
        self.totalFiles = totalFiles
    }

    public var summaryText: String {
        if totalMatches == 0 {
            return "No matches"
        }
        let matchWord = totalMatches == 1 ? "match" : "matches"
        let fileWord = totalFiles == 1 ? "file" : "files"
        return "\(totalMatches) \(matchWord) across \(totalFiles) \(fileWord)"
    }
}

public enum CodeSearchEngine {
    private static let defaultExcludedDirs: Set<String> = [
        ".git", ".build", "build", "DerivedData", "Pods", ".swiftpm", "node_modules", ".svn", ".hg", "dist", ".cache"
    ]

    private static let commonExtensions: Set<String> = [
        "swift", "m", "h", "mm", "cpp", "c", "hpp", "js", "ts", "jsx", "tsx",
        "json", "plist", "yml", "yaml", "xml", "html", "css", "scss", "md",
        "txt", "sh", "py", "rb", "go", "rs", "toml", "ini", "xcconfig", "sql"
    ]

    public static func search(
        query: String,
        rootURL: URL,
        openFileURLs: [URL] = [],
        options: CodeSearchOptions
    ) async -> [CodeSearchFileGroup] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        return await Task.detached(priority: .userInitiated) {
            var targetFiles: [URL] = []
            switch options.scope {
            case .entireProject:
                targetFiles = collectCandidateFiles(in: rootURL, options: options)
            case .openFiles:
                targetFiles = openFileURLs.filter { matchesFilter(filename: $0.lastPathComponent, filters: options.fileFilters) }
            case .currentFolder(let folderURL):
                targetFiles = collectCandidateFiles(in: folderURL, options: options)
            case .customDirectory(let customURL):
                targetFiles = collectCandidateFiles(in: customURL, options: options)
            }

            var groups: [CodeSearchFileGroup] = []

            for fileURL in targetFiles {
                if Task.isCancelled { break }
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let fileName = fileURL.lastPathComponent

                let matches = searchInContent(
                    content: content,
                    query: trimmedQuery,
                    fileName: fileName,
                    filePath: relativePath,
                    fullURL: fileURL,
                    options: options
                )

                if !matches.isEmpty {
                    let group = CodeSearchFileGroup(
                        fileName: fileName,
                        filePath: relativePath,
                        fullURL: fileURL,
                        fileIcon: iconForFileName(fileName),
                        matches: matches,
                        isExpanded: true
                    )
                    groups.append(group)
                }
            }

            return groups
        }.value
    }

    private static func searchInContent(
        content: String,
        query: String,
        fileName: String,
        filePath: String,
        fullURL: URL,
        options: CodeSearchOptions
    ) -> [CodeSearchMatch] {
        var matches: [CodeSearchMatch] = []
        let lines = content.components(separatedBy: .newlines)

        let regex: NSRegularExpression?
        if options.useRegex {
            let regOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            regex = try? NSRegularExpression(pattern: query, options: regOpts)
        } else if options.wholeWord {
            let escaped = NSRegularExpression.escapedPattern(for: query)
            let regOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            regex = try? NSRegularExpression(pattern: "\\b(?:\(escaped))\\b", options: regOpts)
        } else {
            regex = nil
        }

        for (idx, line) in lines.enumerated() {
            let lineNumber = idx + 1
            if let regex = regex {
                let nsString = line as NSString
                let fullRange = NSRange(location: 0, length: nsString.length)
                let results = regex.matches(in: line, options: [], range: fullRange)
                for r in results {
                    let matchedText = nsString.substring(with: r.range)
                    let trimmedSnippet = line.trimmingCharacters(in: .whitespaces)
                    let matchRangeInSnippet = trimmedSnippet.range(of: matchedText, options: options.caseSensitive ? [] : .caseInsensitive)
                    matches.append(CodeSearchMatch(
                        fileName: fileName,
                        filePath: filePath,
                        fullURL: fullURL,
                        lineNumber: lineNumber,
                        lineContent: trimmedSnippet,
                        matchRangeInSnippet: matchRangeInSnippet,
                        matchedText: matchedText
                    ))
                }
            } else {
                let compOptions: NSString.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
                if let foundRange = line.range(of: query, options: compOptions) {
                    let trimmedSnippet = line.trimmingCharacters(in: .whitespaces)
                    let matchRangeInSnippet = trimmedSnippet.range(of: query, options: compOptions)
                    matches.append(CodeSearchMatch(
                        fileName: fileName,
                        filePath: filePath,
                        fullURL: fullURL,
                        lineNumber: lineNumber,
                        lineContent: trimmedSnippet,
                        matchRangeInSnippet: matchRangeInSnippet,
                        matchedText: String(line[foundRange])
                    ))
                }
            }
        }

        return matches
    }

    private static func collectCandidateFiles(in directoryURL: URL, options: CodeSearchOptions) -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        while let itemURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            let lastComponent = itemURL.lastPathComponent

            var isDir: AnyObject?
            try? (itemURL as NSURL).getResourceValue(&isDir, forKey: .isDirectoryKey)
            if (isDir as? Bool) == true {
                if defaultExcludedDirs.contains(lastComponent) || lastComponent.hasPrefix(".") {
                    enumerator.skipDescendants()
                }
                continue
            }

            let ext = itemURL.pathExtension.lowercased()
            if !options.fileFilters.isEmpty {
                if matchesFilter(filename: lastComponent, filters: options.fileFilters) {
                    results.append(itemURL)
                }
            } else {
                if commonExtensions.contains(ext) || ext.isEmpty {
                    results.append(itemURL)
                }
            }
        }

        return results
    }

    public static func matchesFilter(filename: String, filters: String) -> Bool {
        let trimmed = filters.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let tokens = trimmed.components(separatedBy: CharacterSet(charactersIn: ",; "))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var includes: [String] = []
        var excludes: [String] = []

        for token in tokens {
            if token.hasPrefix("!") {
                excludes.append(String(token.dropFirst()))
            } else {
                includes.append(token)
            }
        }

        for exc in excludes {
            if matchesSingleGlob(filename: filename, pattern: exc) {
                return false
            }
        }

        if includes.isEmpty {
            return true
        }

        for inc in includes {
            if matchesSingleGlob(filename: filename, pattern: inc) {
                return true
            }
        }

        return false
    }

    private static func matchesSingleGlob(filename: String, pattern: String) -> Bool {
        let pat = pattern.hasPrefix("*") ? pattern : (pattern.contains(".") ? "*\(pattern)" : "*\(pattern)*")
        return fnmatch(pat, filename, FNM_CASEFOLD) == 0
    }

    public static func iconForFileName(_ fileName: String) -> String {
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return "swift"
        case "json": return "curlybraces"
        case "plist": return "list.bullet.rectangle"
        case "md", "txt": return "doc.plaintext"
        case "yml", "yaml": return "list.dash"
        case "html", "css", "js", "ts", "jsx", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "py": return "chevron.right.2"
        case "sh", "bash", "zsh": return "terminal"
        default: return "doc.text"
        }
    }

    

    public static func replace(
        match: CodeSearchMatch,
        with replacement: String,
        options: CodeSearchOptions
    ) async throws {
        guard let content = try? String(contentsOf: match.fullURL, encoding: .utf8) else {
            throw NSError(domain: "CodeSearchEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read file: \(match.fullURL.path)"])
        }

        let lines = content.components(separatedBy: .newlines)
        guard lines.indices.contains(match.lineNumber - 1) else { return }

        var targetLine = lines[match.lineNumber - 1]
        let replacedLine: String
        if options.useRegex {
            let regOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            if let regex = try? NSRegularExpression(pattern: match.matchedText, options: regOpts) {
                let range = NSRange(targetLine.startIndex..<targetLine.endIndex, in: targetLine)
                replacedLine = regex.stringByReplacingMatches(in: targetLine, options: [], range: range, withTemplate: replacement)
            } else {
                replacedLine = targetLine.replacingOccurrences(of: match.matchedText, with: replacement)
            }
        } else {
            let compareOptions: NSString.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
            replacedLine = targetLine.replacingOccurrences(of: match.matchedText, with: replacement, options: compareOptions)
        }

        var newLines = lines
        newLines[match.lineNumber - 1] = replacedLine
        let updatedContent = newLines.joined(separator: "\n")
        try updatedContent.write(to: match.fullURL, atomically: true, encoding: .utf8)
    }

    public static func replaceAll(
        in fileGroup: CodeSearchFileGroup,
        query: String,
        replacement: String,
        options: CodeSearchOptions
    ) async throws -> Int {
        guard let content = try? String(contentsOf: fileGroup.fullURL, encoding: .utf8) else { return 0 }

        let updatedContent: String
        let count: Int

        if options.useRegex || options.wholeWord {
            let pattern = options.wholeWord && !options.useRegex ? "\\b(?:\(NSRegularExpression.escapedPattern(for: query)))\\b" : query
            let regOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: regOpts) else { return 0 }
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            count = regex.numberOfMatches(in: content, options: [], range: range)
            updatedContent = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
        } else {
            let compareOptions: NSString.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
            updatedContent = content.replacingOccurrences(of: query, with: replacement, options: compareOptions)
            count = fileGroup.matches.count
        }

        if updatedContent != content {
            try updatedContent.write(to: fileGroup.fullURL, atomically: true, encoding: .utf8)
        }
        return count
    }

    public static func replaceAll(
        in fileGroups: [CodeSearchFileGroup],
        query: String,
        replacement: String,
        options: CodeSearchOptions
    ) async throws -> (filesModified: Int, replacementsCount: Int) {
        var filesModified = 0
        var totalReplacements = 0

        for group in fileGroups {
            let count = try await replaceAll(in: group, query: query, replacement: replacement, options: options)
            if count > 0 {
                filesModified += 1
                totalReplacements += count
            }
        }

        return (filesModified, totalReplacements)
    }

    public static func diffPreview(
        for fileURL: URL,
        query: String,
        replacement: String,
        options: CodeSearchOptions
    ) -> (original: String, modified: String, diffLines: [(type: DiffLineType, text: String)])? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }

        let updatedContent: String
        if options.useRegex || options.wholeWord {
            let pattern = options.wholeWord && !options.useRegex ? "\\b(?:\(NSRegularExpression.escapedPattern(for: query)))\\b" : query
            let regOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: regOpts) else { return nil }
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            updatedContent = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
        } else {
            let compareOptions: NSString.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
            updatedContent = content.replacingOccurrences(of: query, with: replacement, options: compareOptions)
        }

        let origLines = content.components(separatedBy: .newlines)
        let modLines = updatedContent.components(separatedBy: .newlines)

        var diffs: [(type: DiffLineType, text: String)] = []
        let maxLines = max(origLines.count, modLines.count)
        for i in 0..<maxLines {
            let o = i < origLines.count ? origLines[i] : nil
            let m = i < modLines.count ? modLines[i] : nil
            if o == m, let line = o {
                diffs.append((.same, "  \(line)"))
            } else {
                if let o = o { diffs.append((.removed, "- \(o)")) }
                if let m = m { diffs.append((.added, "+ \(m)")) }
            }
        }

        return (content, updatedContent, diffs)
    }

    public enum DiffLineType: Sendable {
        case same
        case added
        case removed
    }
}
