import Foundation

public struct JavaJVMBackend: AssembleBackend {
    public init() {}

    public var id: String { "java-jvm" }
    public var displayName: String { "Java (embedded JVM)" }
    public var kind: BackendKind { .runtimeEmbedded }
    public var buildMode: BackendBuildMode { .object }
    public var sourceExtensions: Set<String> { [] }

    public static let definitionPatterns: [String] = [
        #"(?:public\s+)?static\s+long\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)"#,
    ]

    public static func locateJavaHome() -> String? {
        let fm = FileManager.default
        if let envHome = ProcessInfo.processInfo.environment["JAVA_HOME"], !envHome.isEmpty,
           fm.fileExists(atPath: (envHome as NSString).appendingPathComponent("include/jni.h")) {
            return envHome
        }
#if os(macOS)
        let javaHomeTool = "/usr/libexec/java_home"
        if fm.isExecutableFile(atPath: javaHomeTool),
           let result = RuntimeShimSupport.runTool(javaHomeTool, arguments: []),
           result.status == 0 {
            let home = result.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !home.isEmpty, fm.fileExists(atPath: (home as NSString).appendingPathComponent("include/jni.h")) {
                return home
            }
        }
        let jvmDir = "/Library/Java/JavaVirtualMachines"
        if let names = try? fm.contentsOfDirectory(atPath: jvmDir) {
            for name in names.sorted() {
                let home = "\(jvmDir)/\(name)/Contents/Home"
                if fm.fileExists(atPath: (home as NSString).appendingPathComponent("include/jni.h")) {
                    return home
                }
            }
        }
#else
        let jvmDir = "/usr/lib/jvm"
        if let names = try? fm.contentsOfDirectory(atPath: jvmDir) {
            for name in names.sorted() {
                let home = "\(jvmDir)/\(name)"
                if fm.fileExists(atPath: (home as NSString).appendingPathComponent("include/jni.h")) {
                    return home
                }
            }
        }
#endif
        if let java = BackendToolDiscovery.locateOnPATH(["java"]) {
            var path = java
            for _ in 0..<8 {
                guard let target = try? fm.destinationOfSymbolicLink(atPath: path) else { break }
                let dir = (path as NSString).deletingLastPathComponent
                path = ((dir as NSString).appendingPathComponent(target) as NSString).standardizingPath
            }
            let home = URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent().path
            if fm.fileExists(atPath: (home as NSString).appendingPathComponent("include/jni.h")) {
                return home
            }
        }
        return nil
    }

    public static func locateJavac(javaHome: String? = nil) -> String? {
        if let javaHome {
            let sibling = (javaHome as NSString).appendingPathComponent("bin/javac")
            if FileManager.default.isExecutableFile(atPath: sibling) { return sibling }
        }
        return BackendToolDiscovery.locateOnPATH(["javac"])
    }

    public static func includeFlags(javaHome: String) -> [String] {
        var flags = ["-I\(javaHome)/include"]
#if os(macOS)
        flags.append("-I\(javaHome)/include/darwin")
#else
        flags.append("-I\(javaHome)/include/linux")
#endif
        return flags
    }

    public static func linkFlags(javaHome: String) -> [String] {
#if os(macOS)
        return ["-L\(javaHome)/lib/jli", "-ljli", "-L\(javaHome)/lib/server", "-ljvm",
                "-Wl,-rpath,\(javaHome)/lib/server"]
#else
        return ["-L\(javaHome)/lib/server", "-ljvm",
                "-Wl,-rpath,\(javaHome)/lib/server"]
#endif
    }

