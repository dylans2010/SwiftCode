import Foundation
#if canImport(CQuickJS)
import CQuickJS
#endif

public enum QuickJSEvalError: Error, Sendable {
    case runtimeUnavailable
    case contextUnavailable
    case evaluationFailed(String)
    case nonNumericResult
}

public struct QuickJSEngine: JSEngine {
    public init() {}

    public var id: String { "quickjs" }
    public var displayName: String { "QuickJS" }
    public var cIncludeLines: [String] {
        ["#include <stdio.h>", "#include <stdlib.h>", "#include <string.h>", "#include <quickjs.h>"]
    }
    public var contextDeclaration: String {
        """
        static JSRuntime *sc_qjs_runtime = NULL;
        static JSContext *sc_qjs_context = NULL;
        static JSValue sc_qjs_native_log(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
            (void)this_val;
            if (argc > 0) {
                const char *sc_text = JS_ToCString(ctx, argv[0]);
                if (sc_text != NULL) {
                    fprintf(stderr, "%s\\n", sc_text);
                    JS_FreeCString(ctx, sc_text);
                }
            }
            return JS_UNDEFINED;
        }
        """
    }
    public var compileFlags: [String] { [] }
    public var linkFlags: [String] { [] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
#if canImport(CQuickJS)
        return .available(toolPath: "CQuickJS", version: "QuickJS-NG")
#else
        return .unavailable(
            reason: "The vendored QuickJS runtime is not linked into this build.",
            installGuidance: "Rebuild SwiftCode with the CQuickJS target included. JavaScriptCore remains the default JavaScript engine on macOS.")
#endif
    }

    public func contextSetupCode() -> String {
        """
            if (sc_qjs_runtime == NULL) {
                sc_qjs_runtime = JS_NewRuntime();
            }
            if (sc_qjs_runtime == NULL) {
                sc_js_ok = 0;
            }
            if (sc_js_ok && sc_qjs_context == NULL) {
                sc_qjs_context = JS_NewContext(sc_qjs_runtime);
            }
            if (sc_qjs_context == NULL) {
                sc_js_ok = 0;
            }
        """
    }

    public func evaluateSource(scriptVariable: String, lengthVariable: String) -> String {
        """
            {
                JSValue sc_qjs_value = JS_Eval(sc_qjs_context, (const char *)\(scriptVariable), \(lengthVariable), "<anonymous>", JS_EVAL_TYPE_GLOBAL);
                if (JS_IsException(sc_qjs_value)) {
                    JSValue sc_qjs_exception = JS_GetException(sc_qjs_context);
                    const char *sc_qjs_text = JS_ToCString(sc_qjs_context, sc_qjs_exception);
                    if (sc_qjs_text != NULL) {
                        fprintf(stderr, "QuickJS error: %s\\n", sc_qjs_text);
                        JS_FreeCString(sc_qjs_context, sc_qjs_text);
                    }
                    JS_FreeValue(sc_qjs_context, sc_qjs_exception);
                    sc_js_ok = 0;
                }
                JS_FreeValue(sc_qjs_context, sc_qjs_value);
            }
        """
    }

    public func exposeNativeCallback(functionName: String) -> String {
        """
            {
                JSValue sc_qjs_global = JS_GetGlobalObject(sc_qjs_context);
                JSValue sc_qjs_callback = JS_NewCFunction(sc_qjs_context, sc_qjs_native_log, "\(functionName)", 1);
                JS_SetPropertyStr(sc_qjs_context, sc_qjs_global, "\(functionName)", sc_qjs_callback);
                JS_FreeValue(sc_qjs_context, sc_qjs_global);
            }
        """
    }

    public func callFunctionCode(functionName: String, arity: Int) -> String {
        var lines: [String] = []
        lines.append("    {")
        lines.append("        JSValue sc_global = JS_GetGlobalObject(sc_qjs_context);")
        lines.append("        JSValue sc_value = JS_GetPropertyStr(sc_qjs_context, sc_global, \"\(functionName)\");")
        lines.append("        if (JS_IsFunction(sc_qjs_context, sc_value)) {")
        if arity > 0 {
            lines.append("            JSValue sc_args[\(arity)];")
            for index in 0..<arity {
                lines.append("            sc_args[\(index)] = JS_NewFloat64(sc_qjs_context, (double)arg\(index));")
            }
            lines.append("            JSValue sc_call_result = JS_Call(sc_qjs_context, sc_value, sc_global, \(arity), sc_args);")
        } else {
            lines.append("            JSValue sc_call_result = JS_Call(sc_qjs_context, sc_value, sc_global, 0, NULL);")
        }
        lines.append("            if (JS_IsException(sc_call_result)) {")
        lines.append("                JSValue sc_call_exception = JS_GetException(sc_qjs_context);")
        lines.append("                const char *sc_call_text = JS_ToCString(sc_qjs_context, sc_call_exception);")
        lines.append("                if (sc_call_text != NULL) {")
        lines.append("                    fprintf(stderr, \"QuickJS error: %s\\n\", sc_call_text);")
        lines.append("                    JS_FreeCString(sc_qjs_context, sc_call_text);")
        lines.append("                }")
        lines.append("                JS_FreeValue(sc_qjs_context, sc_call_exception);")
        lines.append("            } else {")
        lines.append("                double sc_num = 0;")
        lines.append("                if (JS_ToFloat64(sc_qjs_context, &sc_num, sc_call_result) == 0) {")
        lines.append("                    sc_result = (long)sc_num;")
        lines.append("                }")
        lines.append("                JS_FreeValue(sc_qjs_context, sc_call_result);")
        lines.append("            }")
        if arity > 0 {
            for index in 0..<arity {
                lines.append("            JS_FreeValue(sc_qjs_context, sc_args[\(index)]);")
            }
        }
        lines.append("        }")
        lines.append("        JS_FreeValue(sc_qjs_context, sc_value);")
        lines.append("        JS_FreeValue(sc_qjs_context, sc_global);")
        lines.append("    }")
        return lines.joined(separator: "\n")
    }

