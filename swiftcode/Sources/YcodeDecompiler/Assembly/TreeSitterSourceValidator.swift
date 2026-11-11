import Foundation
#if canImport(SwiftTreeSitter)
import SwiftTreeSitter
#if canImport(TreeSitterC)
import TreeSitterC
#endif
#if canImport(TreeSitterCPP)
import TreeSitterCPP
#endif
#if canImport(TreeSitterRust)
import TreeSitterRust
#endif
#if canImport(TreeSitterGo)
import TreeSitterGo
#endif
#if canImport(TreeSitterJava)
import TreeSitterJava
#endif
#if canImport(TreeSitterJavaScript)
import TreeSitterJavaScript
#endif
#if canImport(TreeSitterPython)
import TreeSitterPython
#endif
#if canImport(TreeSitterCSharp)
import TreeSitterCSharp
#endif
#if canImport(SwiftParser)
import SwiftParser
#endif
#if canImport(SwiftParserDiagnostics)
import SwiftParserDiagnostics
#endif
#if canImport(SwiftSyntax)
import SwiftSyntax
#endif

public struct TreeSitterSourceValidator: PreAssembleValidator {
    public var id: String { "tree-sitter-syntax" }
    public var displayName: String { "Syntax validation (tree-sitter)" }

    public init() {}

