import Foundation

public struct InterfaceShim: Sendable {
    public var functionAddress: UInt64
    public var line: Int
    public var recoveredName: String
    public var shimSymbol: String
    public var quality: ReconstructionQuality

    public init(functionAddress: UInt64, line: Int, recoveredName: String,
                shimSymbol: String, quality: ReconstructionQuality) {
        self.functionAddress = functionAddress
        self.line = line
        self.recoveredName = recoveredName
        self.shimSymbol = shimSymbol
        self.quality = quality
    }
}

public struct InterfaceOmission: Sendable {
    public var functionAddress: UInt64
    public var recoveredName: String
    public var quality: ReconstructionQuality
    public var reason: String

    public init(functionAddress: UInt64, recoveredName: String,
                quality: ReconstructionQuality, reason: String) {
        self.functionAddress = functionAddress
        self.recoveredName = recoveredName
        self.quality = quality
        self.reason = reason
    }
}

public struct InterfaceEmission: Sendable {
    public var file: GeneratedSourceFile
    public var shims: [InterfaceShim]
    public var omitted: [InterfaceOmission]

    public init(file: GeneratedSourceFile, shims: [InterfaceShim], omitted: [InterfaceOmission]) {
        self.file = file
        self.shims = shims
        self.omitted = omitted
    }
}

public protocol InterfaceEmitter: Sendable {
    var language: SourceLanguage { get }
    func emit(libraryName: String, records: [ReconstructionRecord]) -> InterfaceEmission
}

public enum InterfaceEmitterRegistry {
    public static func emitter(for language: SourceLanguage) -> (any InterfaceEmitter)? {
        switch language {
        case .swift:
            return SwiftInterfaceEmitter()
        case .rust:
            return RustInterfaceEmitter()
        default:
            return nil
        }
    }

    public static func fileQuality(for shims: [InterfaceShim]) -> ReconstructionQuality {
        var rank: [ReconstructionQuality: Int] = [:]
        rank[.recovered] = 0
        rank[.reconstructed] = 1
        rank[.inferred] = 2
        rank[.partial] = 3
        rank[.unresolved] = 4
        rank[.unsupported] = 5
        let worst = shims.map(\.quality).max { (rank[$0] ?? 5) < (rank[$1] ?? 5) }
        return worst ?? .unresolved
    }
}

enum InterfaceSignatureParsing {
    struct ParsedParameter {
        var type: String
        var name: String
    }

    struct ParsedSignature {
        var returnType: String
        var parameters: [ParsedParameter]
    }

    static func parse(record: ReconstructionRecord) -> ParsedSignature? {
        if let returnType = record.returnType {
            var params: [ParsedParameter] = []
            for (index, text) in record.parameters.enumerated() {
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                if trimmed == "void" { continue }
                guard let param = parseParameter(trimmed, index: index) else { return nil }
                params.append(param)
            }
            return ParsedSignature(returnType: returnType, parameters: params)
        }
        guard let signature = record.signature else { return nil }
        return parseSignatureString(signature)
    }

    static func parseParameter(_ text: String, index: Int) -> ParsedParameter? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let tokens = trimmed.split(separator: " ").map(String.init)
        if tokens.count == 1 {
            let token = tokens[0]
            if token == "void" || token.hasPrefix("*") { return nil }
            return ParsedParameter(type: token, name: "param_\(index + 1)")
        }
        var nameToken = tokens.last ?? ""
        var starCount = 0
        while nameToken.hasPrefix("*") {
            starCount += 1
            nameToken = String(nameToken.dropFirst())
        }
        guard !nameToken.isEmpty else { return nil }
        var type = tokens.dropLast().joined(separator: " ")
        if starCount > 0 {
            type += " " + String(repeating: "*", count: starCount)
        }
        return ParsedParameter(type: type, name: nameToken)
    }

    static func parseSignatureString(_ signature: String) -> ParsedSignature? {
        let trimmed = signature.trimmingCharacters(in: .whitespaces)
        guard let open = trimmed.firstIndex(of: "("),
              let close = trimmed.lastIndex(of: ")"), open < close else { return nil }
        let before = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        let beforeTokens = before.split(separator: " ").map(String.init)
        guard beforeTokens.count >= 2 else { return nil }
        let returnType = beforeTokens.dropLast().joined(separator: " ")
        guard !returnType.isEmpty else { return nil }
        let paramsText = trimmed[trimmed.index(after: open)..<close]
            .trimmingCharacters(in: .whitespaces)
        if paramsText.isEmpty || paramsText == "void" {
            return ParsedSignature(returnType: returnType, parameters: [])
        }
        var params: [ParsedParameter] = []
        for (index, part) in paramsText.split(separator: ",").enumerated() {
            let text = part.trimmingCharacters(in: .whitespaces)
            if text.isEmpty || text == "void" { continue }
            guard let param = parseParameter(text, index: index) else { return nil }
            params.append(param)
        }
        return ParsedSignature(returnType: returnType, parameters: params)
    }

    static func splitCType(_ type: String) -> (base: String, pointerDepth: Int, isConst: Bool) {
        var tokens = type.split(separator: " ").map(String.init)
        var isConst = false
        tokens = tokens.filter { token in
            if token == "const" {
                isConst = true
                return false
            }
            return true
        }
        var joined = tokens.joined(separator: " ")
        var depth = 0
        while true {
            let trimmed = joined.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("*") {
                depth += 1
                joined = String(trimmed.dropLast())
            } else {
                joined = trimmed
                break
            }
        }
        return (joined, depth, isConst)
    }
}
