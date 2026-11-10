import Foundation

enum ReconstructionUtilities {
    static let cKeywords: Set<String> = [
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "inline", "int", "long", "register", "restrict", "return", "short",
        "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
        "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof",
        "_Atomic", "_Bool", "_Complex", "_Generic", "_Imaginary", "_Noreturn",
        "_Static_assert", "_Thread_local", "bool", "true", "false", "NULL",
    ]

    static func sanitizedCIdentifier(_ name: String, prefix: String = "") -> String {
        var result = ""
        for scalar in name.unicodeScalars {
            let c = Character(scalar)
            if c.isLetter || c.isNumber || c == "_" {
                result.append(c)
            } else {
                result.append("_")
            }
        }
        if result.isEmpty { result = "unnamed" }
        if let first = result.first, first.isNumber {
            result = "_" + result
        }
        if cKeywords.contains(result) {
            result += "_"
        }
        return prefix + result
    }

    static func cFunctionName(for symbolName: String) -> String {
        var name = symbolName
        if name.hasPrefix("_") && !name.hasPrefix("__") {
            name = String(name.dropFirst())
        }
        return sanitizedCIdentifier(name)
    }

    static func asmSymbolName(_ cName: String, format: BinaryFormat) -> String {
        format == .machO ? "_" + cName : cName
    }

    static func dataLabel(for address: UInt64) -> String {
        "__sc_data_\(String(address, radix: 16))"
    }

    static func pageLabel(for pageBase: UInt64) -> String {
        "__sc_page_\(String(pageBase, radix: 16))"
    }

    static func gotLabel(for importName: String) -> String {
        "__sc_got_\(sanitizedCIdentifier(importName))"
    }

    static func escapeCString(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count + 2)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\0": out += "\\0"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7f {
                    out += String(format: "\\x%02x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }

    static func byteLines(_ data: Data, perLine: Int = 16, indent: String = "    ") -> [String] {
        var lines: [String] = []
        var offset = data.startIndex
        while offset < data.endIndex {
            let end = data.index(offset, offsetBy: perLine, limitedBy: data.endIndex) ?? data.endIndex
            let chunk = data[offset..<end]
            let bytes = chunk.map { String(format: "0x%02x", $0) }.joined(separator: ", ")
            lines.append("\(indent).byte \(bytes)")
            offset = end
        }
        if lines.isEmpty {
            lines.append("\(indent).byte 0x00")
        }
        return lines
    }

    static func parseHex(_ text: String) -> UInt64? {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("0x") || t.hasPrefix("0X") { t = String(t.dropFirst(2)) }
        guard !t.isEmpty else { return nil }
        return UInt64(t, radix: 16)
    }

    static func parseSignedHex(_ text: String) -> Int64? {
        var t = text.trimmingCharacters(in: .whitespaces)
        var negative = false
        if t.hasPrefix("-") { negative = true; t = String(t.dropFirst()) }
        if t.hasPrefix("+") { t = String(t.dropFirst()) }
        guard let value = parseHex(t) else { return nil }
        return negative ? -Int64(bitPattern: value) : Int64(bitPattern: value)
    }

    static func ghidraTypeToC(_ type: String) -> String {
        let t = type.trimmingCharacters(in: .whitespaces)
        switch t {
        case "undefined", "undefined1": return "uint8_t"
        case "undefined2": return "uint16_t"
        case "undefined4": return "uint32_t"
        case "undefined8": return "uint64_t"
        case "undefined16": return "unsigned __int128"
        case "byte": return "uint8_t"
        case "word": return "uint16_t"
        case "dword": return "uint32_t"
        case "qword": return "uint64_t"
        case "char": return "char"
        case "uchar": return "unsigned char"
        case "short": return "short"
        case "ushort": return "unsigned short"
        case "int": return "int"
        case "uint": return "unsigned int"
        case "long": return "long"
        case "ulong": return "unsigned long"
        case "longlong": return "long long"
        case "ulonglong": return "unsigned long long"
        case "float": return "float"
        case "double": return "double"
        case "bool": return "bool"
        case "void": return "void"
        case "code": return "void"
        default:
            if t.hasSuffix("*") {
                return ghidraTypeToC(String(t.dropLast()).trimmingCharacters(in: .whitespaces)) + " *"
            }
            if t.hasPrefix("undefined") { return "uint8_t" }
            return t
        }
    }

    static func mapGhidraSignature(_ signature: String, functionName: String) -> (returnType: String, parameters: [String])? {
        let trimmed = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("),
              let close = trimmed.lastIndex(of: ")"), open < close else { return nil }
        let before = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        guard before.hasSuffix(functionName) || before.contains(functionName) else { return nil }
        let returnPart = before.dropLast(functionName.count).trimmingCharacters(in: .whitespaces)
        let returnType = returnPart.isEmpty ? "long" : ghidraTypeToC(returnPart)
        let paramsText = trimmed[trimmed.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        if paramsText.isEmpty || paramsText == "void" { return (returnType, []) }
        var params: [String] = []
        for (index, part) in paramsText.split(separator: ",").enumerated() {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.isEmpty { continue }
            let pieces = p.split(separator: " ").map(String.init)
            if pieces.count >= 2, let last = pieces.last, last.hasPrefix("param_") || last.hasPrefix("uParm") {
                let typeText = pieces.dropLast().joined(separator: " ")
                params.append("\(ghidraTypeToC(typeText)) param_\(index + 1)")
            } else if pieces.count >= 2 {
                params.append("\(ghidraTypeToC(pieces.dropLast().joined(separator: " "))) \(pieces.last!)")
            } else {
                params.append("\(ghidraTypeToC(p)) param_\(index + 1)")
            }
        }
        return (returnType, params)
    }
}
