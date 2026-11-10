import Foundation

/// Content-addressed on-disk cache for expensive analysis results
/// (disassembly listings, pseudocode, control-flow graphs).
///
/// Cache identity always includes the binary content hash, so results
/// produced for one binary are never reused for a different binary even
/// when backend id/version and configuration match.
///
/// Layout under `<project cacheDir>`:
///   Disassembly/<key>.bin     — JSON-encoded `[Instruction]` payload
///   Decompilation/<key>.json  — JSON-encoded pseudocode entries
///   Graphs/<key>.json         — JSON-encoded basic-block graph payloads
///
/// Hashing uses FNV-1a (64-bit) over the identity material. This is a
/// cache key, not a security digest — collisions only cost a cache miss
/// recomputation at worst, and the binary hash prefix is stored verbatim
/// in the key so `invalidate(binaryHash:)` can find every entry.
public actor CacheManager {
    /// Which cache bucket a key belongs to.
    public enum CacheKind: String, Sendable, CaseIterable {
        case disassembly, decompilation, graphs

        var directoryName: String {
            switch self {
            case .disassembly: return "Disassembly"
            case .decompilation: return "Decompilation"
            case .graphs: return "Graphs"
            }
        }
        var fileExtension: String {
            switch self {
            case .disassembly: return "bin"
            case .decompilation, .graphs: return "json"
            }
        }
    }

    private let root: URL
    private let fileManager = FileManager.default

    /// Create a cache rooted at an arbitrary directory.
    public init(cacheDirectory: URL) {
        self.root = cacheDirectory
    }

    /// Create a cache rooted at a `.scdecomp` project's `Cache/` directory.
    public init(project: DecompilerProject) {
        self.init(cacheDirectory: project.cacheDir)
    }

    // MARK: - Key derivation

    /// Deterministic cache key. `binaryHash` MUST be the content hash of
    /// the binary (e.g. `BinaryIdentity.sha256`) so stale results are
    /// never served after the binary changes.
    public static func cacheKey(binaryHash: String, sliceIndex: Int,
                               backendID: String, backendVersion: String?,
                               configFingerprint: String) -> String {
        let material = "\(binaryHash)|\(sliceIndex)|\(backendID)|\(backendVersion ?? "")|\(configFingerprint)"
        let digest = fnv1a64(material)
        // The binary-hash prefix is embedded verbatim so invalidation can
        // locate every entry produced for that binary without an index.
        return "\(binaryHash.prefix(16))-\(digest)"
    }

    /// FNV-1a 64-bit hash, rendered as 16 lowercase hex characters.
    public static func fnv1a64(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16, uppercase: false)
            .leftPad(toLength: 16, withPad: "0")
    }

    /// Convenience fingerprint for an analysis configuration.
    public static func configFingerprint(_ configuration: AnalysisConfiguration) -> String {
        let material = "\(configuration.autoAnalyze)|\(configuration.maxBulkDecompileFunctions)|" +
            "\(configuration.extractStrings)|\(configuration.buildReferences)|" +
            "\(configuration.preferredDecompilerID ?? "")|\(configuration.preferredDisassemblerID ?? "")|" +
            "\(configuration.engineTimeoutSeconds)"
        return fnv1a64(material)
    }

    // MARK: - Disassembly cache

    public func cachedDisassembly(key: String) -> [Instruction]? {
        read(kind: .disassembly, key: key, as: [Instruction].self)
    }

    public func storeDisassembly(_ instructions: [Instruction], key: String) throws {
        try write(kind: .disassembly, key: key, value: instructions)
    }

    // MARK: - Pseudocode cache

    /// Returns cached decompilation results keyed by function address.
    public func cachedPseudocode(key: String) -> [DecompilationResult]? {
        guard let entries: [PseudocodeCacheEntry] = read(kind: .decompilation, key: key,
                                                       as: [PseudocodeCacheEntry].self) else { return nil }
        var out: [DecompilationResult] = []
        out.reserveCapacity(entries.count)
        for e in entries { out.append(e.result) }
        return out
    }

    public func storePseudocode(_ results: [DecompilationResult], key: String) throws {
        try write(kind: .decompilation, key: key,
                  value: results.map(PseudocodeCacheEntry.init))
    }

    /// Store a single pseudocode result under `key` (replaces prior content).
    public func storePseudocode(_ result: DecompilationResult, key: String) throws {
        try storePseudocode([result], key: key)
    }

    // MARK: - Graph cache

    public func cachedGraphData(key: String) -> [GraphCachePayload]? {
        read(kind: .graphs, key: key, as: [GraphCachePayload].self)
    }

    public func storeGraphData(_ payloads: [GraphCachePayload], key: String) throws {
        try write(kind: .graphs, key: key, value: payloads)
    }

    /// Store one function's basic-block graph.
    public func storeGraphData(functionAddress: DecompilerAddress,
                               blocks: [BasicBlock], key: String) throws {
        try storeGraphData([GraphCachePayload(functionAddress: functionAddress, blocks: blocks)], key: key)
    }

    // MARK: - Invalidation & pruning

    /// Remove every cache entry produced for `binaryHash` (any slice,
    /// backend, version or configuration). Safe to call repeatedly.
    @discardableResult
    public func invalidate(binaryHash: String) -> Int {
        let prefix = "\(binaryHash.prefix(16))-"
        var removed = 0
        for kind in CacheKind.allCases {
            let dir = directory(for: kind)
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir.path) else { continue }
            for file in files where file.hasPrefix(prefix) {
                let url = dir.appendingPathComponent(file)
                if (try? fileManager.removeItem(at: url)) != nil { removed += 1 }
            }
        }
        return removed
    }

    /// Remove all cache entries (e.g. on project close or cache reset).
    @discardableResult
    public func invalidateAll() -> Int {
        var removed = 0
        for kind in CacheKind.allCases {
            let dir = directory(for: kind)
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir.path) else { continue }
            for file in files {
                if (try? fileManager.removeItem(at: dir.appendingPathComponent(file))) != nil {
                    removed += 1
                }
            }
        }
        return removed
    }

    /// Total on-disk size of the cache, in bytes.
    public func totalSize() -> Int64 {
        var total: Int64 = 0
        for kind in CacheKind.allCases {
            let dir = directory(for: kind)
            guard let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey])
            else { continue }
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    /// Delete oldest entries (by modification date) until the cache is at
    /// or below `maxBytes`. Returns the number of files removed.
    @discardableResult
    public func prune(maxBytes: Int64) -> Int {
        struct Entry { let url: URL; let modified: Date; let size: Int64 }
        var entries: [Entry] = []
        var total: Int64 = 0
        for kind in CacheKind.allCases {
            let dir = directory(for: kind)
            guard let files = try? fileManager.contentsOfDirectory(at: dir,
                                                                   includingPropertiesForKeys:
                                                                    [.contentModificationDateKey, .fileSizeKey])
            else { continue }
            for url in files {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let size = Int64(values?.fileSize ?? 0)
                entries.append(Entry(url: url,
                                     modified: values?.contentModificationDate ?? .distantPast,
                                     size: size))
                total += size
            }
        }
        guard total > maxBytes else { return 0 }
        entries.sort { $0.modified < $1.modified }
        var removed = 0
        for entry in entries where total > maxBytes {
            if (try? fileManager.removeItem(at: entry.url)) != nil {
                total -= entry.size
                removed += 1
            }
        }
        return removed
    }

    // MARK: - Internals

    private func directory(for kind: CacheKind) -> URL {
        let dir = root.appendingPathComponent(kind.directoryName, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(kind: CacheKind, key: String) -> URL {
        directory(for: kind).appendingPathComponent("\(key).\(kind.fileExtension)")
    }

    private func read<T: Decodable>(kind: CacheKind, key: String, as type: T.Type) -> T? {
        let url = fileURL(kind: kind, key: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.decompiler.decode(T.self, from: data)
    }

    private func write<T: Encodable>(kind: CacheKind, key: String, value: T) throws {
        let data = try JSONEncoder.decompiler.encode(value)
        try data.write(to: fileURL(kind: kind, key: key), options: .atomic)
    }
}

/// One function's cached basic-block graph.
public struct GraphCachePayload: Codable, Sendable, Hashable {
    public var functionAddress: DecompilerAddress
    public var blocks: [BasicBlock]

    public init(functionAddress: DecompilerAddress, blocks: [BasicBlock]) {
        self.functionAddress = functionAddress
        self.blocks = blocks
    }
}

/// Codable mirror of `DecompilationResult` (which is Sendable but not
/// Codable) used only for cache serialization. `addressLineMap` keys are
/// stored as hex strings and converted back on read.
struct PseudocodeCacheEntry: Codable, Sendable {
    var functionAddress: DecompilerAddress
    var functionName: String
    var pseudocode: String
    var signature: String?
    var parameters: [String]
    var returnType: String?
    var localVariables: [String]
    var addressLineMap: [String: Int]
    var warnings: [String]
    var engineID: String
    var engineVersion: String?
    var rawBackendOutput: String?

    init(_ result: DecompilationResult) {
        functionAddress = result.functionAddress
        functionName = result.functionName
        pseudocode = result.pseudocode
        signature = result.signature
        parameters = result.parameters
        returnType = result.returnType
        localVariables = result.localVariables
        addressLineMap = result.addressLineMap.reduce(into: [:]) {
            $0[String($1.key, radix: 16)] = $1.value
        }
        warnings = result.warnings
        engineID = result.engineID
        engineVersion = result.engineVersion
        rawBackendOutput = result.rawBackendOutput
    }

    var result: DecompilationResult {
        DecompilationResult(
            functionAddress: functionAddress,
            functionName: functionName,
            pseudocode: pseudocode,
            signature: signature,
            parameters: parameters,
            returnType: returnType,
            localVariables: localVariables,
            addressLineMap: addressLineMap.reduce(into: [:]) {
                if let value = UInt64($1.key, radix: 16) { $0[value] = $1.value }
            },
            warnings: warnings,
            engineID: engineID,
            engineVersion: engineVersion,
            rawBackendOutput: rawBackendOutput)
    }
}
