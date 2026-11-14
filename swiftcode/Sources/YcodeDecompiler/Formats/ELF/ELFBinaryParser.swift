import Foundation









public struct ELFBinaryParser: BinaryParser {
    public init() {}

    public var format: BinaryFormat { .elf }

    private static let maxFileBytes: UInt64 = 2 << 30

    
    
    

    
    private enum SHT {
        static let null: UInt32 = 0
        static let progBits: UInt32 = 1
        static let symTab: UInt32 = 2
        static let strTab: UInt32 = 3
        static let rela: UInt32 = 4
        static let hash: UInt32 = 5
        static let dynamic: UInt32 = 6
        static let note: UInt32 = 7
        static let noBits: UInt32 = 8
        static let rel: UInt32 = 9
        static let dynSym: UInt32 = 11
    }

    private enum SHF {
        static let write: UInt64 = 0x1
        static let alloc: UInt64 = 0x2
        static let execInstr: UInt64 = 0x4
    }

    private enum PT {
        static let load: UInt32 = 1
        static let dynamic: UInt32 = 2
        static let interp: UInt32 = 3
        static let note: UInt32 = 4
    }

    private enum DT {
        static let needed: Int64 = 1
        static let strTab: Int64 = 5
        static let symTab: Int64 = 6
        static let strSz: Int64 = 10
        static let soname: Int64 = 14
    }

    private enum STB {
        static let local: UInt8 = 0
        static let global: UInt8 = 1
        static let weak: UInt8 = 2
    }

    private static let maxSections = 4096
    private static let maxSegments = 1024

    

    public func matches(header: Data) -> Bool {
        header.count >= 4 && header[0] == 0x7F && header[1] == 0x45
            && header[2] == 0x4C && header[3] == 0x46
    }

    public func detectSlices(url: URL) throws -> [SliceDescriptor] {
        let head = try readFileRegion(url: url, offset: 0, length: 64)
        guard head.count >= 52 else {
            throw DecompilerError.malformedBinary("file too small for an ELF header")
        }
        guard head[0] == 0x7F, head[1] == 0x45, head[2] == 0x4C, head[3] == 0x46 else {
            throw DecompilerError.malformedBinary("not an ELF file")
        }
        let klass = head[4]      
        let dataEnc = head[5]    
        guard klass == 1 || klass == 2, dataEnc == 1 || dataEnc == 2 else {
            throw DecompilerError.malformedBinary("unsupported ELF class/data encoding")
        }
        let order: FormatByteOrder = dataEnc == 1 ? .little : .big
        
        let machine = UInt16(head[18]) | UInt16(head[19]) << 8
        let machineVal = order == .big ? machine.byteSwapped : machine
        let arch = ArchitectureResolver.resolve(format: .elf,
                                                 identifier: .elfMachine(machineVal))
        let size = try fileSize(url: url)
        return [SliceDescriptor(index: 0, architecture: arch,
                                cpuIdentifier: "\(machineVal)",
                                offset: 0, size: size, name: arch.displayName)]
    }