    public func validate(project: ReconstructedProject,
                         configuration: BuildConfiguration) async throws -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        var skippedExtensions: Set<String> = []
        let files = Self.collectSourceFiles(under: project.rootURL)
        for file in files.sorted(by: { $0.path < $1.path }) {
            let ext = file.pathExtension.lowercased()
            let relative = Self.relativePath(of: file, projectRoot: project.rootURL)
            guard let text = try? String(contentsOf: file, encoding: .utf8) else {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    message: "Could not read \(relative) as UTF-8 text; syntax validation skipped for this file.",
                    file: relative, origin: .userCode,
                    rawText: ""))
                continue
            }
            if ext == "swift" {
                diagnostics.append(contentsOf: Self.validateSwiftSource(text, relativePath: relative))
                continue
            }
            guard let language = Self.language(forExtension: ext) else {
                if !Self.unsupportedExtensions.contains(ext) {
                    skippedExtensions.insert(ext)
                }
                continue
            }
            diagnostics.append(contentsOf: Self.validateTreeSitterSource(text, language: language, relativePath: relative))
        }
        if !skippedExtensions.isEmpty {
            diagnostics.append(AssemblyDiagnostic(
                severity: .info,
                message: "No syntax grammar is available for \(skippedExtensions.sorted().map { ".\($0)" }.joined(separator: ", ")); those files were not syntax-checked before compiling.",
                origin: .projectConfiguration,
                suggestion: "Syntax errors in those files are still reported by the compiler during Assemble."))
        }
        return diagnostics
    }

    /// Synchronous directory walk — `DirectoryEnumerator` sequence iteration
    /// is unavailable from async contexts on recent SDKs.
    static func collectSourceFiles(under root: URL) -> [URL] {
        var files: [URL] = []
        for dir in ["Sources", "Assembly", "Headers"] {
            let base = root.appendingPathComponent(dir, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where !url.hasDirectoryPath {
                files.append(url)
            }
        }
        return files
    }

    static let unsupportedExtensions: Set<String> = [
        "m", "mm", "kt", "kts", "lua", "nim", "d", "s", "S", "o", "json", "md", "txt", "plist", "entitlements",
    ]

    static func language(forExtension ext: String) -> Language? {
        switch ext {
        case "c", "h":
#if canImport(TreeSitterC)
            return Language(tree_sitter_c())
#else
            return nil
#endif
        case "cpp", "cc", "cxx", "hpp", "hh":
#if canImport(TreeSitterCPP)
            return Language(tree_sitter_cpp())
#else
            return nil
#endif
        case "rs":
#if canImport(TreeSitterRust)
            return Language(tree_sitter_rust())
#else
            return nil
#endif
        case "go":
#if canImport(TreeSitterGo)
            return Language(tree_sitter_go())
#else
            return nil
#endif
        case "java":
#if canImport(TreeSitterJava)
            return Language(tree_sitter_java())
#else
            return nil
#endif
        case "js", "mjs", "cjs":
#if canImport(TreeSitterJavaScript)
            return Language(tree_sitter_javascript())
#else
            return nil
#endif
        case "py":
#if canImport(TreeSitterPython)
            return Language(tree_sitter_python())
#else
            return nil
#endif
        case "cs":
#if canImport(TreeSitterCSharp)
            return Language(tree_sitter_c_sharp())
#else
            return nil
#endif
        default:
            return nil
        }
    }

    static func validateTreeSitterSource(_ text: String, language: Language,
                                         relativePath: String) -> [AssemblyDiagnostic] {
        let parser = Parser()
        do {
            try parser.setLanguage(language)
        } catch {
            return [AssemblyDiagnostic(
                severity: .warning,
                message: "Could not load the syntax grammar for \(relativePath); syntax validation skipped for this file.",
                file: relativePath, origin: .userCode, rawText: "")]
        }
        guard let tree = parser.parse(text), let root = tree.rootNode else {
            return [AssemblyDiagnostic(
                severity: .warning,
                message: "Could not parse \(relativePath); syntax validation skipped for this file.",
                file: relativePath, origin: .userCode, rawText: "")]
        }
        guard root.hasError else { return [] }
        var diagnostics: [AssemblyDiagnostic] = []
        collectErrors(node: root, relativePath: relativePath, diagnostics: &diagnostics)
        return diagnostics
    }

    static func collectErrors(node: Node, relativePath: String, diagnostics: inout [AssemblyDiagnostic]) {
        if node.isMissing {
            let point = node.pointRange.lowerBound
            diagnostics.append(AssemblyDiagnostic(
                severity: .error,
                message: "Syntax error: expected \(node.nodeType ?? "token") here.",
                file: relativePath, line: Int(point.row) + 1, column: Int(point.column) + 1,
                origin: .userCode,
                suggestion: "Fix the syntax error in the main editor, then Assemble again.",
                rawText: ""))
            return
        }
        if node.nodeType == "ERROR" {
            let point = node.pointRange.lowerBound
            diagnostics.append(AssemblyDiagnostic(
                severity: .error,
                message: "Syntax error: unexpected input at this position.",
                file: relativePath, line: Int(point.row) + 1, column: Int(point.column) + 1,
                origin: .userCode,
                suggestion: "Fix the syntax error in the main editor, then Assemble again.",
                rawText: ""))
            return
        }
        guard node.hasError else { return }
        for index in 0..<node.childCount {
            if let child = node.child(at: index) {
                collectErrors(node: child, relativePath: relativePath, diagnostics: &diagnostics)
            }
        }
    }

    static func validateSwiftSource(_ text: String, relativePath: String) -> [AssemblyDiagnostic] {
#if canImport(SwiftParser) && canImport(SwiftParserDiagnostics)
        let tree = Parser.parse(source: text)
        let converter = SourceLocationConverter(fileName: relativePath, tree: tree)
        var diagnostics: [AssemblyDiagnostic] = []
        for diagnostic in ParseDiagnosticsGenerator.diagnostics(for: tree) {
            let location = converter.location(for: diagnostic.position)
            diagnostics.append(AssemblyDiagnostic(
                severity: diagnostic.diagMessage.severity == .error ? .error : .warning,
                message: diagnostic.diagMessage.message,
                file: relativePath, line: location.line, column: location.column,
                origin: .userCode,
                suggestion: "Fix the syntax error in the main editor, then Assemble again.",
                rawText: ""))
        }
        return diagnostics
#else
        return [AssemblyDiagnostic(
            severity: .info,
            message: "No Swift syntax parser is linked; \(relativePath) was not syntax-checked before compiling.",
            file: relativePath, origin: .projectConfiguration,
            suggestion: "Syntax errors in Swift files are still reported by swiftc during Assemble.")]
#endif
    }

    static func relativePath(of url: URL, projectRoot: URL) -> String {
        // `temporaryDirectory` yields /var/... while directory enumeration can
        // return /private/var/... — compare symlink-resolved paths.
        var rootPath = projectRoot.resolvingSymlinksInPath().path
        while rootPath.hasSuffix("/") { rootPath.removeLast() }
        let path = url.resolvingSymlinksInPath().path
        return path.hasPrefix(rootPath)
            ? String(path.dropFirst(rootPath.count + 1))
            : url.lastPathComponent
    }
}

#endif