    public func contextTeardownCode() -> String {
        """
            if (sc_qjs_context != NULL) {
                JS_FreeContext(sc_qjs_context);
                sc_qjs_context = NULL;
            }
            if (sc_qjs_runtime != NULL) {
                JS_FreeRuntime(sc_qjs_runtime);
                sc_qjs_runtime = NULL;
            }
        """
    }

#if canImport(CQuickJS)
    public func evaluate(source: String) throws -> Double {
        guard let runtime = JS_NewRuntime() else { throw QuickJSEvalError.runtimeUnavailable }
        defer { JS_FreeRuntime(runtime) }
        guard let context = JS_NewContext(runtime) else { throw QuickJSEvalError.contextUnavailable }
        defer { JS_FreeContext(context) }
        let result = source.withCString { cString in
            JS_Eval(context, cString, source.utf8.count, "<eval>", JS_EVAL_TYPE_GLOBAL)
        }
        defer { JS_FreeValue(context, result) }
        if JS_IsException(result) {
            let exception = JS_GetException(context)
            defer { JS_FreeValue(context, exception) }
            guard let text = JS_ToCString(context, exception) else {
                throw QuickJSEvalError.evaluationFailed("unknown error")
            }
            defer { JS_FreeCString(context, text) }
            throw QuickJSEvalError.evaluationFailed(String(cString: text))
        }
        var number: Double = 0
        guard JS_ToFloat64(context, &number, result) == 0 else {
            throw QuickJSEvalError.nonNumericResult
        }
        guard !number.isNaN else {
            throw QuickJSEvalError.nonNumericResult
        }
        return number
    }
#endif
}

public struct QuickJSBackend: AssembleBackend {
    public static let vendoredFileNames: [String] = [
        "quickjs.c", "libregexp.c", "libunicode.c", "dtoa.c",
        "quickjs.h", "cutils.h", "list.h", "libregexp.h", "libregexp-opcode.h",
        "libunicode.h", "libunicode-table.h", "dtoa.h", "quickjs-atom.h",
        "quickjs-opcode.h", "quickjs-c-atomics.h", "builtin-array-fromasync.h",
        "builtin-iterator-zip-keyed.h", "builtin-iterator-zip.h",
    ]

    public static let sourcesEnvironmentVariable = "SWIFTCODE_QUICKJS_SOURCES"

    public init() {}

    public var id: String { "javascript-quickjs" }
    public var displayName: String { "JavaScript (QuickJS)" }
    public var kind: BackendKind { .runtimeEmbedded }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { [] }

