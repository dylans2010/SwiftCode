import Foundation

public struct PythonBackend: AssembleBackend {
    public init() {}

    public var id: String { "python" }
    public var displayName: String { "Python (embedded CPython)" }
    public var kind: BackendKind { .runtimeEmbedded }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { ["py"] }

    public static let definitionPatterns: [String] = [
        #"(?m)^def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*:"#,
    ]

    public static let scriptVariable = "sc_python_script"

    public static func locatePythonConfig() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/bin/python3-config", "/usr/local/bin/python3-config",
                         "/opt/homebrew/bin/python3-config"],
            pathNames: ["python3-config", "python3.12-config", "python3.13-config", "python3.11-config"])
    }

    public static func locatePython() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"],
            pathNames: ["python3", "python3.12", "python3.13", "python3.11"])
    }

    public static func embedFlags(_ config: String, arguments: [String]) -> [String] {
        guard let result = RuntimeShimSupport.runTool(config, arguments: arguments),
              result.status == 0 else { return [] }
        return RuntimeShimSupport.splitFlags(result.stdoutText)
    }

    public static func pythonIncludeFlags() -> [String] {
        guard let config = locatePythonConfig() else { return [] }
        return embedFlags(config, arguments: ["--embed", "--includes"])
    }

    public static func pythonLinkFlags() -> [String] {
        guard let config = locatePythonConfig() else { return [] }
        return embedFlags(config, arguments: ["--embed", "--ldflags"])
    }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let clang = RuntimeShimSupport.locateClang(configuration: configuration) else {
            return .unavailable(
                reason: "No C compiler was found.",
                installGuidance: ClangBackend.installGuidance(format: configuration.format))
        }
        guard let config = Self.locatePythonConfig() else {
            return .unavailable(
                reason: "No python3-config tool was found.",
                installGuidance: "Install CPython development files (on Debian/Ubuntu: apt install python3-dev; on macOS: brew install python) and try again.")
        }
        let ldflags = Self.embedFlags(config, arguments: ["--embed", "--ldflags"])
        guard ldflags.contains(where: { $0.hasPrefix("-lpython") }) else {
            return .unavailable(
                reason: "python3-config --embed did not report a libpython link flag, so no Python runtime library is available to link.",
                installGuidance: "Install CPython development files (on Debian/Ubuntu: apt install python3-dev; on macOS: brew install python) and try again.")
        }
        guard let python = Self.locatePython(),
              let result = RuntimeShimSupport.runTool(python, arguments: ["-c", "import sysconfig; print(sysconfig.get_path('stdlib'))"]),
              result.status == 0 else {
            return .unavailable(
                reason: "The Python interpreter could not report its standard library location.",
                installGuidance: "Install a complete CPython (on Debian/Ubuntu: apt install python3 python3-dev; on macOS: brew install python) and try again.")
        }
        let stdlib = result.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stdlib.isEmpty, FileManager.default.fileExists(atPath: stdlib) else {
            return .unavailable(
                reason: "The Python standard library directory \(stdlib) does not exist.",
                installGuidance: "Install a complete CPython (on Debian/Ubuntu: apt install python3 python3-dev; on macOS: brew install python) and try again.")
        }
        return .available(toolPath: clang, version: BackendToolDiscovery.toolVersion(clang))
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        let sources = RuntimeShimSupport.scriptSources(projectRoot: projectRoot, extensions: sourceExtensions)
        for source in sources {
            let data = try Data(contentsOf: source)
            let bundleURL = RuntimeShimSupport.bundleURL(projectRoot: projectRoot, backendID: id, source: source)
            _ = try RuntimeShimSupport.writeDataIfChanged(data, to: bundleURL)
            let scriptText = String(decoding: data, as: UTF8.self)
            let exports = RuntimeShimSupport.exportedFunctions(script: scriptText, patterns: Self.definitionPatterns,
                                                               exportedSymbols: configuration.exportedSymbols)
            let shim = Self.shimSource(script: data, exports: exports)
            let shimURL = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
            if try RuntimeShimSupport.writeIfChanged(shim, to: shimURL) {
                RuntimeShimSupport.invalidateCachedObject(projectRoot: projectRoot, source: source)
            }
        }
    }

    public static func shimSource(script: Data, exports: [RuntimeShimSupport.ScriptFunction]) -> String {
        var lines: [String] = []
        lines.append("#define PY_SSIZE_T_CLEAN")
        lines.append("#include <Python.h>")
        lines.append(RuntimeShimSupport.cByteArray(variableName: scriptVariable, data: script))
        lines.append("static int sc_python_started = 0;")
        lines.append("static int sc_python_start(void) {")
        lines.append("    if (sc_python_started) {")
        lines.append("        return 1;")
        lines.append("    }")
        lines.append("    PyConfig sc_config;")
        lines.append("    PyConfig_InitPythonConfig(&sc_config);")
        lines.append("    PyStatus sc_status = Py_InitializeFromConfig(&sc_config);")
        lines.append("    PyConfig_Clear(&sc_config);")
        lines.append("    if (PyStatus_Exception(sc_status)) {")
        lines.append("        return 0;")
        lines.append("    }")
        lines.append("    PyObject *sc_code = Py_CompileString((const char *)\(scriptVariable), \"<bundled>\", Py_file_input);")
        lines.append("    if (sc_code == NULL) {")
        lines.append("        PyErr_Print();")
        lines.append("        return 0;")
        lines.append("    }")
        lines.append("    PyObject *sc_module = PyImport_AddModule(\"__main__\");")
        lines.append("    PyObject *sc_dict = sc_module ? PyModule_GetDict(sc_module) : NULL;")
        lines.append("    PyObject *sc_result = sc_dict ? PyEval_EvalCode(sc_code, sc_dict, sc_dict) : NULL;")
        lines.append("    Py_DECREF(sc_code);")
        lines.append("    if (sc_result == NULL) {")
        lines.append("        PyErr_Print();")
        lines.append("        return 0;")
        lines.append("    }")
        lines.append("    Py_DECREF(sc_result);")
        lines.append("    sc_python_started = 1;")
        lines.append("    return 1;")
        lines.append("}")
        for fn in exports {
            lines.append(wrapperSource(function: fn))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func wrapperSource(function fn: RuntimeShimSupport.ScriptFunction) -> String {
        var lines: [String] = []
        lines.append("\(RuntimeShimSupport.wrapperSignature(name: fn.name, arity: fn.arity)) {")
        lines.append("    if (!sc_python_start()) {")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    PyGILState_STATE sc_state = PyGILState_Ensure();")
        lines.append("    long sc_result = -1;")
        lines.append("    PyObject *sc_module = PyImport_AddModule(\"__main__\");")
        lines.append("    PyObject *sc_fn = sc_module ? PyObject_GetAttrString(sc_module, \"\(fn.name)\") : NULL;")
        lines.append("    if (sc_fn != NULL && PyCallable_Check(sc_fn)) {")
        if fn.arity > 0 {
            lines.append("        PyObject *sc_args = PyTuple_New(\(fn.arity));")
            for index in 0..<fn.arity {
                lines.append("        PyTuple_SetItem(sc_args, \(index), PyLong_FromLong(arg\(index)));")
            }
        } else {
            lines.append("        PyObject *sc_args = PyTuple_New(0);")
        }
        lines.append("        PyObject *sc_value = PyObject_CallObject(sc_fn, sc_args);")
        lines.append("        Py_DECREF(sc_args);")
        lines.append("        if (sc_value != NULL) {")
        lines.append("            sc_result = PyLong_AsLong(sc_value);")
        lines.append("            if (sc_result == -1 && PyErr_Occurred()) {")
        lines.append("                PyErr_Clear();")
        lines.append("                sc_result = -1;")
        lines.append("            }")
        lines.append("            Py_DECREF(sc_value);")
        lines.append("        } else {")
        lines.append("            PyErr_Print();")
        lines.append("        }")
        lines.append("    }")
        lines.append("    Py_XDECREF(sc_fn);")
        lines.append("    PyGILState_Release(sc_state);")
        lines.append("    return sc_result;")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let shim = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
        var args = configuration.compileArguments(source: shim, object: object, projectRoot: projectRoot, format: configuration.format)
        args.append(contentsOf: Self.pythonIncludeFlags())
        args.append(contentsOf: configuration.perBackendFlags["python"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] {
        var args = ClangBackend().linkArguments(objects: objects, sources: sources, output: output, configuration: configuration)
        args.append(contentsOf: Self.pythonLinkFlags())
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
            message: "The library needs libpython and the Python standard library at runtime. Wrappers pass integer arguments and return an integer; functions returning other types report -1. Every wrapper takes the GIL, so calls from host threads are serialized through the interpreter.",
            origin: .projectConfiguration))
        return diagnostics
    }
}
