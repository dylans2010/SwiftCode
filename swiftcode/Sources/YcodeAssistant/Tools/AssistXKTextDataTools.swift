// Expansion toolkit: TextData. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKTextBase64EncodeTool: AssistTool {
    public init() {}
    public var id: String { "text_base64_encode" }
    public var name: String { "Base64 Encode" }
    public var description: String { "Encodes UTF-8 `text` as standard Base64 (set `url_safe` true for Base64URL without padding)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Encodes UTF-8 `text` as standard Base64 (set `url_safe` true for Base64URL without padding).", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "url_safe": JSONSchema(type: "boolean", description: "Emit Base64URL alphabet without padding.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var out = Data(text.utf8).base64EncodedString()
        if AssistToolKit.bool(input, "url_safe", default: false) {
            out = out.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        return .success(out, data: ["length": String(out.count)])
    }
}


public struct XKTextBase64DecodeTool: AssistTool {
    public init() {}
    public var id: String { "text_base64_decode" }
    public var name: String { "Base64 Decode" }
    public var description: String { "Decodes standard or URL-safe Base64 `text` and returns the UTF-8 string (or hex when the payload is binary)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Decodes standard or URL-safe Base64 `text` and returns the UTF-8 string (or hex when the payload is binary).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let d = Data(base64Encoded: s) else { return AssistToolKit.invalid("Input is not valid Base64.") }
        if let str = String(data: d, encoding: .utf8) { return .success(str, data: ["bytes": String(d.count), "encoding": "utf8"]) }
        return .success(AssistToolKit.hex(d), data: ["bytes": String(d.count), "encoding": "hex"])
    }
}


public struct XKTextUrlEncodeTool: AssistTool {
    public init() {}
    public var id: String { "text_url_encode" }
    public var name: String { "URL Percent-Encode" }
    public var description: String { "Percent-encodes `text` for use in a URL query component." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Percent-encodes `text` for use in a URL query component.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#/")
        guard let out = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return AssistToolKit.invalid("Unable to encode input.") }
        return .success(out)
    }
}


public struct XKTextUrlDecodeTool: AssistTool {
    public init() {}
    public var id: String { "text_url_decode" }
    public var name: String { "URL Percent-Decode" }
    public var description: String { "Decodes percent-encoded `text` (treats '+' as space)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Decodes percent-encoded `text` (treats '+' as space).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let out = text.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else { return AssistToolKit.invalid("Input contains malformed percent escapes.") }
        return .success(out)
    }
}


public struct XKTextHexEncodeTool: AssistTool {
    public init() {}
    public var id: String { "text_hex_encode" }
    public var name: String { "Hex Encode" }
    public var description: String { "Encodes UTF-8 `text` bytes as lowercase hexadecimal." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Encodes UTF-8 `text` bytes as lowercase hexadecimal.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        return .success(AssistToolKit.hex(Data(text.utf8)), data: ["bytes": String(text.utf8.count)])
    }
}


public struct XKTextHexDecodeTool: AssistTool {
    public init() {}
    public var id: String { "text_hex_decode" }
    public var name: String { "Hex Decode" }
    public var description: String { "Decodes hexadecimal `text` (whitespace and 0x prefix allowed) into UTF-8 text." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Decodes hexadecimal `text` (whitespace and 0x prefix allowed) into UTF-8 text.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var s = text.lowercased().replacingOccurrences(of: "0x", with: "").filter { !$0.isWhitespace }
        guard s.count % 2 == 0, s.allSatisfy({ $0.isHexDigit }) else { return AssistToolKit.invalid("Input is not valid hexadecimal.") }
        var bytes: [UInt8] = []
        while !s.isEmpty { bytes.append(UInt8(s.prefix(2), radix: 16)!); s.removeFirst(2) }
        let d = Data(bytes)
        return .success(String(data: d, encoding: .utf8) ?? "Binary payload (\(d.count) bytes) is not valid UTF-8.", data: ["bytes": String(d.count)])
    }
}


public struct XKTextHashDigestTool: AssistTool {
    public init() {}
    public var id: String { "text_hash_digest" }
    public var name: String { "Text Hash Digest" }
    public var description: String { "Computes a cryptographic digest of UTF-8 `text`. `algorithm`: sha256 (default), sha384, sha512, sha1, md5." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Computes a cryptographic digest of UTF-8 `text`. `algorithm`: sha256 (default), sha384, sha512, sha1, md5.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "algorithm": JSONSchema(type: "string", description: "sha256 | sha384 | sha512 | sha1 | md5")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let algo = AssistToolKit.string(input, "algorithm") ?? "sha256"
        guard let h = AssistToolKit.digest(Data(text.utf8), algorithm: algo) else { return AssistToolKit.invalid("Unsupported algorithm '\(algo)'. Use sha256, sha384, sha512, sha1 or md5.") }
        return .success(h, data: ["algorithm": algo.lowercased()])
    }
}


public struct XKTextUuidGenerateTool: AssistTool {
    public init() {}
    public var id: String { "text_uuid_generate" }
    public var name: String { "UUID Generate" }
    public var description: String { "Generates `count` (default 1, max 100) random RFC 4122 UUIDs. Set `lowercase` for lowercase output." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates `count` (default 1, max 100) random RFC 4122 UUIDs. Set `lowercase` for lowercase output.", properties: ["count": JSONSchema(type: "integer", description: "How many UUIDs (1-100)."), "lowercase": JSONSchema(type: "boolean", description: "Lowercase output.")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let n = max(1, min(AssistToolKit.int(input, "count", default: 1), 100))
        let lower = AssistToolKit.bool(input, "lowercase", default: false)
        let ids = (0..<n).map { _ in lower ? UUID().uuidString.lowercased() : UUID().uuidString }
        return .success(ids.joined(separator: "\n"), data: ["count": String(n)])
    }
}


public struct XKTextCaseConvertTool: AssistTool {
    public init() {}
    public var id: String { "text_case_convert" }
    public var name: String { "Identifier Case Convert" }
    public var description: String { "Converts `text` into `style`: camel, pascal, snake, kebab, upper_snake, title, lower, upper. Splits on camelCase boundaries and punctuation." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts `text` into `style`: camel, pascal, snake, kebab, upper_snake, title, lower, upper. Splits on camelCase boundaries and punctuation.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "style": JSONSchema(type: "string", description: "camel | pascal | snake | kebab | upper_snake | title | lower | upper")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let style = (AssistToolKit.string(input, "style") ?? "camel").lowercased()
        let w = AssistToolKit.words(text)
        guard !w.isEmpty else { return AssistToolKit.invalid("Input contains no words.") }
        let lower = w.map { $0.lowercased() }
        let out: String
        switch style {
        case "camel": out = lower[0] + lower.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        case "pascal": out = lower.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        case "snake": out = lower.joined(separator: "_")
        case "kebab": out = lower.joined(separator: "-")
        case "upper_snake", "constant": out = lower.joined(separator: "_").uppercased()
        case "title": out = lower.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        case "lower": out = lower.joined(separator: " ")
        case "upper": out = lower.joined(separator: " ").uppercased()
        default: return AssistToolKit.invalid("Unknown style '\(style)'.")
        }
        return .success(out, data: ["style": style])
    }
}