    public static func jniClassName(in source: String, fallback: String) -> String {
        var package = ""
        if let regex = try? NSRegularExpression(pattern: #"(?m)^package\s+([A-Za-z_][A-Za-z0-9_.]*)\s*;"#),
           let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           match.numberOfRanges >= 2, let range = Range(match.range(at: 1), in: source) {
            package = String(source[range]).replacingOccurrences(of: ".", with: "/") + "/"
        }
        var className = fallback
        if let regex = try? NSRegularExpression(pattern: #"(?:public\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)"#),
           let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
           match.numberOfRanges >= 2, let range = Range(match.range(at: 1), in: source) {
            className = String(source[range])
        }
        return package + className
    }

    public static func jniSignature(arity: Int) -> String {
        "(" + String(repeating: "J", count: arity) + ")J"
    }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let clang = RuntimeShimSupport.locateClang(configuration: configuration) else {
            return .unavailable(
                reason: "No C compiler was found.",
                installGuidance: ClangBackend.installGuidance(format: configuration.format))
        }
        guard let home = Self.locateJavaHome() else {
            return .unavailable(
                reason: "No JDK was found.",
                installGuidance: "Install a JDK (on macOS: brew install openjdk, or download from https://adoptium.net; on Debian/Ubuntu: apt install default-jdk) and make sure JAVA_HOME points at it, then try again.")
        }
        guard Self.locateJavac(javaHome: home) != nil else {
            return .unavailable(
                reason: "A JDK was found at \(home), but no javac sits beside it.",
                installGuidance: "Install a full JDK (not a JRE) so javac is present in <home>/bin, and try again.")
        }
        return .available(toolPath: clang, version: BackendToolDiscovery.toolVersion(clang))
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        guard let home = Self.locateJavaHome() else {
            throw DecompilerError.engineUnavailable("No JDK was found. Install a JDK and make sure JAVA_HOME points at it, then try again.")
        }
        guard let javac = Self.locateJavac(javaHome: home) else {
            throw DecompilerError.engineUnavailable("No javac was found in the JDK at \(home). Install a full JDK (not a JRE) and try again.")
        }
        let sources = RuntimeShimSupport.scriptSources(projectRoot: projectRoot, extensions: ["java"])
        let classesDir = projectRoot.appendingPathComponent("Build/JavaJVM/classes", isDirectory: true)
        try FileManager.default.createDirectory(at: classesDir, withIntermediateDirectories: true)
        if !sources.isEmpty {
            let result = try ProcessRunnerRegistry.shared.run(
                executable: javac, arguments: ["-d", classesDir.path] + sources.map(\.path),
                environment: nil, currentDirectory: nil)
            if result.status != 0 {
                throw DecompilerError.invalidRequest("javac failed with status \(result.status): \((result.stderrText + "\n" + result.stdoutText).trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        for source in sources {
            guard let text = try? String(contentsOf: source, encoding: .utf8) else { continue }
            let className = Self.jniClassName(in: text, fallback: source.deletingPathExtension().lastPathComponent)
            let exports = RuntimeShimSupport.exportedFunctions(script: text, patterns: Self.definitionPatterns,
                                                               exportedSymbols: configuration.exportedSymbols)
            let shim = Self.shimSource(className: className, classesDirectory: classesDir, exports: exports)
            let shimURL = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
            if try RuntimeShimSupport.writeIfChanged(shim, to: shimURL) {
                RuntimeShimSupport.invalidateCachedObject(projectRoot: projectRoot, source: source)
            }
        }
    }

    public static func shimSource(className: String, classesDirectory: URL, exports: [RuntimeShimSupport.ScriptFunction]) -> String {
        var lines: [String] = []
        lines.append("#include <jni.h>")
        lines.append("#include <stdio.h>")
        lines.append("static JavaVM *sc_jvm = NULL;")
        lines.append("static JNIEnv *sc_java_env(void) {")
        lines.append("    if (sc_jvm != NULL) {")
        lines.append("        JNIEnv *sc_env = NULL;")
        lines.append("        if ((*sc_jvm)->AttachCurrentThread(sc_jvm, (void **)&sc_env, NULL) == JNI_OK) {")
        lines.append("            return sc_env;")
        lines.append("        }")
        lines.append("        return NULL;")
        lines.append("    }")
        lines.append("    JavaVMInitArgs sc_args;")
        lines.append("    JavaVMOption sc_options[1];")
        let classPathOption = "-Djava.class.path=" + classesDirectory.path
        lines.append("    sc_options[0].optionString = \(RuntimeShimSupport.cStringLiteral(classPathOption));")
        lines.append("    sc_args.version = JNI_VERSION_1_8;")
        lines.append("    sc_args.nOptions = 1;")
        lines.append("    sc_args.options = sc_options;")
        lines.append("    sc_args.ignoreUnrecognized = JNI_TRUE;")
        lines.append("    JNIEnv *sc_env = NULL;")
        lines.append("    if (JNI_CreateJavaVM(&sc_jvm, (void **)&sc_env, &sc_args) != JNI_OK) {")
        lines.append("        sc_jvm = NULL;")
        lines.append("        return NULL;")
        lines.append("    }")
        lines.append("    return sc_env;")
        lines.append("}")
        for fn in exports {
            lines.append(wrapperSource(className: className, function: fn))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func wrapperSource(className: String, function fn: RuntimeShimSupport.ScriptFunction) -> String {
        var lines: [String] = []
        lines.append("\(RuntimeShimSupport.wrapperSignature(name: fn.name, arity: fn.arity)) {")
        lines.append("    JNIEnv *sc_env = sc_java_env();")
        lines.append("    if (sc_env == NULL) {")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    jclass sc_class = (*sc_env)->FindClass(sc_env, \"\(className)\");")
        lines.append("    if (sc_class == NULL) {")
        lines.append("        (*sc_env)->ExceptionClear(sc_env);")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    jmethodID sc_method = (*sc_env)->GetStaticMethodID(sc_env, sc_class, \"\(fn.name)\", \"\(jniSignature(arity: fn.arity))\");")
        lines.append("    if (sc_method == NULL) {")
        lines.append("        (*sc_env)->ExceptionClear(sc_env);")
        lines.append("        return -1;")
        lines.append("    }")
        let args = (0..<fn.arity).map { "(jlong)arg\($0)" }.joined(separator: ", ")
        if fn.arity > 0 {
            lines.append("    jlong sc_result = (*sc_env)->CallStaticLongMethod(sc_env, sc_class, sc_method, \(args));")
        } else {
            lines.append("    jlong sc_result = (*sc_env)->CallStaticLongMethod(sc_env, sc_class, sc_method);")
        }
        lines.append("    if ((*sc_env)->ExceptionCheck(sc_env)) {")
        lines.append("        (*sc_env)->ExceptionClear(sc_env);")
        lines.append("        return -1;")
        lines.append("    }")
        lines.append("    return (long)sc_result;")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let shim = RuntimeShimSupport.shimURL(projectRoot: projectRoot, backendID: id, source: source)
        var args = configuration.compileArguments(source: shim, object: object, projectRoot: projectRoot, format: configuration.format)
        if let home = Self.locateJavaHome() { args.append(contentsOf: Self.includeFlags(javaHome: home)) }
        args.append(contentsOf: configuration.perBackendFlags["java-jvm"] ?? [])
        return args
    }

    public func linkArguments(objects: [URL], sources: [URL], output: URL, configuration: BuildConfiguration) -> [String] {
        var args = ClangBackend().linkArguments(objects: objects, sources: sources, output: output, configuration: configuration)
        if let home = Self.locateJavaHome() { args.append(contentsOf: Self.linkFlags(javaHome: home)) }
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        AssemblyDiagnosticParser.parseCompilerOutput(text, projectRoot: projectRoot)
    }

    public func postCompileDiagnostics(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "The Java sources were compiled to bytecode by javac into Build/JavaJVM/classes; the library embeds a JVM and loads the classes from that directory at runtime, so the classes directory must stay in place. Java stays bytecode and is not compiled to native code.",
            origin: .projectConfiguration))
        diagnostics.append(contentsOf: RuntimeShimSupport.missingExportWarnings(
            sources: sources, patterns: Self.definitionPatterns, exportedSymbols: configuration.exportedSymbols))
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "One JVM can exist per process: a second Java library loaded into the same host process reuses the first JVM, and the JVM cannot be unloaded. Only public static methods returning long with long parameters are callable through the wrappers.",
            origin: .projectConfiguration))
        return diagnostics
    }
}
