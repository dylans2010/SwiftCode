import Foundation

public struct LuaBackend: AssembleBackend {
    public init() {}

    public var id: String { "lua" }
    public var displayName: String { "Lua (embedded)" }
    public var kind: BackendKind { .runtimeEmbedded }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { ["lua"] }

    public static let definitionPatterns: [String] = [
        #"function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)"#,
        #"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(([^)]*)\)"#,
    ]

    public static let scriptVariable = "sc_lua_script"

    public static func locatePkgConfig() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/bin/pkg-config", "/usr/local/bin/pkg-config", "/opt/homebrew/bin/pkg-config"],
            pathNames: ["pkg-config"])
    }

    public static func pkgConfigFlags() -> (cflags: [String], libs: [String])? {
        guard let pkgConfig = locatePkgConfig() else { return nil }
        for name in ["lua5.4", "lua-5.4", "lua"] {
            guard let result = RuntimeShimSupport.runTool(pkgConfig, arguments: ["--cflags", "--libs", name]),
                  result.status == 0 else { continue }
            let tokens = RuntimeShimSupport.splitFlags(result.stdoutText)
            guard !tokens.isEmpty else { continue }
            var cflags: [String] = []
            var libs: [String] = []
            for token in tokens {
                if token.hasPrefix("-I") || token.hasPrefix("-D") {
                    cflags.append(token)
                } else {
                    libs.append(token)
                }
            }
            return (cflags, libs)
        }
        return nil
    }

    public static func fixedLuaPaths() -> (cflags: [String], libs: [String])? {
        let fm = FileManager.default
        let includeDirs = ["/opt/homebrew/include", "/usr/local/include", "/usr/include/lua5.4", "/usr/include"]
        var includeDir: String?
        for dir in includeDirs where fm.fileExists(atPath: (dir as NSString).appendingPathComponent("lua.h")) {
            includeDir = dir
            break
        }
        guard let includeDir else { return nil }
        var libs = ["-llua"]
        for libDir in ["/opt/homebrew/lib", "/usr/local/lib"] where fm.fileExists(atPath: libDir) {
            libs.insert("-L\(libDir)", at: 0)
        }
        return (["-I\(includeDir)"], libs)
    }

    public static func luaFlags() -> (cflags: [String], libs: [String])? {
        pkgConfigFlags() ?? fixedLuaPaths()
    }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let clang = RuntimeShimSupport.locateClang(configuration: configuration) else {
            return .unavailable(
                reason: "No C compiler was found.",
                installGuidance: ClangBackend.installGuidance(format: configuration.format))
        }
        guard Self.luaFlags() != nil else {
            return .unavailable(
                reason: "No Lua 5.4 development files were found (no lua.h and no linkable liblua).",
                installGuidance: "Install Lua 5.4 development files (on Debian/Ubuntu: apt install liblua5.4-dev; on macOS: brew install lua) and try again.")
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
        lines.append("#include <stdio.h>")
        lines.append("#include <lua.h>")
        lines.append("#include <lauxlib.h>")
        lines.append("#include <lualib.h>")
        lines.append(RuntimeShimSupport.cByteArray(variableName: scriptVariable, data: script))
        lines.append("static lua_State *sc_lua_state = NULL;")
        lines.append("static int sc_lua_start(void) {")
        lines.append("    if (sc_lua_state != NULL) {")
        lines.append("        return 1;")
        lines.append("    }")
        lines.append("    sc_lua_state = luaL_newstate();")
        lines.append("    if (sc_lua_state == NULL) {")
        lines.append("        return 0;")
        lines.append("    }")
        lines.append("    luaL_openlibs(sc_lua_state);")
        lines.append("    if (luaL_loadbuffer(sc_lua_state, (const char *)\(scriptVariable), \(scriptVariable)_len, \"bundled\") != LUA_OK) {")
        lines.append("        fprintf(stderr, \"%s\\n\", lua_tostring(sc_lua_state, -1));")
        lines.append("        lua_close(sc_lua_state);")
        lines.append("        sc_lua_state = NULL;")
        lines.append("        return 0;")
        lines.append("    }")
        lines.append("    if (lua_pcall(sc_lua_state, 0, 0, 0) != LUA_OK) {")
        lines.append("        fprintf(stderr, \"%s\\n\", lua_tostring(sc_lua_state, -1));")
        lines.append("        lua_close(sc_lua_state);")
        lines.append("        sc_lua_state = NULL;")
        lines.append("        return 0;")
        lines.append("    }")
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
        lines.append("    if (!sc_lua_start()) {")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    lua_getglobal(sc_lua_state, \"\(fn.name)\");")
        for index in 0..<fn.arity {
            lines.append("    lua_pushnumber(sc_lua_state, (lua_Number)arg\(index));")
        }
        lines.append("    if (lua_pcall(sc_lua_state, \(fn.arity), 1, 0) != LUA_OK) {")
        lines.append("        lua_pop(sc_lua_state, 1);")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    long sc_result = (long)lua_tonumber(sc_lua_state, -1);")
        lines.append("    lua_pop(sc_lua_state, 1);")
        lines.append("    return sc_result;")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let shim = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
        var args = configuration.compileArguments(source: shim, object: object, projectRoot: projectRoot, format: configuration.format)
        if let flags = Self.luaFlags() { args.append(contentsOf: flags.cflags) }
        args.append(contentsOf: configuration.perBackendFlags["lua"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] {
        var args = ClangBackend().linkArguments(objects: objects, sources: sources, output: output, configuration: configuration)
        if let flags = Self.luaFlags() { args.append(contentsOf: flags.libs) }
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
            message: "The Lua source stays text inside the library; there is no native compilation step. The lua_State is not thread-safe, so exports must not be called concurrently from multiple host threads, and wrappers pass integer arguments and return an integer.",
            origin: .projectConfiguration))
        return diagnostics
    }
}