public struct XKTextSlugifyTool: AssistTool {
    public init() {}
    public var id: String { "text_slugify" }
    public var name: String { "Slugify" }
    public var description: String { "Converts `text` into a lowercase ASCII URL/file slug (diacritics removed, words joined by '-')." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts `text` into a lowercase ASCII URL/file slug (diacritics removed, words joined by '-').", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en_US_POSIX"))
        let slug = AssistToolKit.words(folded).map { $0.lowercased() }.joined(separator: "-")
        return .success(slug)
    }
}


public struct XKTextStatisticsTool: AssistTool {
    public init() {}
    public var id: String { "text_statistics" }
    public var name: String { "Text Statistics" }
    public var description: String { "Counts characters, bytes, words, lines, sentences and paragraphs in `text`, and gives an approximate token estimate (chars/4)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Counts characters, bytes, words, lines, sentences and paragraphs in `text`, and gives an approximate token estimate (chars/4).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let lines = text.components(separatedBy: .newlines)
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let sentences = text.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let r = "characters: \(text.count)\nbytes(utf8): \(text.utf8.count)\nwords: \(words)\nlines: \(lines.count)\nsentences: \(sentences)\nparagraphs: \(paragraphs)\napprox_tokens: \((text.count + 3) / 4)"
        return .success(r, data: ["words": String(words), "lines": String(lines.count)])
    }
}


public struct XKTextSortLinesTool: AssistTool {
    public init() {}
    public var id: String { "text_sort_lines" }
    public var name: String { "Sort Lines" }
    public var description: String { "Sorts the lines of `text`. Options: `unique`, `reverse`, `numeric`, `case_insensitive`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Sorts the lines of `text`. Options: `unique`, `reverse`, `numeric`, `case_insensitive`.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "unique": JSONSchema(type: "boolean", description: "Remove duplicates."), "reverse": JSONSchema(type: "boolean", description: "Descending order."), "numeric": JSONSchema(type: "boolean", description: "Numeric sort."), "case_insensitive": JSONSchema(type: "boolean", description: "Ignore case.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var lines = text.components(separatedBy: .newlines)
        if AssistToolKit.bool(input, "unique", default: false) { var seen = Set<String>(); lines = lines.filter { seen.insert($0).inserted } }
        let ci = AssistToolKit.bool(input, "case_insensitive", default: false)
        if AssistToolKit.bool(input, "numeric", default: false) {
            lines.sort { (Double($0.trimmingCharacters(in: .whitespaces)) ?? .infinity) < (Double($1.trimmingCharacters(in: .whitespaces)) ?? .infinity) }
        } else {
            lines.sort { ci ? $0.localizedCaseInsensitiveCompare($1) == .orderedAscending : $0 < $1 }
        }
        if AssistToolKit.bool(input, "reverse", default: false) { lines.reverse() }
        return .success(lines.joined(separator: "\n"), data: ["lines": String(lines.count)])
    }
}


public struct XKTextDedupeLinesTool: AssistTool {
    public init() {}
    public var id: String { "text_dedupe_lines" }
    public var name: String { "Deduplicate Lines" }
    public var description: String { "Removes duplicate lines from `text` while preserving first-occurrence order; reports how many were removed." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Removes duplicate lines from `text` while preserving first-occurrence order; reports how many were removed.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var seen = Set<String>()
        let lines = text.components(separatedBy: .newlines)
        let kept = lines.filter { seen.insert($0).inserted }
        return .success(kept.joined(separator: "\n"), data: ["removed": String(lines.count - kept.count)])
    }
}


public struct XKTextHtmlEscapeTool: AssistTool {
    public init() {}
    public var id: String { "text_html_escape" }
    public var name: String { "HTML Escape" }
    public var description: String { "Escapes ampersands, angle brackets, double and single quotes in `text` as HTML entities." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Escapes ampersands, angle brackets, double and single quotes in `text` as HTML entities.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let out = text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
        return .success(out)
    }
}


public struct XKTextHtmlUnescapeTool: AssistTool {
    public init() {}
    public var id: String { "text_html_unescape" }
    public var name: String { "HTML Unescape" }
    public var description: String { "Decodes named (&amp; &lt; &gt; &quot; &apos; &nbsp;) and numeric (&#NN; &#xHH;) HTML entities in `text`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Decodes named (&amp; &lt; &gt; &quot; &apos; &nbsp;) and numeric (&#NN; &#xHH;) HTML entities in `text`.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var out = text
        let regex = try NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);")
        for m in regex.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed() {
            let ns = out as NSString
            let isHex = ns.substring(with: m.range(at: 1)) == "x"
            if let v = UInt32(ns.substring(with: m.range(at: 2)), radix: isHex ? 16 : 10), let sc = Unicode.Scalar(v), let r = Range(m.range, in: out) {
                out.replaceSubrange(r, with: String(Character(sc)))
            }
        }
        for (k, v) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"), ("&nbsp;", " "), ("&amp;", "&")] { out = out.replacingOccurrences(of: k, with: v) }
        return .success(out)
    }
}


public struct XKTextSwiftStringLiteralTool: AssistTool {
    public init() {}
    public var id: String { "text_swift_string_literal" }
    public var name: String { "Swift String Literal" }
    public var description: String { "Converts `text` into a valid Swift string literal (escaped single-line, or multi-line when `multiline` is true)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts `text` into a valid Swift string literal (escaped single-line, or multi-line when `multiline` is true).", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "multiline": JSONSchema(type: "boolean", description: "Emit a triple-quoted literal.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        if AssistToolKit.bool(input, "multiline", default: false) {
            let body = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"\"\"", with: "\\\"\"\"")
            return .success("\"\"\"\n\(body)\n\"\"\"")
        }
        var out = ""
        for ch in text.unicodeScalars {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\0": out += "\\0"
            default: out.unicodeScalars.append(ch)
            }
        }
        return .success("\"\(out)\"")
    }
}


public struct XKTextRegexTestTool: AssistTool {
    public init() {}
    public var id: String { "text_regex_test" }
    public var name: String { "Regex Test" }
    public var description: String { "Runs regular expression `pattern` against `text` and returns every match with capture groups and ranges." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Runs regular expression `pattern` against `text` and returns every match with capture groups and ranges.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "pattern": JSONSchema(type: "string", description: "ICU regular expression."), "case_insensitive": JSONSchema(type: "boolean", description: "Ignore case.")], required: ["text", "pattern"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let pattern = AssistToolKit.string(input, "pattern") else { return AssistToolKit.missing("pattern") }
        let opts: NSRegularExpression.Options = AssistToolKit.bool(input, "case_insensitive", default: false) ? [.caseInsensitive, .anchorsMatchLines] : [.anchorsMatchLines]
        guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { return AssistToolKit.invalid("Invalid regular expression.") }
        let ns = text as NSString
        let ms = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var lines = ["matches: \(ms.count)"]
        for (i, m) in ms.prefix(200).enumerated() {
            lines.append("[\(i)] @\(m.range.location)+\(m.range.length): \(ns.substring(with: m.range))")
            if m.numberOfRanges > 1 {
                for g in 1..<m.numberOfRanges { let r = m.range(at: g); lines.append("    group \(g): \(r.location == NSNotFound ? "<nil>" : ns.substring(with: r))") }
            }
        }
        return .success(lines.joined(separator: "\n"), data: ["count": String(ms.count)])
    }
}


