import Foundation

public protocol JSEngine: Sendable {
    var id: String { get }
    var displayName: String { get }
    var cIncludeLines: [String] { get }
    var contextDeclaration: String { get }
    var compileFlags: [String] { get }
    var linkFlags: [String] { get }
    func availability(configuration: BuildConfiguration) -> BackendAvailability
    func contextSetupCode() -> String
    func evaluateSource(scriptVariable: String, lengthVariable: String) -> String
    func exposeNativeCallback(functionName: String) -> String
    func callFunctionCode(functionName: String, arity: Int) -> String
    func contextTeardownCode() -> String
}

public struct JavaScriptCoreEngine: JSEngine {
    public init() {}

    public var id: String { "javascriptcore" }
    public var displayName: String { "JavaScriptCore" }
    public var cIncludeLines: [String] {
        ["#include <stdio.h>", "#include <stdlib.h>", "#include <JavaScriptCore/JavaScriptCore.h>"]
    }
    public var contextDeclaration: String {
        """
        static JSGlobalContextRef sc_js_context = NULL;
        static JSValueRef sc_js_native_log(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception) {
            if (argumentCount > 0) {
                JSStringRef sc_text = JSValueToStringCopy(ctx, arguments[0], NULL);
                if (sc_text != NULL) {
                    size_t sc_size = JSStringGetMaximumUTF8CStringSize(sc_text);
                    char *sc_buffer = (char *)malloc(sc_size);
                    if (sc_buffer != NULL) {
                        JSStringGetUTF8CString(sc_text, sc_buffer, sc_size);
                        fprintf(stderr, "%s\\n", sc_buffer);
                        free(sc_buffer);
                    }
                    JSStringRelease(sc_text);
                }
            }
            return JSValueMakeUndefined(ctx);
        }
        """
    }
    public var compileFlags: [String] { [] }
    public var linkFlags: [String] { ["-framework", "JavaScriptCore"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
#if os(macOS)
        let framework = "/System/Library/Frameworks/JavaScriptCore.framework"
        if FileManager.default.fileExists(atPath: framework) {
            return .available(toolPath: framework, version: nil)
        }
        return .unavailable(
            reason: "The JavaScriptCore framework was not found.",
            installGuidance: "JavaScriptCore ships with macOS; install the Xcode Command Line Tools (xcode-select --install) and try again.")
#else
        return .unavailable(
            reason: "JavaScriptCore is a macOS system framework and is not available on this platform.",
            installGuidance: "Build on macOS, or use a JavaScript engine with a Linux build such as QuickJS.")
#endif
    }

    public func contextSetupCode() -> String {
        """
            if (sc_js_context == NULL) {
                sc_js_context = JSGlobalContextCreate(NULL);
            }
            if (sc_js_context == NULL) {
                sc_js_ok = 0;
            }
        """
    }

    public func evaluateSource(scriptVariable: String, lengthVariable: String) -> String {
        """
            {
                JSStringRef sc_js_source = JSStringCreateWithUTF8CString((const char *)\(scriptVariable));
                JSValueRef sc_js_exception = NULL;
                JSEvaluateScript(sc_js_context, sc_js_source, NULL, NULL, 0, &sc_js_exception);
                JSStringRelease(sc_js_source);
                if (sc_js_exception != NULL) {
                    sc_js_ok = 0;
                }
            }
        """
    }

    public func exposeNativeCallback(functionName: String) -> String {
        """
            {
                JSObjectRef sc_js_global = JSContextGetGlobalObject(sc_js_context);
                JSStringRef sc_js_callback_name = JSStringCreateWithUTF8CString("\(functionName)");
                JSObjectRef sc_js_callback = JSObjectMakeFunctionWithCallback(sc_js_context, NULL, sc_js_native_log);
                JSObjectSetProperty(sc_js_context, sc_js_global, sc_js_callback_name, sc_js_callback, kJSPropertyAttributeNone, NULL);
                JSStringRelease(sc_js_callback_name);
            }
        """
    }

    public func callFunctionCode(functionName: String, arity: Int) -> String {
        var lines: [String] = []
        lines.append("    {")
        lines.append("        JSObjectRef sc_global = JSContextGetGlobalObject(sc_js_context);")
        lines.append("        JSStringRef sc_name = JSStringCreateWithUTF8CString(\"\(functionName)\");")
        lines.append("        JSValueRef sc_value = JSObjectGetProperty(sc_js_context, sc_global, sc_name, NULL);")
        lines.append("        JSStringRelease(sc_name);")
        lines.append("        JSObjectRef sc_function = JSValueToObject(sc_js_context, sc_value, NULL);")
        lines.append("        if (sc_function != NULL) {")
        if arity > 0 {
            lines.append("            JSValueRef sc_args[\(arity)];")
            for index in 0..<arity {
                lines.append("            sc_args[\(index)] = JSValueMakeNumber(sc_js_context, (double)arg\(index));")
            }
            lines.append("            JSValueRef sc_exception = NULL;")
            lines.append("            JSValueRef sc_call_result = JSObjectCallAsFunction(sc_js_context, sc_function, sc_global, \(arity), sc_args, &sc_exception);")
        } else {
            lines.append("            JSValueRef sc_exception = NULL;")
            lines.append("            JSValueRef sc_call_result = JSObjectCallAsFunction(sc_js_context, sc_function, sc_global, 0, NULL, &sc_exception);")
        }
        lines.append("            if (sc_call_result != NULL) {")
        lines.append("                sc_result = (long)JSValueToNumber(sc_js_context, sc_call_result, NULL);")
        lines.append("            }")
        lines.append("        }")
        lines.append("    }")
        return lines.joined(separator: "\n")
    }

    public func contextTeardownCode() -> String {
        """
            if (sc_js_context != NULL) {
                JSGlobalContextRelease(sc_js_context);
                sc_js_context = NULL;
            }
        """
    }
}