    public func parse(url: URL, sliceIndex: Int, identity: BinaryIdentity,
                      byteProvider: @escaping @Sendable (UInt64, UInt64) throws -> Data) throws -> BinaryImage {
        _ = sliceIndex 
        let size = try fileSize(url: url)
        guard size <= Self.maxFileBytes else {
            throw DecompilerError.resourceLimitExceeded(
                "ELF file is \(size) bytes (limit \(Self.maxFileBytes))")
        }
        guard size >= 52 else {
            throw DecompilerError.malformedBinary("file too small for an ELF header")
        }
        let data = try byteProvider(0, size)

        
        guard data.count >= 16, data[0] == 0x7F, data[1] == 0x45,
              data[2] == 0x4C, data[3] == 0x46 else {
            throw DecompilerError.malformedBinary("bad ELF magic")
        }
        let is64 = data[4] == 2
        let order: FormatByteOrder = data[5] == 1 ? .little : .big
        guard data[4] == 1 || data[4] == 2, data[5] == 1 || data[5] == 2 else {
            throw DecompilerError.malformedBinary("unsupported ELF class/data encoding")
        }

        var hdr = ByteCursor(data, order: order, offset: 16)
        let eType = try hdr.u16()
        let eMachine = try hdr.u16()
        _ = try hdr.u32() 
        let eEntry = is64 ? try hdr.u64() : UInt64(try hdr.u32())
        let ePhoff = is64 ? try hdr.u64() : UInt64(try hdr.u32())
        let eShoff = is64 ? try hdr.u64() : UInt64(try hdr.u32())
        _ = try hdr.u32() 
        _ = try hdr.u16() 
        let ePhentsize = Int(try hdr.u16())
        let ePhnum = Int(try hdr.u16())
        let eShentsize = Int(try hdr.u16())
        let eShnum = Int(try hdr.u16())
        let eShstrndx = Int(try hdr.u16())

        let arch = ArchitectureResolver.resolve(format: .elf, identifier: .elfMachine(eMachine))

        
        struct Phdr {
            var type: UInt32
            var offset: UInt64
            var vaddr: UInt64
            var filesz: UInt64
            var memsz: UInt64
            var flags: UInt32
        }
        var phdrs: [Phdr] = []
        guard ePhnum <= Self.maxSegments else {
            throw DecompilerError.malformedBinary("too many program headers")
        }
        for i in 0..<ePhnum {
            var p = ByteCursor(data, order: order, offset: Int(ePhoff) + i * ePhentsize)
            let pType = try p.u32()
            let pFlags: UInt32
            let pOffset: UInt64, pVaddr: UInt64, pFilesz: UInt64, pMemsz: UInt64
            if is64 {
                pFlags = try p.u32()
                pOffset = try p.u64(); pVaddr = try p.u64()
                _ = try p.u64() 
                pFilesz = try p.u64(); pMemsz = try p.u64()
                _ = try p.u64() 
            } else {
                pOffset = UInt64(try p.u32()); pVaddr = UInt64(try p.u32())
                _ = try p.u32() 
                pFilesz = UInt64(try p.u32()); pMemsz = UInt64(try p.u32())
                pFlags = try p.u32()
                _ = try p.u32() 
            }
            phdrs.append(Phdr(type: pType, offset: pOffset, vaddr: pVaddr,
                              filesz: pFilesz, memsz: pMemsz, flags: pFlags))
        }

        
        struct Shdr {
            var name: String
            var type: UInt32
            var flags: UInt64
            var addr: UInt64
            var offset: UInt64
            var size: UInt64
            var link: UInt32
            var info: UInt32
            var entsize: UInt64
        }
        var shdrs: [Shdr] = []
        var shnum = eShnum
        var shstrndx = eShstrndx
        
        if (eShnum == 0 || eShstrndx == 0) && eShoff != 0 {
            var z = ByteCursor(data, order: order, offset: Int(eShoff))
            _ = try z.u32() 
            _ = try z.u32() 
            _ = is64 ? try z.u64() : UInt64(try z.u32()) 
            _ = is64 ? try z.u64() : UInt64(try z.u32()) 
            _ = is64 ? try z.u64() : UInt64(try z.u32()) 
            let zSize = is64 ? try z.u64() : UInt64(try z.u32())
            _ = try z.u32() 
            let zInfo = try z.u32()
            if eShnum == 0 { shnum = Int(zSize) }
            if eShstrndx == 0 { shstrndx = Int(zInfo) }
        }
        guard shnum <= Self.maxSections else {
            throw DecompilerError.malformedBinary("too many section headers")
        }
        
        var shstrData = Data()
        if shstrndx >= 0 && shstrndx < shnum && eShoff != 0 {
            var s = ByteCursor(data, order: order,
                               offset: Int(eShoff) + shstrndx * eShentsize)
            _ = try s.u32() 
            _ = try s.u32() 
            _ = is64 ? try s.u64() : UInt64(try s.u32()) 
            _ = is64 ? try s.u64() : UInt64(try s.u32()) 
            let stroff = is64 ? try s.u64() : UInt64(try s.u32())
            let strsize = is64 ? try s.u64() : UInt64(try s.u32())
            let o = Int(stroff), n = Int(strsize)
            if o >= 0, n >= 0, o + n <= data.count {
                shstrData = Data(data[o..<(o + n)])
            }
        }
        func shName(_ strx: UInt32) -> String {
            guard strx < shstrData.count else { return "" }
            var i = Int(strx)
            var bytes = [UInt8]()
            while i < shstrData.count, shstrData[i] != 0 {
                bytes.append(shstrData[i]); i += 1
            }
            return String(decoding: bytes, as: UTF8.self)
        }

        if eShoff != 0 {
            for i in 0..<shnum {
                var s = ByteCursor(data, order: order, offset: Int(eShoff) + i * eShentsize)
                let nameOff = try s.u32()
                let sType = try s.u32()
                let sFlags = is64 ? try s.u64() : UInt64(try s.u32())
                let sAddr = is64 ? try s.u64() : UInt64(try s.u32())
                let sOffset = is64 ? try s.u64() : UInt64(try s.u32())
                let sSize = is64 ? try s.u64() : UInt64(try s.u32())
                let sLink = try s.u32()
                let sInfo = try s.u32()
                if is64 { _ = try s.u64() } else { _ = try s.u32() } 
                let sEntsize = is64 ? try s.u64() : UInt64(try s.u32())
                shdrs.append(Shdr(name: shName(nameOff), type: sType, flags: sFlags,
                                  addr: sAddr, offset: sOffset, size: sSize,
                                  link: sLink, info: sInfo, entsize: sEntsize))
            }
        }

        func makeSection(_ sh: Shdr, segName: String, writable: Bool) -> BinarySectionInfo {
            BinarySectionInfo(
                name: sh.name.isEmpty ? "section_\(sh.offset)" : sh.name,
                segment: segName,
                address: DecompilerAddress(virtual: sh.addr),
                size: sh.size,
                fileOffset: sh.offset,
                flags: UInt32(truncatingIfNeeded: sh.flags),
                isExecutable: sh.flags & SHF.execInstr != 0,
                isWritable: writable || (sh.flags & SHF.write) != 0,
                containsStrings: sh.name.contains("str") || sh.name.contains("rodata"))
        }

        
        
        
        let loadPhdrs = phdrs.enumerated().filter { $0.element.type == PT.load }
        var sectionOwner = [Int?](repeating: nil, count: shdrs.count)
        var segments: [BinarySegmentInfo] = []
        var interpPath: String? = nil
        for (segIdx, pair) in loadPhdrs.enumerated() {
            let ph = pair.element
            let writable = (ph.flags & 2) != 0       
            let span = max(ph.memsz, ph.filesz)
            var secs: [BinarySectionInfo] = []
            for (si, sh) in shdrs.enumerated()
            where sh.flags & SHF.alloc != 0 && sh.size > 0 && sectionOwner[si] == nil {
                guard sh.addr >= ph.vaddr, sh.addr < ph.vaddr + span else { continue }
                sectionOwner[si] = segIdx
                secs.append(makeSection(sh, segName: "LOAD\(segIdx)", writable: writable))
            }
            segments.append(BinarySegmentInfo(
                name: "LOAD\(segIdx)", vmAddress: ph.vaddr, vmSize: ph.memsz,
                fileOffset: ph.offset, fileSize: ph.filesz,
                maxProtection: Int(ph.flags), initialProtection: Int(ph.flags),
                sections: secs))
        }
        
        
        var others: [BinarySectionInfo] = []
        for (si, sh) in shdrs.enumerated() where sh.size > 0 && sectionOwner[si] == nil {
            others.append(makeSection(sh, segName: "__NON_ALLOC",
                                      writable: (sh.flags & SHF.write) != 0))
        }
        if !others.isEmpty {
            segments.append(BinarySegmentInfo(
                name: "__NON_ALLOC", vmAddress: 0, vmSize: 0,
                fileOffset: 0, fileSize: 0,
                maxProtection: 0, initialProtection: 0, sections: others))
        }

        
        for ph in phdrs where ph.type == PT.interp {
            let o = Int(ph.offset), n = Int(ph.filesz)
            if o >= 0, n > 0, o + n <= data.count {
                interpPath = String(decoding: data[o..<(o + n)].prefix { $0 != 0 }, as: UTF8.self)
            }
        }

        
        var symbols: [BinarySymbol] = []
        var imports: [BinaryImport] = []
        var exportsList: [BinaryExport] = []
        var hasDebugInfo = false

        for sh in shdrs.enumerated() {
            let sh = sh.element
            if sh.name.hasPrefix(".debug") { hasDebugInfo = true }
            let isSymtab = sh.type == SHT.symTab || sh.type == SHT.dynSym
            guard isSymtab, sh.entsize > 0, sh.size > 0 else { continue }
            guard Int(sh.link) < shdrs.count else { continue }
            let strSh = shdrs[Int(sh.link)]
            let strOff = Int(strSh.offset), strSize = Int(strSh.size)
            guard strOff >= 0, strOff + strSize <= data.count else { continue }
            let strtab = Data(data[strOff..<(strOff + strSize)])
            func elfString(_ strx: UInt32) -> String {
                guard strx < strtab.count else { return "" }
                var i = Int(strx)
                var bytes = [UInt8]()
                while i < strtab.count, strtab[i] != 0 {
                    bytes.append(strtab[i]); i += 1
                }
                return String(decoding: bytes, as: UTF8.self)
            }
            let count = Int(sh.size / sh.entsize)
            var cur = ByteCursor(data, order: order, offset: Int(sh.offset))
            for _ in 0..<count {
                let stName = try cur.u32()
                let stInfo: UInt8
                let stShndx: UInt16
                let stValue: UInt64
                let stSize: UInt64
                if is64 {
                    stInfo = try cur.u8()
                    _ = try cur.u8() 
                    stShndx = try cur.u16()
                    stValue = try cur.u64()
                    stSize = try cur.u64()
                } else {
                    stValue = UInt64(try cur.u32())
                    stSize = UInt64(try cur.u32())
                    stInfo = try cur.u8()
                    _ = try cur.u8()
                    stShndx = try cur.u16()
                }
                let bind = stInfo >> 4
                let name = elfString(stName)
                guard !name.isEmpty else { continue } 
                let isUndef = stShndx == 0 
                let kind: BinarySymbol.Kind
                if isUndef {
                    kind = .undefined
                    imports.append(BinaryImport(name: name, library: "",
                                                address: nil, isWeak: bind == STB.weak))
                } else {
                    switch bind {
                    case STB.global: kind = .global
                    case STB.weak: kind = .global
                    default: kind = .local
                    }
                    if sh.type == SHT.dynSym, kind != .local {
                        exportsList.append(BinaryExport(
                            name: name, address: DecompilerAddress(virtual: stValue),
                            kind: .symbol))
                    }
                }
                symbols.append(BinarySymbol(
                    name: name,
                    address: isUndef ? nil : DecompilerAddress(virtual: stValue),
                    size: stSize, kind: kind,
                    source: AnalysisSource(provenance: .symbolTable,
                                           pass: sh.type == SHT.dynSym ? "elf-dynsym" : "elf-symtab")))
            }
        }

        
        var seenImports = Set<String>()
        imports = imports.filter { seenImports.insert($0.name).inserted }

        
        var dependencies: [BinaryDependency] = []
        for sh in shdrs where sh.type == SHT.dynamic {
            let count = Int(sh.size / (is64 ? 16 : 8))
            var cur = ByteCursor(data, order: order, offset: Int(sh.offset))
            var strtabAddr: UInt64? = nil
            var neededOffsets: [UInt64] = []
            for _ in 0..<count {
                let tag = is64 ? try cur.i64() : Int64(try cur.i32())
                let val = is64 ? try cur.u64() : UInt64(try cur.u32())
                if tag == DT.strTab { strtabAddr = val }
                if tag == DT.needed { neededOffsets.append(val) }
            }
            
            func vaddrToOffset(_ va: UInt64) -> UInt64? {
                for ph in phdrs where ph.type == PT.load {
                    if va >= ph.vaddr && va < ph.vaddr + ph.filesz {
                        return ph.offset + (va - ph.vaddr)
                    }
                }
                return nil
            }
            guard let strAddr = strtabAddr, let strFileOff = vaddrToOffset(strAddr) else { continue }
            let o = Int(strFileOff)
            for noff in neededOffsets {
                let pos = o + Int(noff)
                guard pos >= 0, pos < data.count else { continue }
                var c = ByteCursor(data, order: order, offset: pos)
                if let s = try? c.cstring(), !s.isEmpty {
                    dependencies.append(BinaryDependency(path: s, kind: "load"))
                }
            }
        }

        
        var buildID: String? = nil
        for sh in shdrs where sh.type == SHT.note {
            var cur = ByteCursor(data, order: order, offset: Int(sh.offset))
            let end = min(Int(sh.offset + sh.size), data.count)
            while cur.offset + 12 <= end {
                let namesz = Int(try cur.u32())
                let descsz = Int(try cur.u32())
                let ntype = try cur.u32()
                
                _ = try? cur.bytes(namesz)
                _ = try? cur.skip((4 - (namesz % 4)) % 4)
                let desc = (try? cur.bytes(descsz)) ?? Data()
                _ = try? cur.skip((4 - (descsz % 4)) % 4)
                if ntype == 3, descsz > 0 { 
                    buildID = desc.map { String(format: "%02x", $0) }.joined()
                    break
                }
            }
        }

        
        let entryPoint: DecompilerAddress? = eEntry != 0
            ? DecompilerAddress(virtual: eEntry) : nil

        let fileType: String = switch eType {
        case 1: "relocatable"
        case 2: "execute"
        case 3: "shared"
        case 4: "core"
        default: "elf-\(eType)"
        }

        var notes: [String] = []
        if let interp = interpPath { notes.append("interpreter: \(interp)") }
        let codeSigInfo = notes.isEmpty ? nil : notes.joined(separator: "; ")

        var ident = identity
        ident.binaryUUID = buildID
        ident.architecture = arch

        return BinaryImage(
            identity: ident, format: .elf, architecture: arch,
            cpuIdentifier: "\(eMachine)", fileType: fileType,
            entryPoint: entryPoint, segments: segments,
            imports: imports, exports: exportsList, dependencies: dependencies,
            symbols: symbols, strings: [], functionStarts: [],
            isEncrypted: false, isSigned: false, entitlements: nil,
            codeSignatureInfo: codeSigInfo,
            buildVersion: nil, minOSVersion: nil,
            hasDebugInfo: hasDebugInfo,
            byteCount: Int64(size), byteProvider: byteProvider)
    }
}