public struct XKTextRegexReplaceTool: AssistTool {
    public init() {}
    public var id: String { "text_regex_replace" }
    public var name: String { "Regex Replace" }
    public var description: String { "Replaces every match of `pattern` in `text` with `template` ($1, $2 for groups) and returns the result." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Replaces every match of `pattern` in `text` with `template` ($1, $2 for groups) and returns the result.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "pattern": JSONSchema(type: "string", description: "ICU regular expression."), "template": JSONSchema(type: "string", description: "Replacement template.")], required: ["text", "pattern"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let pattern = AssistToolKit.string(input, "pattern") else { return AssistToolKit.missing("pattern") }
        let template = AssistToolKit.string(input, "template") ?? ""
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return AssistToolKit.invalid("Invalid regular expression.") }
        let range = NSRange(text.startIndex..., in: text)
        let count = re.numberOfMatches(in: text, range: range)
        return .success(re.stringByReplacingMatches(in: text, range: range, withTemplate: template), data: ["replacements": String(count)])
    }
}


public struct XKTextLineDiffTool: AssistTool {
    public init() {}
    public var id: String { "text_line_diff" }
    public var name: String { "Line Diff" }
    public var description: String { "Computes a unified-style line diff between `old_text` and `new_text` (lines prefixed with -, +, or space)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Computes a unified-style line diff between `old_text` and `new_text` (lines prefixed with -, +, or space).", properties: ["old_text": JSONSchema(type: "string", description: "Original text."), "new_text": JSONSchema(type: "string", description: "Updated text.")], required: ["old_text", "new_text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let a = AssistToolKit.string(input, "old_text") else { return AssistToolKit.missing("old_text") }
        guard let b = AssistToolKit.string(input, "new_text") else { return AssistToolKit.missing("new_text") }
        let al = a.components(separatedBy: .newlines), bl = b.components(separatedBy: .newlines)
        let diff = bl.difference(from: al)
        var removed = Set<Int>(), inserted = Set<Int>()
        for c in diff { switch c { case .remove(let o, _, _): removed.insert(o); case .insert(let o, _, _): inserted.insert(o) } }
        var out: [String] = []
        var i = 0, j = 0
        while i < al.count || j < bl.count {
            if i < al.count, removed.contains(i) { out.append("-" + al[i]); i += 1 }
            else if j < bl.count, inserted.contains(j) { out.append("+" + bl[j]); j += 1 }
            else { if i < al.count { out.append(" " + al[i]) }; i += 1; j += 1 }
        }
        return .success(AssistToolKit.output(out.joined(separator: "\n")), data: ["removed": String(removed.count), "added": String(inserted.count)])
    }
}


public struct XKTextWrapTool: AssistTool {
    public init() {}
    public var id: String { "text_wrap" }
    public var name: String { "Word Wrap" }
    public var description: String { "Re-wraps `text` to `width` columns (default 80) at word boundaries, preserving blank-line paragraph breaks." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Re-wraps `text` to `width` columns (default 80) at word boundaries, preserving blank-line paragraph breaks.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "width": JSONSchema(type: "integer", description: "Column width (default 80).")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let width = max(10, AssistToolKit.int(input, "width", default: 80))
        let paragraphs = text.components(separatedBy: "\n\n")
        let wrapped = paragraphs.map { p -> String in
            var lines: [String] = []; var cur = ""
            for w in p.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) {
                if cur.isEmpty { cur = String(w) } else if cur.count + 1 + w.count <= width { cur += " " + w } else { lines.append(cur); cur = String(w) }
            }
            if !cur.isEmpty { lines.append(cur) }
            return lines.joined(separator: "\n")
        }
        return .success(wrapped.joined(separator: "\n\n"))
    }
}


public struct XKTextIndentTool: AssistTool {
    public init() {}
    public var id: String { "text_indent" }
    public var name: String { "Indent/Outdent Lines" }
    public var description: String { "Indents every non-empty line of `text` by `spaces` (negative values outdent)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Indents every non-empty line of `text` by `spaces` (negative values outdent).", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "spaces": JSONSchema(type: "integer", description: "Spaces to add (negative to remove).")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let n = AssistToolKit.int(input, "spaces", default: 4)
        let lines = text.components(separatedBy: .newlines).map { line -> String in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            if n >= 0 { return String(repeating: " ", count: n) + line }
            var l = Substring(line); var k = -n
            while k > 0, let f = l.first, f == " " { l = l.dropFirst(); k -= 1 }
            return String(l)
        }
        return .success(lines.joined(separator: "\n"))
    }
}


public struct XKTextExtractUrlsTool: AssistTool {
    public init() {}
    public var id: String { "text_extract_urls" }
    public var name: String { "Extract URLs" }
    public var description: String { "Extracts every URL found in `text` using NSDataDetector (deduplicated, in order)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Extracts every URL found in `text` using NSDataDetector (deduplicated, in order).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let det = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        var seen = Set<String>(); var urls: [String] = []
        for m in det.matches(in: text, range: NSRange(text.startIndex..., in: text)) { if let u = m.url?.absoluteString, seen.insert(u).inserted { urls.append(u) } }
        return .success(urls.isEmpty ? "No URLs found." : urls.joined(separator: "\n"), data: ["count": String(urls.count)])
    }
}


public struct XKTextExtractEmailsTool: AssistTool {
    public init() {}
    public var id: String { "text_extract_emails" }
    public var name: String { "Extract Email Addresses" }
    public var description: String { "Extracts unique email addresses from `text`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Extracts unique email addresses from `text`.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let re = try NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        let ns = text as NSString
        var seen = Set<String>(); var out: [String] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) { let e = ns.substring(with: m.range); if seen.insert(e.lowercased()).inserted { out.append(e) } }
        return .success(out.isEmpty ? "No email addresses found." : out.joined(separator: "\n"), data: ["count": String(out.count)])
    }
}


public struct XKTextLevenshteinDistanceTool: AssistTool {
    public init() {}
    public var id: String { "text_levenshtein_distance" }
    public var name: String { "Levenshtein Distance" }
    public var description: String { "Computes the edit distance and similarity ratio between strings `a` and `b`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Computes the edit distance and similarity ratio between strings `a` and `b`.", properties: ["a": JSONSchema(type: "string", description: "First string."), "b": JSONSchema(type: "string", description: "Second string.")], required: ["a", "b"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let a = AssistToolKit.string(input, "a") else { return AssistToolKit.missing("a") }
        guard let b = AssistToolKit.string(input, "b") else { return AssistToolKit.missing("b") }
        let x = Array(a), y = Array(b)
        var prev = Array(0...y.count)
        for i in 1...max(1, x.count) where !x.isEmpty {
            var cur = [i] + Array(repeating: 0, count: y.count)
            for j in stride(from: 1, through: y.count, by: 1) { cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1)) }
            prev = cur
        }
        let d = x.isEmpty ? y.count : prev[y.count]
        let ratio = max(x.count, y.count) == 0 ? 1.0 : 1.0 - Double(d) / Double(max(x.count, y.count))
        return .success("distance: \(d)\nsimilarity: \(String(format: "%.3f", ratio))", data: ["distance": String(d)])
    }
}


