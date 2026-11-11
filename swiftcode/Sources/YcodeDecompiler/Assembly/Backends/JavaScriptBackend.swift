import Foundation

public struct JavaScriptBackend: AssembleBackend {
    public var engine: any JSEngine

    public init(engine: any JSEngine = JavaScriptCoreEngine()) {
        self.engine = engine
    }

    public var id: String { "javascript" }
    public var displayName: String { "JavaScript (\(engine.displayName))" }
    public var kind: BackendKind { .runtimeEmbedded }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { ["js", "ts"] }

    public static let definitionPatterns: [String] = [
        #"function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(([^)]*)\)"#,
        #"(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*function\s*\(([^)]*)\)"#,
        #"(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*\(([^)]*)\)\s*=>"#,
    ]

    public static let scriptVariable = "sc_javascript_script"

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let clang = RuntimeShimSupport.locateClang(configuration: configuration) else {
            return .unavailable(
                reason: "No C compiler was found.",
                installGuidance: ClangBackend.installGuidance(format: configuration.format))
        }
        switch engine.availability(configuration: configuration) {
        case .available:
            return .available(toolPath: clang, version: BackendToolDiscovery.toolVersion(clang))
        case .unavailable(let reason, let guidance):
            return .unavailable(reason: reason, installGuidance: guidance)
        }
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        let sources = RuntimeShimSupport.scriptSources(projectRoot: projectRoot, extensions: sourceExtensions)
        for source in sources where source.pathExtension == "ts" {
            throw DecompilerError.invalidRequest("TypeScript file \(source.lastPathComponent) cannot be assembled by the JavaScript backend: JavaScriptCore parses JavaScript only. Transpile it to JavaScript first (for example with tsc) and assemble the .js output instead.")
        }
        for source in sources where source.pathExtension == "js" {
            let data = try Data(contentsOf: source)
            let bundleURL = RuntimeShimSupport.bundleURL(projectRoot: projectRoot, backendID: id, source: source)
            _ = try RuntimeShimSupport.writeDataIfChanged(data, to: bundleURL)
            let scriptText = String(decoding: data, as: UTF8.self)
            let exports = RuntimeShimSupport.exportedFunctions(script: scriptText, patterns: Self.definitionPatterns,
                                                               exportedSymbols: configuration.exportedSymbols)
            let shim = Self.shimSource(script: data, exports: exports, engine: engine)
            let shimURL = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
            if try RuntimeShimSupport.writeIfChanged(shim, to: shimURL) {
                RuntimeShimSupport.invalidateCachedObject(projectRoot: projectRoot, source: source)
            }
        }
    }

    public static func shimSource(script: Data, exports: [RuntimeShimSupport.ScriptFunction], engine: any JSEngine) -> String {
        var lines: [String] = []
        lines.append(contentsOf: engine.cIncludeLines)
        lines.append(RuntimeShimSupport.cByteArray(variableName: scriptVariable, data: script))
        lines.append(engine.contextDeclaration)
        lines.append("static int sc_js_started = 0;")
        lines.append("static int sc_js_start(void) {")
        lines.append("    if (sc_js_started) {")
        lines.append("        return 1;")
        lines.append("    }")
        lines.append("    int sc_js_ok = 1;")
        lines.append(engine.contextSetupCode())
        lines.append("    if (!sc_js_ok) {")
        lines.append(engine.contextTeardownCode())
        lines.append("        return 0;")
        lines.append("    }")
        lines.append(engine.exposeNativeCallback(functionName: "sc_native_log"))
        lines.append(engine.evaluateSource(scriptVariable: scriptVariable, lengthVariable: "\(scriptVariable)_len"))
        lines.append("    if (!sc_js_ok) {")
        lines.append(engine.contextTeardownCode())
        lines.append("        return 0;")
        lines.append("    }")
        lines.append("    sc_js_started = 1;")
        lines.append("    return 1;")
        lines.append("}")
        for fn in exports {
            lines.append(wrapperSource(function: fn, engine: engine))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func wrapperSource(function fn: RuntimeShimSupport.ScriptFunction, engine: any JSEngine) -> String {
        var lines: [String] = []
        lines.append("\(RuntimeShimSupport.wrapperSignature(name: fn.name, arity: fn.arity)) {")
        lines.append("    if (!sc_js_start()) {")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    long sc_result = -1;")
        lines.append(engine.callFunctionCode(functionName: fn.name, arity: fn.arity))
        lines.append("    return sc_result;")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let shim = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
        var args = configuration.compileArguments(source: shim, object: object, projectRoot: projectRoot, format: configuration.format)
        args.append(contentsOf: engine.compileFlags)
        args.append(contentsOf: configuration.perBackendFlags["javascript"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] {
        var args = ClangBackend().linkArguments(objects: objects, sources: sources, output: output, configuration: configuration)
        args.append(contentsOf: engine.linkFlags)
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        AssemblyDiagnosticParser.parseCompilerOutput(text, projectRoot: projectRoot)
    }

    public func postCompileDiagnostics(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        diagnostics.append(RuntimeShimSupport.bundledInfo(sources: sources))
        diagnostics.append(contentsOf: RuntimeShimSupport.missingExportWarnings(
            sources: sources, patterns: Self.definitionPatterns, exportedSymbols: configuration.exportedSymbols))
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "JavaScript functions are not native exports: the host calls the shim wrappers, which call the JavaScript functions through the \(engine.displayName) context. Node.js APIs are not available.",
            origin: .projectConfiguration))
        return diagnostics
    }
}