    public static func vendoredSourcesDirectory() -> URL? {
        if let resourceURL = Bundle.module.resourceURL?.appendingPathComponent("QuickJS", isDirectory: true),
           FileManager.default.fileExists(atPath: resourceURL.appendingPathComponent("quickjs.c").path) {
            return resourceURL
        }
        if let override = ProcessInfo.processInfo.environment[sourcesEnvironmentVariable], !override.isEmpty {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("quickjs.c").path) {
                return url
            }
        }
        return nil
    }

    public static func vendoredSourcesDirectory(in projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent("Assembly/QuickJS", isDirectory: true)
    }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let clang = RuntimeShimSupport.locateClang(configuration: configuration) else {
            return .unavailable(
                reason: "No C compiler was found.",
                installGuidance: ClangBackend.installGuidance(format: configuration.format))
        }
        guard Self.vendoredSourcesDirectory() != nil else {
            return .unavailable(
                reason: "The vendored QuickJS sources are not available in this build.",
                installGuidance: "Rebuild SwiftCode with the CQuickJS target and its bundled QuickJS sources; JavaScriptCore remains the default JavaScript engine on macOS.")
        }
        return .available(toolPath: clang, version: BackendToolDiscovery.toolVersion(clang))
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        try JavaScriptBackend(engine: QuickJSEngine()).prepareProject(projectRoot: projectRoot, configuration: configuration)
        guard let sourcesDir = Self.vendoredSourcesDirectory() else {
            throw DecompilerError.invalidRequest("The vendored QuickJS sources are not available in this build, so the QuickJS backend cannot assemble JavaScript. JavaScriptCore remains the default JavaScript engine on macOS.")
        }
        let targetDir = Self.vendoredSourcesDirectory(in: projectRoot)
        for fileName in Self.vendoredFileNames {
            let sourceURL = sourcesDir.appendingPathComponent(fileName)
            let targetURL = targetDir.appendingPathComponent(fileName)
            let data = try Data(contentsOf: sourceURL)
            if try RuntimeShimSupport.writeDataIfChanged(data, to: targetURL) {
                RuntimeShimSupport.invalidateCachedObject(projectRoot: projectRoot, source: targetURL)
            }
        }
        try ensureVendoredObjectsCompiled(projectRoot: projectRoot, configuration: configuration)
    }

    func ensureVendoredObjectsCompiled(projectRoot: URL, configuration: BuildConfiguration) throws {
        guard let clang = RuntimeShimSupport.locateClang(configuration: configuration) else {
            throw DecompilerError.engineUnavailable("No C compiler was found to build the vendored QuickJS sources. \(ClangBackend.installGuidance(format: configuration.format))")
        }
        let targetDir = Self.vendoredSourcesDirectory(in: projectRoot)
        let objectsDir = projectRoot.appendingPathComponent("Build/Objects", isDirectory: true)
        try FileManager.default.createDirectory(at: objectsDir, withIntermediateDirectories: true)
        let includeDir = targetDir.path
        for fileName in ["quickjs.c", "libregexp.c", "libunicode.c", "dtoa.c"] {
            let sourceURL = targetDir.appendingPathComponent(fileName)
            let objectURL = objectsDir.appendingPathComponent("Assembly_QuickJS_\(fileName).o")
            if Self.isObjectCurrent(sourceURL: sourceURL, objectURL: objectURL) { continue }
            var args = ClangBackend().compileArguments(source: sourceURL, object: objectURL,
                                                       projectRoot: projectRoot, configuration: configuration)
            args.append("-I\(includeDir)")
            let output = try ProcessRunnerRegistry.shared.run(
                executable: clang, arguments: args, environment: nil, currentDirectory: nil)
            if output.status != 0 {
                throw DecompilerError.invalidRequest("Compiling the vendored QuickJS source \(fileName) failed: \(output.stderrText)\(output.stdoutText)")
            }
        }
    }

    static func isObjectCurrent(sourceURL: URL, objectURL: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: objectURL.path),
              let sourceDate = (try? fm.attributesOfItem(atPath: sourceURL.path)[.modificationDate]) as? Date,
              let objectDate = (try? fm.attributesOfItem(atPath: objectURL.path)[.modificationDate]) as? Date else {
            return false
        }
        return objectDate >= sourceDate
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL,
                                 configuration: BuildConfiguration) -> [String] {
        let includeDir = Self.vendoredSourcesDirectory(in: projectRoot).path
        if source.pathExtension == "js" {
            var args = JavaScriptBackend(engine: QuickJSEngine()).compileArguments(
                source: source, object: object, projectRoot: projectRoot, configuration: configuration)
            args.append("-I\(includeDir)")
            args.append(contentsOf: configuration.perBackendFlags["javascript-quickjs"] ?? [])
            return args
        }
        var args = ClangBackend().compileArguments(source: source, object: object,
                                                   projectRoot: projectRoot, configuration: configuration)
        args.append("-I\(includeDir)")
        args.append(contentsOf: configuration.perBackendFlags["javascript-quickjs"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL,
                              configuration: BuildConfiguration) -> [String] {
        let objectsDir = objects.first?.deletingLastPathComponent()
            ?? output.deletingLastPathComponent().appendingPathComponent("Objects", isDirectory: true)
        let extraObjects = ["quickjs.c", "libregexp.c", "libunicode.c", "dtoa.c"]
            .map { objectsDir.appendingPathComponent("Assembly_QuickJS_\($0).o") }
            .filter { !objects.contains($0) }
        var args = ClangBackend().linkArguments(objects: objects + extraObjects, sources: sources, output: output,
                                                configuration: configuration)
        args.append(contentsOf: configuration.perBackendFlags["javascript-quickjs"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        AssemblyDiagnosticParser.parseCompilerOutput(text, projectRoot: projectRoot)
    }

    public func postCompileDiagnostics(sources: [URL], projectRoot: URL,
                                       configuration: BuildConfiguration) -> [AssemblyDiagnostic] {
        var diagnostics = JavaScriptBackend(engine: QuickJSEngine()).postCompileDiagnostics(
            sources: sources, projectRoot: projectRoot, configuration: configuration)
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "JavaScript runs on the vendored QuickJS engine (no JIT). The QuickJS C sources were compiled into the library from the bundled QuickJS-NG sources.",
            origin: .projectConfiguration))
        return diagnostics
    }
}