public struct XKNumberBaseConvertTool: AssistTool {
    public init() {}
    public var id: String { "number_base_convert" }
    public var name: String { "Number Base Convert" }
    public var description: String { "Converts integer `value` from base `from` (default 10) to base `to` (default 16). Bases 2-36; 0x/0b/0o prefixes accepted." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts integer `value` from base `from` (default 10) to base `to` (default 16). Bases 2-36; 0x/0b/0o prefixes accepted.", properties: ["value": JSONSchema(type: "string", description: "Integer value."), "from": JSONSchema(type: "integer", description: "Source base."), "to": JSONSchema(type: "integer", description: "Target base.")], required: ["value"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard var v = AssistToolKit.string(input, "value")?.trimmingCharacters(in: .whitespaces).lowercased() else { return AssistToolKit.missing("value") }
        var from = AssistToolKit.int(input, "from", default: 10)
        let to = AssistToolKit.int(input, "to", default: 16)
        for (p, b) in [("0x", 16), ("0b", 2), ("0o", 8)] where v.hasPrefix(p) { v.removeFirst(2); from = b }
        guard (2...36).contains(from), (2...36).contains(to) else { return AssistToolKit.invalid("Bases must be between 2 and 36.") }
        guard let n = Int64(v.replacingOccurrences(of: "_", with: ""), radix: from) else { return AssistToolKit.invalid("'\(v)' is not a valid base-\(from) integer.") }
        return .success("\(String(n, radix: to))\n(decimal \(n), hex 0x\(String(n, radix: 16)), binary 0b\(String(n, radix: 2)))", data: ["result": String(n, radix: to)])
    }
}


public struct XKUnixTimestampConvertTool: AssistTool {
    public init() {}
    public var id: String { "unix_timestamp_convert" }
    public var name: String { "Unix Timestamp Convert" }
    public var description: String { "Converts a Unix timestamp `value` (seconds or milliseconds) to ISO-8601 UTC and local time, or an ISO-8601 date to Unix seconds. Omit `value` for the current time." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts a Unix timestamp `value` (seconds or milliseconds) to ISO-8601 UTC and local time, or an ISO-8601 date to Unix seconds. Omit `value` for the current time.", properties: ["value": JSONSchema(type: "string", description: "Unix timestamp or ISO-8601 date (optional).")], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let raw = AssistToolKit.string(input, "value")?.trimmingCharacters(in: .whitespaces) ?? ""
        let iso = ISO8601DateFormatter()
        let date: Date
        if raw.isEmpty { date = Date() }
        else if let n = Double(raw) { date = Date(timeIntervalSince1970: n > 1e11 ? n / 1000 : n) }
        else if let d = iso.date(from: raw) { date = d }
        else { return AssistToolKit.invalid("Value must be a Unix timestamp or ISO-8601 date.") }
        let local = DateFormatter(); local.dateStyle = .full; local.timeStyle = .long
        return .success("unix_seconds: \(Int(date.timeIntervalSince1970))\nunix_ms: \(Int64(date.timeIntervalSince1970 * 1000))\niso8601_utc: \(iso.string(from: date))\nlocal: \(local.string(from: date)) (\(TimeZone.current.identifier))", data: ["unix": String(Int(date.timeIntervalSince1970))])
    }
}


public struct XKDateFormatConvertTool: AssistTool {
    public init() {}
    public var id: String { "date_format_convert" }
    public var name: String { "Date Format Convert" }
    public var description: String { "Parses `date` with `from_format` (ICU pattern, default ISO-8601) and renders it with `to_format` (ICU pattern). Uses en_US_POSIX and optional `timezone`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Parses `date` with `from_format` (ICU pattern, default ISO-8601) and renders it with `to_format` (ICU pattern). Uses en_US_POSIX and optional `timezone`.", properties: ["date": JSONSchema(type: "string", description: "Date string."), "from_format": JSONSchema(type: "string", description: "ICU input pattern (default ISO-8601)."), "to_format": JSONSchema(type: "string", description: "ICU output pattern."), "timezone": JSONSchema(type: "string", description: "IANA zone (default UTC).")], required: ["date", "to_format"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "date") else { return AssistToolKit.missing("date") }
        guard let toFmt = AssistToolKit.string(input, "to_format") else { return AssistToolKit.missing("to_format") }
        let tz = AssistToolKit.string(input, "timezone").flatMap { TimeZone(identifier: $0) } ?? TimeZone(identifier: "UTC")!
        var date: Date?
        if let fromFmt = AssistToolKit.string(input, "from_format") {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = tz; f.dateFormat = fromFmt; date = f.date(from: raw)
        } else { date = ISO8601DateFormatter().date(from: raw) }
        guard let d = date else { return AssistToolKit.invalid("Could not parse '\(raw)' with the given format.") }
        let out = DateFormatter(); out.locale = Locale(identifier: "en_US_POSIX"); out.timeZone = tz; out.dateFormat = toFmt
        return .success(out.string(from: d))
    }
}


public struct XKSemverCompareTool: AssistTool {
    public init() {}
    public var id: String { "semver_compare" }
    public var name: String { "Semantic Version Compare" }
    public var description: String { "Compares semantic versions `a` and `b` (MAJOR.MINOR.PATCH[-prerelease]) following SemVer 2.0 precedence." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Compares semantic versions `a` and `b` (MAJOR.MINOR.PATCH[-prerelease]) following SemVer 2.0 precedence.", properties: ["a": JSONSchema(type: "string", description: "First version."), "b": JSONSchema(type: "string", description: "Second version.")], required: ["a", "b"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let a = AssistToolKit.string(input, "a"), let b = AssistToolKit.string(input, "b") else { return AssistToolKit.missing("a/b") }
        func parse(_ s: String) -> ([Int], [String])? {
            let t = s.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let core = t.split(separator: "+", maxSplits: 1)[0]
            let parts = core.split(separator: "-", maxSplits: 1)
            let nums = parts[0].split(separator: ".").map { Int($0) }
            guard !nums.isEmpty, nums.allSatisfy({ $0 != nil }) else { return nil }
            var n = nums.map { $0! }; while n.count < 3 { n.append(0) }
            return (n, parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : [])
        }
        guard let x = parse(a), let y = parse(b) else { return AssistToolKit.invalid("Versions must look like 1.2.3 or 1.2.3-beta.1") }
        var r = 0
        for (p, q) in zip(x.0, y.0) where p != q { r = p < q ? -1 : 1; break }
        if r == 0 {
            if x.1.isEmpty != y.1.isEmpty { r = x.1.isEmpty ? 1 : -1 }
            else { for (p, q) in zip(x.1, y.1) where p != q { if let pi = Int(p), let qi = Int(q) { r = pi < qi ? -1 : 1 } else { r = p < q ? -1 : 1 }; break }
                if r == 0, x.1.count != y.1.count { r = x.1.count < y.1.count ? -1 : 1 } }
        }
        let word = r < 0 ? "older than" : (r > 0 ? "newer than" : "equal to")
        return .success("\(a) is \(word) \(b)", data: ["result": String(r)])
    }
}


