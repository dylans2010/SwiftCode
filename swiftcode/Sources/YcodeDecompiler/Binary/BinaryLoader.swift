import Foundation

/// Loads binaries: detection → slice enumeration → canonical BinaryImage.
public struct BinaryLoader: Sendable {
    public let registry: EngineRegistry

    /// Registered format parsers, in priority order.
    public static let parsers: [any BinaryParser] = [
        MachOParser(), ELFBinaryParser(), PEBinaryParser()
    ]

    public init(registry: EngineRegistry = .shared) { self.registry = registry }

    public struct LoadedContainer: Sendable {
        public var url: URL
        public var detection: BinaryDetector.Detection
        public var slices: [SliceDescriptor]
    }

    /// Detect format and enumerate slices without fully parsing.
    public func loadContainer(at url: URL) async throws -> LoadedContainer {
        let detection = try BinaryDetector.detect(url: url)
        var parser = Self.parsers.first { $0.format == detection.format }
        if parser == nil {
            parser = Self.parsers.first { $0.matches(header: (try? headData(url)) ?? Data()) }
        }
        guard let parser else {
            throw DecompilerError.unsupportedFormat(detection.format.rawValue)
        }
        let slices = try parser.detectSlices(url: url)
        return LoadedContainer(url: url, detection: detection, slices: slices)
    }

    public func detectSlices(at url: URL) async throws -> [SliceDescriptor] {
        let container = try await loadContainer(at: url)
        return container.slices
    }

    /// Parse one slice into a canonical image.
    public func parseSlice(container: LoadedContainer, sliceIndex: Int, sourceURL: URL) async throws -> BinaryImage {
        guard let slice = container.slices.first(where: { $0.index == sliceIndex })
                ?? container.slices.first else {
            throw DecompilerError.invalidRequest("slice \(sliceIndex) not present")
        }
        let parser = Self.parsers.first { $0.format == container.detection.format }!
        let hash = (try? BinaryDetector.sha256(url: sourceURL)) ?? ""
        let size = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0
        let identity = BinaryIdentity(
            sha256: hash,
            originalFileName: sourceURL.lastPathComponent,
            originalLocation: sourceURL.path,
            fileSize: size,
            format: container.detection.format,
            architecture: slice.architecture,
            sliceIndex: slice.index,
            sliceName: slice.name)
        return try parser.parse(url: sourceURL, sliceIndex: slice.index,
                                identity: identity, byteProvider: makeByteProvider(url: sourceURL))
    }

    private func headData(_ url: URL) throws -> Data {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        return try h.read(upToCount: 64) ?? Data()
    }

    /// Random-access byte provider backed by FileHandle (bounded memory use).
    public func makeByteProvider(url: URL) -> @Sendable (UInt64, UInt64) throws -> Data {
        let path = url.path
        return { offset, length in
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: Int(length)), data.count == Int(length) else {
                throw DecompilerError.truncatedFile("read at offset \(offset) length \(length)")
            }
            return data
        }
    }
}
