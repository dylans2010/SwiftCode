import Foundation



enum DecompileAssistToolSupport {

    

    static func string(_ args: [String: Any], _ key: String) -> String? {
        guard let v = args[key] else { return nil }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    static func int(_ args: [String: Any], _ key: String, fallback def: Int? = nil) -> Int? {
        guard let v = args[key] else { return def }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) }
        return def
    }

    static func bool(_ args: [String: Any], _ key: String, fallback def: Bool = false) -> Bool {
        guard let v = args[key] else { return def }
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        if let s = v as? String { return s.lowercased() == "true" || s == "1" }
        return def
    }

    
    
    static func address(_ args: [String: Any], keys: [String] = ["address"]) -> DecompilerAddress? {
        for key in keys {
            if let raw = string(args, key), let addr = DecompilerAddress.parse(raw) {
                return addr
            }
        }
        return nil
    }

    static func requireAddress(_ args: [String: Any], keys: [String] = ["address"],
                               tool: String) throws -> DecompilerAddress {
        guard let addr = address(args, keys: keys) else {
            throw ToolArgError.missing("\(tool) requires an address argument (\(keys.joined(separator: " or ")))")
        }
        return addr
    }

    
    static func pagination(_ args: [String: Any], defaultLimit: Int = 100) -> (offset: Int, limit: Int) {
        let offset = max(0, int(args, "offset", fallback: 0) ?? 0)
        let limit = min(1_000, max(1, int(args, "limit", fallback: defaultLimit) ?? defaultLimit))
        return (offset, limit)
    }

    

    static func encode(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{\"error\":\"failed to encode result\"}"
        }
        return text
    }

    static func success(_ pairs: [String: Any] = [:]) -> String {
        var obj = pairs
        obj["ok"] = true
        return encode(obj)
    }

    static func error(_ message: String, code: String? = nil) -> String {
        var obj: [String: Any] = ["ok": false, "error": message]
        if let code { obj["code"] = code }
        return encode(obj)
    }

    
    
    static func opt<T>(_ value: T?) -> Any {
        if let value { return value }
        return NSNull()
    }

    
    static func approvalRequired(_ tool: String) -> String {
        error("approval_required: \(tool) modifies analysis data and requires \"approved\": true in the arguments", code: "approval_required")
    }

    enum ToolArgError: Error {
        case missing(String)
    }

    

    static func functionDict(_ f: DecompilerFunction) -> [String: Any] {
        var d: [String: Any] = [
            "id": f.id,
            "address": f.address.hexString,
            "name": f.displayName,
            "original_name": opt(f.originalName),
            "kind": f.kind.rawValue,
            "size": f.size,
            "provenance": f.source.provenance.rawValue,
            "has_pseudocode": f.hasPseudocode,
            "has_disassembly": f.hasDisassembly,
            "callers": f.callers.map(\.hexString),
            "callees": f.callees.map(\.hexString),
        ]
        if let end = f.endAddress { d["end_address"] = end.hexString }
        if !f.parameters.isEmpty { d["parameters"] = f.parameters }
        if !f.localVariables.isEmpty { d["local_variables"] = f.localVariables }
        if let cc = f.callingConvention { d["calling_convention"] = cc }
        if let rt = f.returnType { d["return_type"] = rt }
        return d
    }

    static func symbolDict(_ s: BinarySymbol) -> [String: Any] {
        var d: [String: Any] = [
            "name": s.name,
            "effective_name": s.effectiveName,
            "kind": s.kind.rawValue,
            "provenance": s.source.provenance.rawValue,
            "size": s.size,
        ]
        if let a = s.address { d["address"] = a.hexString }
        if let dm = s.demangledName { d["demangled_name"] = dm }
        if let lib = s.library { d["library"] = lib }
        return d
    }

    static func stringDict(_ s: BinaryString) -> [String: Any] {
        [
            "text": s.text,
            "address": s.address.hexString,
            "file_offset": s.fileOffset,
            "encoding": s.encoding.rawValue,
            "is_referenced": s.isReferenced,
        ]
    }

    static func xrefDict(_ x: CrossReference) -> [String: Any] {
        var d: [String: Any] = [
            "source": x.source.hexString,
            "destination": x.destination.hexString,
            "kind": x.kind.rawValue,
            "provenance": x.provenance.provenance.rawValue,
        ]
        if let sf = x.sourceFunction { d["source_function"] = sf.hexString }
        if let df = x.destinationFunction { d["destination_function"] = df.hexString }
        return d
    }

    static func instructionDict(_ i: Instruction) -> [String: Any] {
        var d: [String: Any] = [
            "address": i.address.hexString,
            "mnemonic": i.mnemonic,
            "operands": i.operandText,
            "text": i.text,
            "size": i.size,
            "classification": i.classification.rawValue,
            "bytes": i.rawBytes.map { String(format: "%02x", $0) }.joined(),
        ]
        if let bt = i.branchTarget { d["branch_target"] = bt.hexString }
        if let label = i.label { d["label"] = label }
        if let comment = i.comment { d["comment"] = comment }
        return d
    }

    static func typeDict(_ t: TypeInfo) -> [String: Any] {
        var d: [String: Any] = [
            "id": t.id,
            "name": t.name,
            "kind": t.kind.rawValue,
            "provenance": t.provenance.provenance.rawValue,
        ]
        if let size = t.size { d["size"] = size }
        if let underlying = t.underlyingType { d["underlying_type"] = underlying }
        if !t.fields.isEmpty {
            d["fields"] = t.fields.map {
                ["name": $0.name, "type": $0.typeName, "offset": $0.offset]
            }
        }
        return d
    }

    static func segmentDict(_ s: BinarySegmentInfo) -> [String: Any] {
        [
            "name": s.name,
            "vm_address": String(format: "0x%llx", s.vmAddress),
            "vm_size": s.vmSize,
            "file_offset": s.fileOffset,
            "file_size": s.fileSize,
            "is_executable": s.isExecutable,
            "section_count": s.sections.count,
        ]
    }

    static func sectionDict(_ s: BinarySectionInfo) -> [String: Any] {
        [
            "name": s.name,
            "segment": s.segment,
            "address": s.address.hexString,
            "size": s.size,
            "file_offset": s.fileOffset,
            "is_executable": s.isExecutable,
            "is_writable": s.isWritable,
            "contains_strings": s.containsStrings,
        ]
    }
}