public struct XKSemverBumpTool: AssistTool {
    public init() {}
    public var id: String { "semver_bump" }
    public var name: String { "Semantic Version Bump" }
    public var description: String { "Bumps `version` by `part` (major, minor, patch) and optionally appends `prerelease`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Bumps `version` by `part` (major, minor, patch) and optionally appends `prerelease`.", properties: ["version": JSONSchema(type: "string", description: "Current version."), "part": JSONSchema(type: "string", description: "major | minor | patch"), "prerelease": JSONSchema(type: "string", description: "Optional prerelease tag.")], required: ["version"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let v = AssistToolKit.string(input, "version") else { return AssistToolKit.missing("version") }
        let part = (AssistToolKit.string(input, "part") ?? "patch").lowercased()
        let core = v.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: "-")[0].split(separator: "+")[0]
        var n = core.split(separator: ".").compactMap { Int($0) }
        guard !n.isEmpty else { return AssistToolKit.invalid("Invalid version '\(v)'.") }
        while n.count < 3 { n.append(0) }
        switch part { case "major": n = [n[0] + 1, 0, 0]; case "minor": n = [n[0], n[1] + 1, 0]; case "patch": n[2] += 1; default: return AssistToolKit.invalid("part must be major, minor or patch") }
        var out = n.prefix(3).map(String.init).joined(separator: ".")
        if let pre = AssistToolKit.string(input, "prerelease"), !pre.isEmpty { out += "-" + pre }
        return .success(out)
    }
}


public struct XKColorHexToSwiftTool: AssistTool {
    public init() {}
    public var id: String { "color_hex_to_swift" }
    public var name: String { "Hex Color to Swift" }
    public var description: String { "Converts a hex color (#RGB, #RRGGBB, #RRGGBBAA) to RGBA components plus SwiftUI Color, UIColor and NSColor initializer code." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts a hex color (#RGB, #RRGGBB, #RRGGBBAA) to RGBA components plus SwiftUI Color, UIColor and NSColor initializer code.", properties: ["hex": JSONSchema(type: "string", description: "Hex color string.")], required: ["hex"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard var h = AssistToolKit.string(input, "hex")?.trimmingCharacters(in: .whitespaces) else { return AssistToolKit.missing("hex") }
        h = h.replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "0x", with: "")
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        if h.count == 6 { h += "FF" }
        guard h.count == 8, let v = UInt32(h, radix: 16) else { return AssistToolKit.invalid("Expected #RGB, #RRGGBB or #RRGGBBAA.") }
        let r = Double((v >> 24) & 0xFF) / 255, g = Double((v >> 16) & 0xFF) / 255, b = Double((v >> 8) & 0xFF) / 255, a = Double(v & 0xFF) / 255
        func f(_ x: Double) -> String { String(format: "%.3f", x) }
        let s = "rgba: (\(Int(r*255)), \(Int(g*255)), \(Int(b*255)), \(f(a)))\nSwiftUI: Color(red: \(f(r)), green: \(f(g)), blue: \(f(b)), opacity: \(f(a)))\nUIKit: UIColor(red: \(f(r)), green: \(f(g)), blue: \(f(b)), alpha: \(f(a)))\nAppKit: NSColor(srgbRed: \(f(r)), green: \(f(g)), blue: \(f(b)), alpha: \(f(a)))"
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return .success(s + "\nrelative_luminance: \(f(lum)) (\(lum > 0.5 ? "use dark text" : "use light text"))")
    }
}


public struct XKColorContrastRatioTool: AssistTool {
    public init() {}
    public var id: String { "color_contrast_ratio" }
    public var name: String { "Color Contrast Ratio" }
    public var description: String { "Computes the WCAG 2.x contrast ratio between `foreground` and `background` hex colors and reports AA/AAA pass/fail for normal and large text." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Computes the WCAG 2.x contrast ratio between `foreground` and `background` hex colors and reports AA/AAA pass/fail for normal and large text.", properties: ["foreground": JSONSchema(type: "string", description: "Foreground hex."), "background": JSONSchema(type: "string", description: "Background hex.")], required: ["foreground", "background"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        func lum(_ raw: String) -> Double? {
            var h = raw.replacingOccurrences(of: "#", with: "")
            if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
            guard h.count >= 6, let v = UInt32(h.prefix(6), radix: 16) else { return nil }
            func c(_ x: UInt32) -> Double { let s = Double(x) / 255; return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) }
            return 0.2126 * c((v >> 16) & 0xFF) + 0.7152 * c((v >> 8) & 0xFF) + 0.0722 * c(v & 0xFF)
        }
        guard let fg = AssistToolKit.string(input, "foreground"), let bg = AssistToolKit.string(input, "background") else { return AssistToolKit.missing("foreground/background") }
        guard let l1 = lum(fg), let l2 = lum(bg) else { return AssistToolKit.invalid("Colors must be hex values like #1A2B3C.") }
        let ratio = (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
        func p(_ b: Bool) -> String { b ? "PASS" : "FAIL" }
        return .success("contrast_ratio: \(String(format: "%.2f", ratio)):1\nAA normal (4.5): \(p(ratio >= 4.5))\nAA large (3.0): \(p(ratio >= 3))\nAAA normal (7.0): \(p(ratio >= 7))\nAAA large (4.5): \(p(ratio >= 4.5))", data: ["ratio": String(format: "%.2f", ratio)])
    }
}


public struct XKJsonFormatTool: AssistTool {
    public init() {}
    public var id: String { "json_format" }
    public var name: String { "JSON Pretty Print" }
    public var description: String { "Validates `text` as JSON and returns it pretty-printed with sorted keys (or minified when `minify` is true)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Validates `text` as JSON and returns it pretty-printed with sorted keys (or minified when `minify` is true).", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "minify": JSONSchema(type: "boolean", description: "Emit compact JSON.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let obj = AssistToolKit.parseJSON(text) else { return AssistToolKit.invalid("Input is not valid JSON.") }
        if AssistToolKit.bool(input, "minify", default: false) {
            let d = try JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes])
            return .success(String(decoding: d, as: UTF8.self))
        }
        return .success(AssistToolKit.output(AssistToolKit.prettyJSON(obj) ?? text))
    }
}


public struct XKJsonStructureValidateTool: AssistTool {
    public init() {}
    public var id: String { "json_structure_validate" }
    public var name: String { "JSON Validate" }
    public var description: String { "Validates `text` as JSON and reports the top-level type, element counts, depth, or the exact parse error." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Validates `text` as JSON and reports the top-level type, element counts, depth, or the exact parse error.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        do {
            let obj = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
            func depth(_ o: Any) -> Int { if let d = o as? [String: Any] { return 1 + (d.values.map(depth).max() ?? 0) }; if let a = o as? [Any] { return 1 + (a.map(depth).max() ?? 0) }; return 0 }
            let type = obj is [String: Any] ? "object(\((obj as! [String: Any]).count) keys)" : obj is [Any] ? "array(\((obj as! [Any]).count) items)" : "scalar"
            return .success("valid JSON\ntop_level: \(type)\nmax_depth: \(depth(obj))", data: ["valid": "true"])
        } catch {
            return AssistToolKit.invalid("Invalid JSON: \((error as NSError).userInfo["NSDebugDescription"] ?? error.localizedDescription)")
        }
    }
}


