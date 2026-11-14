import Foundation









public struct PEBinaryParser: BinaryParser {
    public init() {}

    public var format: BinaryFormat { .pe }

    private static let maxFileBytes: UInt64 = 2 << 30
    private static let maxSections = 4096

    
    private enum Dir {
        static let export: Int = 0
        static let importTable: Int = 1
        static let resource: Int = 2
        static let exception: Int = 3
        static let security: Int = 4
        static let basereloc: Int = 5
        static let debug: Int = 6
        static let tls: Int = 9
        static let loadConfig: Int = 10
        static let boundImport: Int = 11
        static let iat: Int = 12
        static let delayImport: Int = 13
        static let comDescriptor: Int = 14
    }

    private struct Section {
        var name: String
        var virtualSize: UInt32
        var virtualAddress: UInt32   
        var sizeOfRawData: UInt32
        var pointerToRawData: UInt32 
        var characteristics: UInt32
    }

    

    public func matches(header: Data) -> Bool {
        guard header.count >= 2, header[0] == 0x4D, header[1] == 0x5A else { return false }
        
        guard header.count >= 0x40 else { return true } 
        let peOff = Int(header.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 0x3C, as: UInt32.self)
        })
        if peOff >= 0, peOff + 4 <= header.count {
            return header[peOff] == 0x50 && header[peOff + 1] == 0x45
                && header[peOff + 2] == 0 && header[peOff + 3] == 0
        }
        
        
        return true
    }

    public func detectSlices(url: URL) throws -> [SliceDescriptor] {
        let head = try readFileRegion(url: url, offset: 0, length: 4096)
        guard head.count >= 0x40 else {
            throw DecompilerError.malformedBinary("file too small for a PE header")
        }
        guard head[0] == 0x4D, head[1] == 0x5A else {
            throw DecompilerError.malformedBinary("missing MZ signature")
        }
        let peOff = Int(head.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 0x3C, as: UInt32.self)
        })
        guard peOff >= 0, peOff + 4 <= head.count,
              head[peOff] == 0x50, head[peOff + 1] == 0x45,
              head[peOff + 2] == 0, head[peOff + 3] == 0 else {
            throw DecompilerError.malformedBinary("missing PE signature")
        }
        
        let machine = UInt16(head[peOff + 4]) | UInt16(head[peOff + 5]) << 8
        let arch = ArchitectureResolver.resolve(format: .pe,
                                                 identifier: .peMachine(machine))
        let size = try fileSize(url: url)
        return [SliceDescriptor(index: 0, architecture: arch,
                                cpuIdentifier: "\(machine)",
                                offset: 0, size: size, name: arch.displayName)]
    }

    public func parse(url: URL, sliceIndex: Int, identity: BinaryIdentity,
                      byteProvider: @escaping @Sendable (UInt64, UInt64) throws -> Data) throws -> BinaryImage {
        _ = sliceIndex
        let size = try fileSize(url: url)
        guard size <= Self.maxFileBytes else {
            throw DecompilerError.resourceLimitExceeded(
                "PE file is \(size) bytes (limit \(Self.maxFileBytes))")
        }
        guard size >= 0x40 else {
            throw DecompilerError.malformedBinary("file too small for a PE header")
        }
        let data = try byteProvider(0, size)

        
        guard data.count >= 0x40, data[0] == 0x4D, data[1] == 0x5A else {
            throw DecompilerError.malformedBinary("missing MZ signature")
        }
        let peOff = Int(data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 0x3C, as: UInt32.self)
        })
        guard peOff >= 0, peOff + 24 <= data.count,
              data[peOff] == 0x50, data[peOff + 1] == 0x45,
              data[peOff + 2] == 0, data[peOff + 3] == 0 else {
            throw DecompilerError.malformedBinary("missing PE\\0\\0 signature")
        }

        
        var coff = ByteCursor(data, order: .little, offset: peOff + 4)
        let machine = try coff.u16()
        let numberOfSections = Int(try coff.u16())
        _ = try coff.u32() 
        _ = try coff.u32() 
        _ = try coff.u32() 
        let sizeOfOptionalHeader = Int(try coff.u16())
        let characteristics = try coff.u16()

        guard numberOfSections <= Self.maxSections else {
            throw DecompilerError.malformedBinary("too many PE sections")
        }

        
        let optStart = coff.offset
        guard optStart + sizeOfOptionalHeader <= data.count else {
            throw DecompilerError.malformedBinary("optional header out of range")
        }
        var opt = ByteCursor(data, order: .little, offset: optStart)
        let magic = try opt.u16()
        let is64: Bool
        switch magic {
        case 0x10B: is64 = false 
        case 0x20B: is64 = true  
        default: throw DecompilerError.malformedBinary("unknown optional header magic 0x\(String(magic, radix: 16))")
        }
        _ = try opt.u8(); _ = try opt.u8() 
        _ = try opt.u32(); _ = try opt.u32(); _ = try opt.u32() 
        let addressOfEntryPoint = try opt.u32()
        _ = try opt.u32() 
        if !is64 { _ = try opt.u32() } 
        let imageBase: UInt64 = is64 ? try opt.u64() : UInt64(try opt.u32())
        _ = try opt.u32() 
        _ = try opt.u32() 
        
        let dirOffsetFromOptStart = is64 ? 112 : 96
        var dirCur = ByteCursor(data, order: .little,
                                offset: optStart + dirOffsetFromOptStart)
        var directories = [(rva: UInt32, size: UInt32)](repeating: (0, 0), count: 16)
        for i in 0..<16 {
            directories[i] = (try dirCur.u32(), try dirCur.u32())
        }

        
        var sections: [Section] = []
        var secCur = ByteCursor(data, order: .little,
                                offset: optStart + sizeOfOptionalHeader)
        for _ in 0..<numberOfSections {
            let nameBytes = try secCur.bytes(8)
            let name = ByteCursor.fixedString(nameBytes)
            let vsize = try secCur.u32()
            let vaddr = try secCur.u32()
            let rawSize = try secCur.u32()
            let rawPtr = try secCur.u32()
            _ = try secCur.u32() 
            _ = try secCur.u32() 
            _ = try secCur.u16() 
            _ = try secCur.u16() 
            let chars = try secCur.u32()
            sections.append(Section(name: name, virtualSize: vsize,
                                    virtualAddress: vaddr, sizeOfRawData: rawSize,
                                    pointerToRawData: rawPtr, characteristics: chars))
        }

        
        func rvaToOffset(_ rva: UInt32) -> UInt64? {
            for s in sections {
                let span = max(s.virtualSize, s.sizeOfRawData)
                if rva >= s.virtualAddress, rva < s.virtualAddress &+ span {
                    return UInt64(s.pointerToRawData) + UInt64(rva - s.virtualAddress)
                }
            }
            return nil
        }
        func readCString(atFileOffset off: UInt64) -> String? {
            let o = Int(off)
            guard o >= 0, o < data.count else { return nil }
            var c = ByteCursor(data, order: .little, offset: o)
            return try? c.cstring()
        }
        func readAtRVA(_ rva: UInt32) -> String? {
            guard let off = rvaToOffset(rva) else { return nil }
            return readCString(atFileOffset: off)
        }

        
        
        var segments: [BinarySegmentInfo] = []
        for s in sections {
            let va = imageBase + UInt64(s.virtualAddress)
            let vspan = UInt64(max(s.virtualSize, s.sizeOfRawData))
            let executable = (s.characteristics & 0x2000_0000) != 0 
            let writable = (s.characteristics & 0x8000_0000) != 0   
            let sectionInfo = BinarySectionInfo(
                name: s.name.isEmpty ? "section_\(s.virtualAddress)" : s.name,
                segment: "Image", address: DecompilerAddress(virtual: va),
                size: vspan, fileOffset: UInt64(s.pointerToRawData),
                flags: s.characteristics, isExecutable: executable,
                isWritable: writable,
                containsStrings: s.name.localizedCaseInsensitiveContains("data")
                    || s.name.localizedCaseInsensitiveContains("rdata")
                    || s.name.localizedCaseInsensitiveContains("rsrc"))
            segments.append(BinarySegmentInfo(
                name: s.name.isEmpty ? "section" : s.name,
                vmAddress: va, vmSize: vspan,
                fileOffset: UInt64(s.pointerToRawData), fileSize: UInt64(s.sizeOfRawData),
                maxProtection: executable ? 5 : (writable ? 3 : 1),
                initialProtection: executable ? 5 : (writable ? 3 : 1),
                sections: [sectionInfo]))
        }
        if segments.isEmpty {
            segments.append(BinarySegmentInfo(
                name: "Image", vmAddress: imageBase, vmSize: UInt64(size),
                fileOffset: 0, fileSize: size,
                maxProtection: 0, initialProtection: 0, sections: []))
        }

        
        var imports: [BinaryImport] = []
        var dependencies: [BinaryDependency] = []
        var depNames = Set<String>()
        let importDir = directories[Dir.importTable]
        if importDir.size > 0, let descOff = rvaToOffset(importDir.rva) {
            var d = ByteCursor(data, order: .little, offset: Int(descOff))
            
            while true {
                guard let oft = try? d.u32() else { break }
                _ = try? d.u32() 
                _ = try? d.u32() 
                guard let nameRVA = try? d.u32(),
                      let firstThunk = try? d.u32() else { break }
                if oft == 0 && nameRVA == 0 && firstThunk == 0 { break }
                guard let dllName = readAtRVA(nameRVA) else { continue }
                if depNames.insert(dllName).inserted {
                    dependencies.append(BinaryDependency(path: dllName, kind: "load"))
                }
                
                let thunkRVA = oft != 0 ? oft : firstThunk
                if let tOff = rvaToOffset(thunkRVA) {
                    var t = ByteCursor(data, order: .little, offset: Int(tOff))
                    while true {
                        guard let thunkVal: UInt64 = is64 ? try? t.u64() : try? UInt64(t.u32())
                        else { break }
                        if thunkVal == 0 { break }
                        
                        let ordinalMask: UInt64 = is64 ? 0x8000_0000_0000_0000 : 0x8000_0000
                        if thunkVal & ordinalMask != 0 { continue }
                        if let hintNameOff = rvaToOffset(UInt32(truncatingIfNeeded: thunkVal)) {
                            var h = ByteCursor(data, order: .little, offset: Int(hintNameOff))
                            _ = try? h.u16() 
                            if let fnName = try? h.cstring(), !fnName.isEmpty {
                                imports.append(BinaryImport(name: fnName, library: dllName,
                                                            address: nil, isWeak: false))
                            }
                        }
                    }
                }
            }
        }

        
        var exports: [BinaryExport] = []
        let exportDir = directories[Dir.export]
        if exportDir.size > 0, let eOff = rvaToOffset(exportDir.rva) {
            var e = ByteCursor(data, order: .little, offset: Int(eOff))
            _ = try e.u32(); _ = try e.u32(); _ = try e.u16(); _ = try e.u16()
            _ = try e.u32() 
            _ = try e.u32() 
            let numFuncs = Int(try e.u32())
            let numNames = Int(try e.u32())
            let funcsRVA = try e.u32()
            let namesRVA = try e.u32()
            let ordsRVA = try e.u32()
            if let fOff = rvaToOffset(funcsRVA),
               let nOff = rvaToOffset(namesRVA),
               let oOff = rvaToOffset(ordsRVA) {
                var funcs = ByteCursor(data, order: .little, offset: Int(fOff))
                var funcRVAs = [UInt32]()
                for _ in 0..<numFuncs { funcRVAs.append((try? funcs.u32()) ?? 0) }
                var names = ByteCursor(data, order: .little, offset: Int(nOff))
                var nameRVAs = [UInt32]()
                for _ in 0..<numNames { nameRVAs.append((try? names.u32()) ?? 0) }
                var ords = ByteCursor(data, order: .little, offset: Int(oOff))
                for i in 0..<numNames {
                    guard let ord = try? ords.u16(), Int(ord) < funcRVAs.count else { continue }
                    guard let nameStr = readAtRVA(nameRVAs[i]) else { continue }
                    let rva = funcRVAs[Int(ord)]
                    exports.append(BinaryExport(
                        name: nameStr,
                        address: DecompilerAddress(virtual: imageBase + UInt64(rva)),
                        kind: .symbol))
                }
            }
        }

        
        var isSigned = false
        var sigNote: String? = nil
        let secDir = directories[Dir.security]
        if secDir.size > 0 {
            isSigned = true
            sigNote = "PKCS#7 signature, \(secDir.size) bytes"
        }

        
        var hasDebugInfo = false
        var pdbNote: String? = nil
        let debugDir = directories[Dir.debug]
        if debugDir.size > 0, let dOff = rvaToOffset(debugDir.rva) {
            hasDebugInfo = true
            
            let entryCount = Int(debugDir.size) / 28
            var d = ByteCursor(data, order: .little, offset: Int(dOff))
            for _ in 0..<entryCount {
                _ = try d.u32(); _ = try d.u32() 
                _ = try d.u16(); _ = try d.u16() 
                let dtype = try d.u32()
                let dataSize = try d.u32()
                _ = try d.u32() 
                let rawPtr = try d.u32()
                if dtype == 2, dataSize >= 4 {
                    let o = Int(rawPtr)
                    if o >= 0, o + Int(dataSize) <= data.count {
                        
                        if data[o] == 0x52, data[o+1] == 0x53, data[o+2] == 0x44, data[o+3] == 0x53 {
                            var p = ByteCursor(data, order: .little, offset: o + 24)
                            if let path = try? p.cstring(), !path.isEmpty {
                                pdbNote = "PDB: \(path)"
                            }
                        }
                    }
                }
            }
        }

        var notes: [String] = []
        if let s = sigNote { notes.append(s) }
        if let p = pdbNote { notes.append(p) }

        let arch = ArchitectureResolver.resolve(format: .pe,
                                                 identifier: .peMachine(machine))
        let entryPoint: DecompilerAddress? = addressOfEntryPoint != 0
            ? DecompilerAddress(virtual: imageBase + UInt64(addressOfEntryPoint)) : nil
        
        let fileType = (characteristics & 0x2000) != 0 ? "dll" : "exe"

        var ident = identity
        ident.architecture = arch

        return BinaryImage(
            identity: ident, format: .pe, architecture: arch,
            cpuIdentifier: "\(machine)", fileType: fileType,
            entryPoint: entryPoint, segments: segments,
            imports: imports, exports: exports, dependencies: dependencies,
            symbols: [], strings: [], functionStarts: [],
            isEncrypted: false, isSigned: isSigned, entitlements: nil,
            codeSignatureInfo: notes.isEmpty ? nil : notes.joined(separator: "; "),
            buildVersion: nil, minOSVersion: nil,
            hasDebugInfo: hasDebugInfo,
            byteCount: Int64(size), byteProvider: byteProvider)
    }
}