public struct XKJsonQueryTool: AssistTool {
    public init() {}
    public var id: String { "json_query" }
    public var name: String { "JSON Path Query" }
    public var description: String { "Extracts a value from JSON `text` using a dot/bracket `query` such as `items[0].name` or `meta.tags[*]`." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Extracts a value from JSON `text` using a dot/bracket `query` such as `items[0].name` or `meta.tags[*]`.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "query": JSONSchema(type: "string", description: "Path like a.b[0].c or a[*].id.")], required: ["text", "query"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let q = AssistToolKit.string(input, "query") else { return AssistToolKit.missing("query") }
        guard var cur: [Any] = AssistToolKit.parseJSON(text).map({ [$0] }) else { return AssistToolKit.invalid("Input is not valid JSON.") }
        let tokens = q.replacingOccurrences(of: "[", with: ".[").split(separator: ".").map(String.init).filter { !$0.isEmpty && $0 != "$" }
        for t in tokens {
            var next: [Any] = []
            for v in cur {
                if t == "[*]" || t == "*" { if let a = v as? [Any] { next += a } else if let d = v as? [String: Any] { next += d.keys.sorted().compactMap { d[$0] } } }
                else if t.hasPrefix("["), let i = Int(t.dropFirst().dropLast()), let a = v as? [Any] { let idx = i < 0 ? a.count + i : i; if a.indices.contains(idx) { next.append(a[idx]) } }
                else if let d = v as? [String: Any], let x = d[t] { next.append(x) }
            }
            cur = next
        }
        guard !cur.isEmpty else { return AssistToolKit.notFound("No value at '\(q)'.") }
        let result: Any = cur.count == 1 ? cur[0] : cur
        return .success(AssistToolKit.output(AssistToolKit.prettyJSON(result) ?? "\(result)"), data: ["matches": String(cur.count)])
    }
}


public struct XKJsonListKeysTool: AssistTool {
    public init() {}
    public var id: String { "json_list_keys" }
    public var name: String { "JSON Key Paths" }
    public var description: String { "Lists every key path in JSON `text` with its value type (arrays summarized by first element), useful for designing Codable models." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Lists every key path in JSON `text` with its value type (arrays summarized by first element), useful for designing Codable models.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let obj = AssistToolKit.parseJSON(text) else { return AssistToolKit.invalid("Input is not valid JSON.") }
        var out: [String] = []
        func walk(_ o: Any, _ p: String) {
            if let d = o as? [String: Any] { if !p.isEmpty { out.append("\(p): object") }; for k in d.keys.sorted() { walk(d[k]!, p.isEmpty ? k : "\(p).\(k)") } }
            else if let a = o as? [Any] { out.append("\(p): array[\(a.count)]"); if let f = a.first { walk(f, p + "[0]") } }
            else if o is NSNull { out.append("\(p): null") }
            else if let n = o as? NSNumber { out.append("\(p): \(CFGetTypeID(n) == CFBooleanGetTypeID() ? "bool" : (n.stringValue.contains(".") ? "double" : "int"))") }
            else { out.append("\(p): string") }
        }
        walk(obj, "")
        return .success(AssistToolKit.output(out.joined(separator: "\n")), data: ["paths": String(out.count)])
    }
}


public struct XKJsonToSwiftCodableTool: AssistTool {
    public init() {}
    public var id: String { "json_to_swift_codable" }
    public var name: String { "JSON to Swift Codable" }
    public var description: String { "Generates Swift Codable structs (with CodingKeys for snake_case keys) from sample JSON `text`. `root_name` names the top-level type (default Root)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates Swift Codable structs (with CodingKeys for snake_case keys) from sample JSON `text`. `root_name` names the top-level type (default Root).", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "root_name": JSONSchema(type: "string", description: "Top-level type name.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let obj = AssistToolKit.parseJSON(text) else { return AssistToolKit.invalid("Input is not valid JSON.") }
        let rootName = AssistToolKit.string(input, "root_name") ?? "Root"
        var structs: [String] = []
        func typeName(_ k: String) -> String { let w = AssistToolKit.words(k); return w.isEmpty ? "Item" : w.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined() }
        func propName(_ k: String) -> String { let w = AssistToolKit.words(k).map { $0.lowercased() }; guard let f = w.first else { return "value" }; return f + w.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined() }
        func swiftType(_ v: Any, _ key: String) -> String {
            if let d = v as? [String: Any] { let n = typeName(key); build(d, n); return n }
            if let a = v as? [Any] { return a.first.map { "[\(swiftType($0, key.hasSuffix("s") ? String(key.dropLast()) : key + "Item"))]" } ?? "[String]" }
            if v is NSNull { return "String?" }
            if let n = v as? NSNumber { return CFGetTypeID(n) == CFBooleanGetTypeID() ? "Bool" : (n.stringValue.contains(".") ? "Double" : "Int") }
            return "String"
        }
        func build(_ d: [String: Any], _ name: String) {
            var props: [String] = [], keys: [String] = [], needKeys = false
            for k in d.keys.sorted() { let p = propName(k); let t = swiftType(d[k]!, k); props.append("    let \(p): \(t)"); keys.append(p == k ? "        case \(p)" : "        case \(p) = \"\(k)\""); if p != k { needKeys = true } }
            var s = "struct \(name): Codable, Hashable, Sendable {\n" + props.joined(separator: "\n")
            if needKeys { s += "\n\n    enum CodingKeys: String, CodingKey {\n" + keys.joined(separator: "\n") + "\n    }" }
            structs.append(s + "\n}")
        }
        if let d = obj as? [String: Any] { build(d, rootName) }
        else if let a = obj as? [Any], let f = a.first as? [String: Any] { build(f, rootName); structs.append("typealias \(rootName)List = [\(rootName)]") }
        else { return AssistToolKit.invalid("Top-level JSON must be an object or an array of objects.") }
        return .success(structs.joined(separator: "\n\n"), data: ["types": String(structs.count)])
    }
}


public struct XKConvertJsonToPlistXmlTool: AssistTool {
    public init() {}
    public var id: String { "convert_json_to_plist_xml" }
    public var name: String { "JSON to Property List" }
    public var description: String { "Converts JSON `text` into an XML property list." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts JSON `text` into an XML property list.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let obj = AssistToolKit.parseJSON(text) else { return AssistToolKit.invalid("Input is not valid JSON.") }
        func clean(_ o: Any) -> Any? { if o is NSNull { return nil }; if let d = o as? [String: Any] { return d.compactMapValues(clean) }; if let a = o as? [Any] { return a.compactMap(clean) }; return o }
        guard let c = clean(obj) else { return AssistToolKit.invalid("JSON null cannot be represented in a property list.") }
        let d = try PropertyListSerialization.data(fromPropertyList: c, format: .xml, options: 0)
        return .success(String(decoding: d, as: UTF8.self))
    }
}


public struct XKConvertPlistTextToJsonTool: AssistTool {
    public init() {}
    public var id: String { "convert_plist_text_to_json" }
    public var name: String { "Property List to JSON" }
    public var description: String { "Converts XML/OpenStep property list `text` into pretty JSON (dates as ISO-8601, data as Base64)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts XML/OpenStep property list `text` into pretty JSON (dates as ISO-8601, data as Base64).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let obj = try? PropertyListSerialization.propertyList(from: Data(text.utf8), options: [], format: nil) else { return AssistToolKit.invalid("Input is not a valid property list.") }
        func conv(_ o: Any) -> Any { if let d = o as? [String: Any] { return d.mapValues(conv) }; if let a = o as? [Any] { return a.map(conv) }; if let dt = o as? Date { return ISO8601DateFormatter().string(from: dt) }; if let da = o as? Data { return da.base64EncodedString() }; return o }
        return .success(AssistToolKit.prettyJSON(conv(obj)) ?? "")
    }
}


public struct XKConvertCsvTextToJsonTool: AssistTool {
    public init() {}
    public var id: String { "convert_csv_text_to_json" }
    public var name: String { "CSV to JSON" }
    public var description: String { "Parses CSV `text` (RFC 4180 quoting, custom `delimiter`) using the first row as headers and returns a JSON array of objects." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Parses CSV `text` (RFC 4180 quoting, custom `delimiter`) using the first row as headers and returns a JSON array of objects.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "delimiter": JSONSchema(type: "string", description: "Field delimiter (default ',').")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let delim = Character(AssistToolKit.string(input, "delimiter")?.first.map(String.init) ?? ",")
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var it = Array(text).makeIterator(); var pending: Character? = nil
        while let c = pending ?? it.next() {
            pending = nil
            if quoted { if c == "\"" { if let n = it.next() { if n == "\"" { field.append("\"") } else { quoted = false; pending = n } } else { quoted = false } } else { field.append(c) } }
            else if c == "\"" { quoted = true }
            else if c == delim { row.append(field); field = "" }
            else if c == "\n" || c == "\r\n" { row.append(field); field = ""; rows.append(row); row = [] }
            else if c != "\r" { field.append(c) }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        guard let header = rows.first else { return AssistToolKit.invalid("CSV is empty.") }
        let objs: [[String: Any]] = rows.dropFirst().filter { !($0.count == 1 && $0[0].isEmpty) }.map { r in
            var o: [String: Any] = [:]; for (i, h) in header.enumerated() { o[h] = i < r.count ? r[i] : "" }; return o }
        return .success(AssistToolKit.output(AssistToolKit.prettyJSON(objs) ?? "[]"), data: ["rows": String(objs.count), "columns": String(header.count)])
    }
}


public struct XKConvertJsonTextToCsvTool: AssistTool {
    public init() {}
    public var id: String { "convert_json_text_to_csv" }
    public var name: String { "JSON to CSV" }
    public var description: String { "Converts a JSON array of flat objects in `text` into CSV with a header row (union of keys, RFC 4180 quoting)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts a JSON array of flat objects in `text` into CSV with a header row (union of keys, RFC 4180 quoting).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let arr = AssistToolKit.parseJSON(text) as? [[String: Any]] else { return AssistToolKit.invalid("Expected a JSON array of objects.") }
        var keys: [String] = []; for o in arr { for k in o.keys.sorted() where !keys.contains(k) { keys.append(k) } }
        func q(_ v: Any?) -> String { guard let v, !(v is NSNull) else { return "" }; let s = "\(v)"; return s.contains(",") || s.contains("\"") || s.contains("\n") ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s }
        var lines = [keys.map { q($0) }.joined(separator: ",")]
        for o in arr { lines.append(keys.map { q(o[$0]) }.joined(separator: ",")) }
        return .success(AssistToolKit.output(lines.joined(separator: "\n")), data: ["rows": String(arr.count)])
    }
}


public struct XKJwtDecodeTool: AssistTool {
    public init() {}
    public var id: String { "jwt_decode" }
    public var name: String { "JWT Decode" }
    public var description: String { "Decodes (without verifying) a JSON Web Token's header and payload, and explains exp/iat/nbf claims relative to now. Never use this as authentication." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Decodes (without verifying) a JSON Web Token's header and payload, and explains exp/iat/nbf claims relative to now. Never use this as authentication.", properties: ["token": JSONSchema(type: "string", description: "The JWT string.")], required: ["token"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let token = AssistToolKit.string(input, "token")?.trimmingCharacters(in: .whitespacesAndNewlines) else { return AssistToolKit.missing("token") }
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return AssistToolKit.invalid("A JWT has three dot-separated segments.") }
        func dec(_ s: String) -> Any? { var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"); while b.count % 4 != 0 { b += "=" }; return Data(base64Encoded: b).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
        guard let h = dec(parts[0]), let p = dec(parts[1]) else { return AssistToolKit.invalid("Header or payload is not Base64URL JSON.") }
        var notes: [String] = []
        if let d = p as? [String: Any] { for k in ["exp", "iat", "nbf"] { if let t = (d[k] as? NSNumber)?.doubleValue { let date = Date(timeIntervalSince1970: t); notes.append("\(k): \(ISO8601DateFormatter().string(from: date))\(k == "exp" ? (date < Date() ? " (EXPIRED)" : " (valid)") : "")") } } }
        return .success("header:\n\(AssistToolKit.prettyJSON(h) ?? "")\npayload:\n\(AssistToolKit.prettyJSON(p) ?? "")\n\(notes.joined(separator: "\n"))\nsignature: \(parts.count > 2 ? "present (NOT verified)" : "absent")")
    }
}


public struct XKMarkdownTocTool: AssistTool {
    public init() {}
    public var id: String { "markdown_toc" }
    public var name: String { "Markdown Table of Contents" }
    public var description: String { "Generates a nested Markdown table of contents with GitHub-style anchors from the headings in `text` (code fences ignored)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Generates a nested Markdown table of contents with GitHub-style anchors from the headings in `text` (code fences ignored).", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        var out: [String] = []; var fence = false; var used: [String: Int] = [:]
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") { fence.toggle(); continue }
            guard !fence, line.hasPrefix("#") else { continue }
            let level = line.prefix(while: { $0 == "#" }).count
            guard level <= 6 else { continue }
            let title = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            var anchor = title.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }.replacingOccurrences(of: " ", with: "-")
            if let n = used[anchor] { used[anchor] = n + 1; anchor += "-\(n + 1)" } else { used[anchor] = 0 }
            out.append(String(repeating: "  ", count: level - 1) + "- [\(title)](#\(anchor))")
        }
        return .success(out.isEmpty ? "No headings found." : out.joined(separator: "\n"), data: ["headings": String(out.count)])
    }
}


public struct XKCsvToMarkdownTableTool: AssistTool {
    public init() {}
    public var id: String { "csv_to_markdown_table" }
    public var name: String { "CSV to Markdown Table" }
    public var description: String { "Converts simple CSV/TSV `text` (first row = header) into a GitHub-flavored Markdown table." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Converts simple CSV/TSV `text` (first row = header) into a GitHub-flavored Markdown table.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "delimiter": JSONSchema(type: "string", description: "Delimiter (default ',').")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let delim: Character = text.contains("\t") ? "\t" : Character(AssistToolKit.string(input, "delimiter") ?? ",")
        let rows = text.components(separatedBy: .newlines).filter { !$0.isEmpty }.map { $0.split(separator: delim, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "|", with: "\\|") } }
        guard let header = rows.first else { return AssistToolKit.invalid("No rows.") }
        var out = ["| " + header.joined(separator: " | ") + " |", "|" + Array(repeating: " --- |", count: header.count).joined()]
        for r in rows.dropFirst() { out.append("| " + (0..<header.count).map { $0 < r.count ? r[$0] : "" }.joined(separator: " | ") + " |") }
        return .success(out.joined(separator: "\n"))
    }
}


public struct XKTextFilterLinesTool: AssistTool {
    public init() {}
    public var id: String { "text_filter_lines" }
    public var name: String { "Filter Lines" }
    public var description: String { "Keeps (or with `invert` removes) lines of `text` matching regex `pattern`; returns matching lines with original line numbers." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Keeps (or with `invert` removes) lines of `text` matching regex `pattern`; returns matching lines with original line numbers.", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "pattern": JSONSchema(type: "string", description: "Regex."), "invert": JSONSchema(type: "boolean", description: "Exclude matches instead.")], required: ["text", "pattern"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        guard let p = AssistToolKit.string(input, "pattern"), let re = try? NSRegularExpression(pattern: p) else { return AssistToolKit.invalid("Missing or invalid pattern.") }
        let inv = AssistToolKit.bool(input, "invert", default: false)
        var out: [String] = []
        for (i, l) in text.components(separatedBy: .newlines).enumerated() { let hit = re.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) != nil; if hit != inv { out.append("\(i + 1): \(l)") } }
        return .success(out.joined(separator: "\n"), data: ["count": String(out.count)])
    }
}


public struct XKTextExtractColumnTool: AssistTool {
    public init() {}
    public var id: String { "text_extract_column" }
    public var name: String { "Extract Column" }
    public var description: String { "Extracts column `index` (0-based) from each line of `text` split by `delimiter` (default whitespace)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Extracts column `index` (0-based) from each line of `text` split by `delimiter` (default whitespace).", properties: ["text": JSONSchema(type: "string", description: "Input text to process."), "index": JSONSchema(type: "integer", description: "0-based column."), "delimiter": JSONSchema(type: "string", description: "Delimiter (default whitespace).")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let idx = AssistToolKit.int(input, "index", default: 0)
        let d = AssistToolKit.string(input, "delimiter")
        let out = text.components(separatedBy: .newlines).compactMap { l -> String? in
            let cols = d.map { l.components(separatedBy: $0) } ?? l.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            return idx < cols.count ? cols[idx] : nil }
        return .success(out.joined(separator: "\n"), data: ["rows": String(out.count)])
    }
}


public struct XKTextNumberSummaryTool: AssistTool {
    public init() {}
    public var id: String { "text_number_summary" }
    public var name: String { "Number Summary" }
    public var description: String { "Extracts all numbers from `text` and returns count, sum, min, max, mean, median and standard deviation." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Extracts all numbers from `text` and returns count, sum, min, max, mean, median and standard deviation.", properties: ["text": JSONSchema(type: "string", description: "Input text to process.")], required: ["text"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let text = AssistToolKit.textInput(input, key: "text") else { return AssistToolKit.missing("text") }
        let re = try NSRegularExpression(pattern: "-?\\d+(?:\\.\\d+)?(?:[eE][-+]?\\d+)?")
        let ns = text as NSString
        let nums = re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { Double(ns.substring(with: $0.range)) }
        guard !nums.isEmpty else { return AssistToolKit.notFound("No numbers found.") }
        let sum = nums.reduce(0, +), mean = sum / Double(nums.count), s = nums.sorted()
        let median = s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
        let sd = (nums.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(nums.count)).squareRoot()
        return .success("count: \(nums.count)\nsum: \(sum)\nmin: \(s.first!)\nmax: \(s.last!)\nmean: \(mean)\nmedian: \(median)\nstddev: \(sd)", data: ["count": String(nums.count)])
    }
}


public struct XKUrlParseTool: AssistTool {
    public init() {}
    public var id: String { "url_parse" }
    public var name: String { "URL Parse" }
    public var description: String { "Parses `url` into scheme, user, host, port, path, query items and fragment." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Parses `url` into scheme, user, host, port, path, query items and fragment.", properties: ["url": JSONSchema(type: "string", description: "URL to parse.")], required: ["url"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let raw = AssistToolKit.string(input, "url"), let c = URLComponents(string: raw.trimmingCharacters(in: .whitespaces)) else { return AssistToolKit.invalid("Missing or malformed url.") }
        var lines = ["scheme: \(c.scheme ?? "-")", "user: \(c.user ?? "-")", "host: \(c.host ?? "-")", "port: \(c.port.map(String.init) ?? "-")", "path: \(c.path.isEmpty ? "/" : c.path)", "fragment: \(c.fragment ?? "-")"]
        for q in c.queryItems ?? [] { lines.append("query \(q.name) = \(q.value ?? "")") }
        return .success(lines.joined(separator: "\n"))
    }
}


public struct XKCronExpressionExplainTool: AssistTool {
    public init() {}
    public var id: String { "cron_expression_explain" }
    public var name: String { "Cron Expression Explain" }
    public var description: String { "Explains a 5-field cron expression (`expression`) field by field and lists the next 5 run times computed from now (local time)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Explains a 5-field cron expression (`expression`) field by field and lists the next 5 run times computed from now (local time).", properties: ["expression": JSONSchema(type: "string", description: "5-field cron expression.")], required: ["expression"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let expr = AssistToolKit.string(input, "expression") else { return AssistToolKit.missing("expression") }
        let f = expr.split(separator: " ").map(String.init)
        guard f.count == 5 else { return AssistToolKit.invalid("Expected 5 fields: minute hour day-of-month month day-of-week.") }
        func set(_ s: String, _ lo: Int, _ hi: Int) -> Set<Int>? {
            var out = Set<Int>()
            for part in s.split(separator: ",") {
                let st = part.split(separator: "/"); let step = st.count > 1 ? Int(st[1]) ?? 0 : 1
                guard step > 0 else { return nil }
                var a = lo, b = hi
                if st[0] != "*" { let r = st[0].split(separator: "-"); guard let x = Int(r[0]) else { return nil }; a = x; b = r.count > 1 ? (Int(r[1]) ?? x) : (st.count > 1 ? hi : x) }
                guard a >= lo, b <= hi, a <= b else { return nil }
                for v in stride(from: a, through: b, by: step) { out.insert(v) }
            }
            return out
        }
        let names = ["minute", "hour", "day-of-month", "month", "day-of-week"], ranges = [(0, 59), (0, 23), (1, 31), (1, 12), (0, 7)]
        var sets: [Set<Int>] = []
        for i in 0..<5 { guard let s = set(f[i], ranges[i].0, ranges[i].1) else { return AssistToolKit.invalid("Invalid \(names[i]) field '\(f[i])'.") }; sets.append(s) }
        if sets[4].contains(7) { sets[4].insert(0) }
        var lines = (0..<5).map { "\(names[$0]): \(f[$0] == "*" ? "every" : sets[$0].sorted().map(String.init).joined(separator: ","))" }
        let cal = Calendar.current; var t = cal.date(bySetting: .second, value: 0, of: Date().addingTimeInterval(60)) ?? Date()
        var runs: [String] = []; var guardCount = 0
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm EEE"
        while runs.count < 5 && guardCount < 600_000 {
            let c = cal.dateComponents([.minute, .hour, .day, .month, .weekday], from: t)
            let domAny = f[2] == "*", dowAny = f[4] == "*"
            let dayOK = (domAny && dowAny) || (!domAny && sets[2].contains(c.day!)) || (!dowAny && sets[4].contains(c.weekday! - 1)) || (domAny != dowAny && (domAny ? sets[4].contains(c.weekday! - 1) : sets[2].contains(c.day!)))
            if sets[0].contains(c.minute!) && sets[1].contains(c.hour!) && sets[3].contains(c.month!) && dayOK { runs.append(fmt.string(from: t)) }
            t = t.addingTimeInterval(60); guardCount += 1
        }
        lines.append("next runs: " + (runs.isEmpty ? "none within ~1 year" : runs.joined(separator: " | ")))
        return .success(lines.joined(separator: "\n"))
    }
}
