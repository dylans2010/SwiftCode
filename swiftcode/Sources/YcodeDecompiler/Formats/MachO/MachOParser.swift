import Foundation












public struct MachOParser: BinaryParser {
    public init() {}

    public var format: BinaryFormat { .machO }

    

    private enum Magic {
        static let mhMagic: UInt32    = 0xFEED_FACE   
        static let mhCigam: UInt32    = 0xCEFA_EDFE   
        static let mhMagic64: UInt32  = 0xFEED_FACF   
        static let mhCigam64: UInt32  = 0xCFFA_EDFE   
        static let fatMagic: UInt32   = 0xCAFE_BABE   
        static let fatCigam: UInt32   = 0xBEBA_FECA   
        static let fatMagic64: UInt32 = 0xCAFE_BABF   
        static let fatCigam64: UInt32 = 0xBFBA_FECA
    }

    

    private enum LC {
        static let segment: UInt32        = 0x01
        static let symtab: UInt32         = 0x02
        static let dysymtab: UInt32       = 0x0B
        static let loadDylib: UInt32       = 0x0C
        static let idDylib: UInt32         = 0x0D
        static let loadDylinker: UInt32    = 0x0E
        static let segment64: UInt32       = 0x19
        static let uuid: UInt32            = 0x1B
        static let rpath: UInt32           = 0x1C | 0x8000_0000
        static let codeSignature: UInt32   = 0x1D
        static let reexportDylib: UInt32   = 0x1F | 0x8000_0000
        static let lazyLoadDylib: UInt32   = 0x20
        static let encryptionInfo: UInt32  = 0x21
        static let dyldInfo: UInt32        = 0x22
        static let dyldInfoOnly: UInt32    = 0x22 | 0x8000_0000
        static let loadUpwardDylib: UInt32 = 0x23 | 0x8000_0000
        static let loadWeakDylib: UInt32   = 0x18 | 0x8000_0000
        static let versionMinMacOSX: UInt32   = 0x24
        static let versionMinIPhoneOS: UInt32 = 0x25
        static let functionStarts: UInt32     = 0x26
        static let main: UInt32               = 0x28 | 0x8000_0000
        static let dataInCode: UInt32         = 0x29
        static let encryptionInfo64: UInt32   = 0x2C
        static let versionMinTVOS: UInt32     = 0x2F
        static let versionMinWatchOS: UInt32  = 0x30
        static let buildVersion: UInt32       = 0x32
        static let dyldExportsTrie: UInt32    = 0x33 | 0x8000_0000
        static let dyldChainedFixups: UInt32  = 0x34 | 0x8000_0000
    }

    
    private enum NList {
        static let typeMask: UInt8 = 0x0E
        static let ext: UInt8      = 0x01
        static let pext: UInt8     = 0x10
        static let undef: UInt8    = 0x00
        static let abs_: UInt8     = 0x02
        static let sect: UInt8     = 0x0E
        static let weakRefDesc: UInt16 = 0x0040 
    }

    
    private enum SAttr {
        static let pureInstructions: UInt32 = 0x8000_0000
        static let someInstructions: UInt32 = 0x0000_0400
    }

    private static let sectionStringNames: Set<String> = [
        "__cstring", "__objc_methname", "__objc_classname", "__objc_methtype",
        "__ustring", "__cfstring", "__objc_selrefs", "__objc_classrefs",
        "__objc_superrefs", "__objc_imageinfo", "__objc_protolist",
        "__objc_arraydata", "__objc_arrayobj", "__objc_dictobj",
        "__swift5_typeref", "__swift5_reflstr", "__swift5_fieldmd",
        "__swift5_assocty", "__swift5_proto", "__swift5_types",
        "__gcc_except_tab", "__eh_frame", "__unwind_info", "__objc_const",
    ]

    private static let maxSliceBytes: UInt64 = 2 << 30 

    

    public func matches(header: Data) -> Bool {
        guard header.count >= 4 else { return false }
        let b = [UInt8](header.prefix(4))
        
        let le = UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
        switch le {
        case Magic.mhMagic, Magic.mhMagic64, Magic.mhCigam, Magic.mhCigam64:
            return true
        default: break
        }
        
        let be = UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])
        switch be {
        case Magic.fatMagic, Magic.fatMagic64, Magic.fatCigam, Magic.fatCigam64:
            return true
        default: return false
        }
    }

    public func detectSlices(url: URL) throws -> [SliceDescriptor] {
        let head = try readFileRegion(url: url, offset: 0, length: 4096)
        guard head.count >= 8 else {
            throw DecompilerError.malformedBinary("file too small for a Mach-O header")
        }
        let be = head.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let le = head.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }

        
        var fatOrder: FormatByteOrder? = nil
        var fatIs64 = false
        switch be {
        case Magic.fatMagic: fatOrder = .big; fatIs64 = false
        case Magic.fatMagic64: fatOrder = .big; fatIs64 = true
        default: break
        }
        if fatOrder == nil {
            switch le {
            case Magic.fatMagic, Magic.fatMagic64: 
                fatOrder = .little
                fatIs64 = (le == Magic.fatMagic64)
            default: break
            }
        }
        if let order = fatOrder {
            return try detectFatSlices(head: head, url: url, order: order, is64: fatIs64)
        }

        
        guard head.count >= 28 else {
            throw DecompilerError.malformedBinary("truncated Mach-O header")
        }
        
        let magicLE = head.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
        let order: FormatByteOrder
        switch magicLE {
        case Magic.mhMagic, Magic.mhMagic64: order = .little
        case Magic.mhCigam, Magic.mhCigam64: order = .big
        default:
            throw DecompilerError.malformedBinary("unrecognized Mach-O magic")
        }
        var cur = ByteCursor(head, order: order, offset: 4)
        let cpuType = try cur.u32()
        let cpuSubtype = try cur.u32()
        let arch = ArchitectureResolver.resolve(format: .machO,
                                                 identifier: .machO(cpuType: cpuType, cpuSubtype: cpuSubtype))
        let size = try fileSize(url: url)
        let cpuID = "\(cpuType)/\(cpuSubtype)"
        return [SliceDescriptor(index: 0, architecture: arch, cpuIdentifier: cpuID,
                                offset: 0, size: size, name: arch.displayName)]
    }

    private func detectFatSlices(head: Data, url: URL, order: FormatByteOrder, is64: Bool) throws -> [SliceDescriptor] {
        var cur = ByteCursor(head, order: order, offset: 4)
        let nfat = Int(try cur.u32())
        guard nfat > 0, nfat < 64 else {
            throw DecompilerError.malformedBinary("implausible nfat_arch \(nfat)")
        }
        let entrySize = is64 ? 32 : 20
        guard head.count >= 8 + nfat * entrySize else {
            
            let need = UInt64(8 + nfat * entrySize)
            let full = try readFileRegion(url: url, offset: 0, length: need)
            return try detectFatSlices(head: full, url: url, order: order, is64: is64)
        }
        var out: [SliceDescriptor] = []
        for i in 0..<nfat {
            let cpuType = try cur.u32()
            let cpuSubtype = try cur.u32()
            let offset: UInt64
            let size: UInt64
            var align: UInt32 = 0
            if is64 {
                offset = try cur.u64()
                size = try cur.u64()
                align = try cur.u32()
                _ = try cur.u32() 
            } else {
                offset = UInt64(try cur.u32())
                size = UInt64(try cur.u32())
                align = try cur.u32()
            }
            _ = align
            let arch = ArchitectureResolver.resolve(format: .machO,
                                                     identifier: .machO(cpuType: cpuType, cpuSubtype: cpuSubtype))
            out.append(SliceDescriptor(index: i, architecture: arch,
                                       cpuIdentifier: "\(cpuType)/\(cpuSubtype)",
                                       offset: offset, size: size,
                                       name: arch.displayName))
        }
        return out
    }

    

    public func parse(url: URL, sliceIndex: Int, identity: BinaryIdentity,
                      byteProvider: @escaping @Sendable (UInt64, UInt64) throws -> Data) throws -> BinaryImage {
        let slices = try detectSlices(url: url)
        guard let slice = slices.first(where: { $0.index == sliceIndex }) ?? slices.first else {
            throw DecompilerError.invalidRequest("Mach-O slice \(sliceIndex) not present")
        }
        guard slice.size <= Self.maxSliceBytes else {
            throw DecompilerError.resourceLimitExceeded(
                "Mach-O slice is \(slice.size) bytes (limit \(Self.maxSliceBytes))")
        }
        
        
        let sliceData = try byteProvider(slice.offset, slice.size)

        
        guard sliceData.count >= 28 else {
            throw DecompilerError.malformedBinary("truncated Mach-O header in slice")
        }
        let magicLE = sliceData.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
        let is64: Bool
        let order: FormatByteOrder
        switch magicLE {
        case Magic.mhMagic:    is64 = false; order = .little
        case Magic.mhMagic64:  is64 = true;  order = .little
        case Magic.mhCigam:    is64 = false; order = .big
        case Magic.mhCigam64:  is64 = true;  order = .big
        default:
            throw DecompilerError.malformedBinary("unrecognized Mach-O magic in slice")
        }
        var cur = ByteCursor(sliceData, order: order, offset: 4)
        let cpuType = try cur.u32()
        let cpuSubtype = try cur.u32()
        let fileTypeRaw = try cur.u32()
        let ncmds = Int(try cur.u32())
        _ = try cur.u32() 
        _ = try cur.u32() 
        if is64 { _ = try cur.u32() } 

        
        var segments: [BinarySegmentInfo] = []
        var symtab: (symoff: UInt64, nsyms: UInt32, stroff: UInt64, strsize: UInt32)? = nil
        var dependencies: [BinaryDependency] = []
        var installName: String? = nil
        var runpaths: [String] = []
        var dylinker: String? = nil
        var sawDWARF = false
        var hasLocalDefinedSymbol = false
        var isEncrypted = false
        var entryOffset: UInt64? = nil
        var functionStartsInfo: (off: UInt64, size: UInt64)? = nil
        var exportTrieInfo: (off: UInt64, size: UInt64)? = nil
        var sawCodeSignature = false
        var minOSVersion: String? = nil
        var buildVersion: String? = nil
        var targetPlatform: String? = nil
        var uuidBytes: Data? = nil
        var signatureNotes: [String] = []

        for _ in 0..<ncmds {
            let cmdStart = cur.offset
            guard cur.remaining >= 8 else {
                throw DecompilerError.malformedBinary("load commands overrun header")
            }
            let cmd = try cur.u32()
            let cmdsize = Int(try cur.u32())
            guard cmdsize >= 8, cmdStart + cmdsize <= sliceData.count else {
                throw DecompilerError.malformedBinary("bad cmdsize \(cmdsize) for cmd \(cmd)")
            }
            
            
            defer { cur.offset = cmdStart + cmdsize }

            switch cmd {
            case LC.segment, LC.segment64:
                let seg = try parseSegment(cur: &cur, is64: (cmd == LC.segment64),
                                           sliceBase: slice.offset)
                if seg.name == "__DWARF" { sawDWARF = true }
                segments.append(seg)

            case LC.symtab:
                let symoff = UInt64(try cur.u32())
                let nsyms = try cur.u32()
                let stroff = UInt64(try cur.u32())
                let strsize = try cur.u32()
                symtab = (symoff, nsyms, stroff, strsize)

            case LC.dysymtab:
                
                
                
                break

            case LC.loadDylib, LC.loadWeakDylib, LC.reexportDylib,
                 LC.lazyLoadDylib, LC.loadUpwardDylib:
                let nameOff = Int(try cur.u32())
                _ = try cur.u32() 
                let curVer = try cur.u32()
                let compatVer = try cur.u32()
                let name = try stringAt(cmdStart: cmdStart, nameOffset: nameOff,
                                        data: sliceData, order: order)
                let kind: String
                switch cmd {
                case LC.loadWeakDylib: kind = "weak"
                case LC.reexportDylib: kind = "reexport"
                case LC.loadUpwardDylib: kind = "upward"
                case LC.lazyLoadDylib: kind = "lazy"
                default: kind = "load"
                }
                dependencies.append(BinaryDependency(
                    path: name, kind: kind,
                    currentVersion: versionString(curVer),
                    compatibilityVersion: versionString(compatVer)))

            case LC.idDylib:
                let nameOff = Int(try cur.u32())
                installName = try stringAt(cmdStart: cmdStart, nameOffset: nameOff,
                                           data: sliceData, order: order)

            case LC.rpath:
                let pathOff = Int(try cur.u32())
                let path = try stringAt(cmdStart: cmdStart, nameOffset: pathOff,
                                        data: sliceData, order: order)
                runpaths.append(path)

            case LC.loadDylinker:
                let nameOff = Int(try cur.u32())
                dylinker = try stringAt(cmdStart: cmdStart, nameOffset: nameOff,
                                        data: sliceData, order: order)

            case LC.uuid:
                uuidBytes = try cur.bytes(16)

            case LC.encryptionInfo, LC.encryptionInfo64:
                _ = try cur.u32() 
                _ = try cur.u32() 
                let cryptid = try cur.u32()
                isEncrypted = cryptid != 0

            case LC.main:
                entryOffset = try cur.u64()
                _ = try cur.u64() 

            case LC.codeSignature, LC.functionStarts, LC.dataInCode,
                 LC.dyldExportsTrie, LC.dyldChainedFixups:
                let dataoff = UInt64(try cur.u32())
                let datasize = UInt64(try cur.u32())
                switch cmd {
                case LC.codeSignature:
                    sawCodeSignature = true
                    signatureNotes.append("PKCS#7 code signature, \(datasize) bytes")
                case LC.functionStarts:
                    functionStartsInfo = (dataoff, datasize)
                case LC.dyldExportsTrie:
                    if exportTrieInfo == nil { exportTrieInfo = (dataoff, datasize) }
                case LC.dyldChainedFixups:
                    signatureNotes.append("dyld chained fixups, \(datasize) bytes")
                default:
                    break
                }

            case LC.dyldInfo, LC.dyldInfoOnly:
                
                for _ in 0..<8 { _ = try cur.u32() } 
                let eoff = UInt64(try cur.u32())
                let esize = UInt64(try cur.u32())
                if esize > 0 { exportTrieInfo = (eoff, esize) }

            case LC.buildVersion:
                let platform = try cur.u32()
                let minos = try cur.u32()
                let sdk = try cur.u32()
                _ = try cur.u32() 
                minOSVersion = unpackVersion(minos)
                targetPlatform = platformID(platform)
                buildVersion = "platform \(platformName(platform)), minOS \(unpackVersion(minos)), SDK \(unpackVersion(sdk))"

            case LC.versionMinMacOSX, LC.versionMinIPhoneOS, LC.versionMinTVOS, LC.versionMinWatchOS:
                let v = try cur.u32()
                _ = try cur.u32() 
                minOSVersion = unpackVersion(v)
                targetPlatform = switch cmd {
                case LC.versionMinMacOSX: "macos"
                case LC.versionMinIPhoneOS: "ios"
                case LC.versionMinTVOS: "tvos"
                case LC.versionMinWatchOS: "watchos"
                default: nil
                }

            default:
                break 
            }
        }
        
        var symbols: [BinarySymbol] = []
        var imports: [BinaryImport] = []
        if let st = symtab {
            let result = try parseSymtab(sliceData: sliceData, symtab: st, is64: is64,
                                         order: order)
            symbols = result.symbols
            imports = result.imports
            if result.hasLocalDefined { hasLocalDefinedSymbol = true }
        }

        
        let imageBase: UInt64 = {
            if let t = segments.first(where: { $0.name == "__TEXT" }) { return t.vmAddress }
            return segments.map(\.vmAddress).min() ?? 0
        }()

        
        let entryPoint: DecompilerAddress? = entryOffset.map {
            DecompilerAddress(virtual: imageBase &+ $0)
        }

        
        var functionStarts: [DecompilerAddress] = []
        if let fs = functionStartsInfo, fs.size > 0 {
            functionStarts = try parseFunctionStarts(sliceData: sliceData, info: fs,
                                                     imageBase: imageBase, order: order)
        }

        
        var exports: [BinaryExport] = []
        if let et = exportTrieInfo, et.size > 0 {
            exports = try parseExportsTrie(sliceData: sliceData, info: et,
                                           imageBase: imageBase, order: order)
        }

        
        var ident = identity
        ident.binaryUUID = uuidBytes?.hexDashedUUID()
        ident.architecture = ArchitectureResolver.resolve(
            format: .machO, identifier: .machO(cpuType: cpuType, cpuSubtype: cpuSubtype))
        let cpuID = "\(cpuType)/\(cpuSubtype)"

        
        var notes = signatureNotes
        if let name = installName { notes.append("install name: \(name)") }
        if let d = dylinker { notes.append("dyld: \(d)") }
        let codeSigInfo = notes.isEmpty ? nil : notes.joined(separator: "; ")

        let fileType: String = switch fileTypeRaw {
        case 0x1: "object"
        case 0x2: "execute"
        case 0x6: "dylib"
        case 0x7: "dyld"
        case 0x8: "bundle"
        default: "mh-\(fileTypeRaw)"
        }

        var image = BinaryImage(
            identity: ident, format: .machO, architecture: ident.architecture,
            cpuIdentifier: cpuID, fileType: fileType,
            entryPoint: entryPoint, segments: segments,
            imports: imports, exports: exports, dependencies: dependencies,
            symbols: symbols, strings: [], functionStarts: functionStarts,
            isEncrypted: isEncrypted, isSigned: sawCodeSignature,
            entitlements: nil, codeSignatureInfo: codeSigInfo,
            buildVersion: buildVersion, minOSVersion: minOSVersion,
            hasDebugInfo: hasLocalDefinedSymbol || sawDWARF,
            byteCount: Int64(slice.size), byteProvider: byteProvider,
            targetPlatform: targetPlatform, containerOffset: slice.offset)
        image.installName = installName
        image.runpaths = runpaths
        return image
    }

    

    
    
    
    private func parseSegment(cur: inout ByteCursor, is64: Bool,
                              sliceBase: UInt64) throws -> BinarySegmentInfo {
        let segnameBytes = try cur.bytes(16)
        let segName = ByteCursor.fixedString(segnameBytes)
        let vmaddr: UInt64, vmsize: UInt64, fileoff: UInt64, filesize: UInt64
        let maxprot: UInt32, initprot: UInt32, nsects: UInt32
        if is64 {
            vmaddr = try cur.u64(); vmsize = try cur.u64()
            fileoff = try cur.u64(); filesize = try cur.u64()
            maxprot = try cur.u32(); initprot = try cur.u32()
            nsects = try cur.u32(); _ = try cur.u32() 
        } else {
            vmaddr = UInt64(try cur.u32()); vmsize = UInt64(try cur.u32())
            fileoff = UInt64(try cur.u32()); filesize = UInt64(try cur.u32())
            maxprot = try cur.u32(); initprot = try cur.u32()
            nsects = try cur.u32(); _ = try cur.u32()
        }
        let writable = (maxprot | initprot) & 2 != 0 
        
        let sectBytes = is64 ? 80 : 68
        guard Int(nsects) <= cur.remaining / sectBytes else {
            throw DecompilerError.malformedBinary("segment section table overruns command")
        }
        var sections: [BinarySectionInfo] = []
        for _ in 0..<nsects {
            let snameBytes = try cur.bytes(16)
            let sname = ByteCursor.fixedString(snameBytes)
            _ = try cur.bytes(16) 
            let addr: UInt64, size: UInt64
            let offset: UInt32, flags: UInt32
            if is64 {
                addr = try cur.u64(); size = try cur.u64()
                offset = try cur.u32(); _ = try cur.u32() 
                _ = try cur.u32() 
                _ = try cur.u32() 
                flags = try cur.u32()
                _ = try cur.u32(); _ = try cur.u32(); _ = try cur.u32() 
            } else {
                addr = UInt64(try cur.u32()); size = UInt64(try cur.u32())
                offset = try cur.u32(); _ = try cur.u32() 
                _ = try cur.u32(); _ = try cur.u32() 
                flags = try cur.u32()
                _ = try cur.u32(); _ = try cur.u32() 
            }
            let executable = (flags & (SAttr.pureInstructions | SAttr.someInstructions)) != 0
            let isStringSection = Self.sectionStringNames.contains(sname)
                || sname.contains("string") || sname.contains("cstring")
            sections.append(BinarySectionInfo(
                name: sname, segment: segName,
                address: DecompilerAddress(virtual: addr), size: size,
                
                fileOffset: sliceBase + UInt64(offset),
                flags: flags, isExecutable: executable,
                isWritable: writable, containsStrings: isStringSection))
        }
        return BinarySegmentInfo(
            name: segName, vmAddress: vmaddr, vmSize: vmsize,
            
            fileOffset: sliceBase + fileoff, fileSize: filesize,
            maxProtection: Int(maxprot), initialProtection: Int(initprot),
            sections: sections)
    }

    

    private struct SymtabResult {
        var symbols: [BinarySymbol]
        var imports: [BinaryImport]
        var hasLocalDefined: Bool
    }

    private func parseSymtab(sliceData: Data, symtab: (symoff: UInt64, nsyms: UInt32,
                                                      stroff: UInt64, strsize: UInt32),
                            is64: Bool, order: FormatByteOrder) throws -> SymtabResult {
        let entrySize = is64 ? 16 : 12
        let nsyms = Int(symtab.nsyms)
        let empty = SymtabResult(symbols: [], imports: [], hasLocalDefined: false)
        
        guard nsyms > 0,
              symtab.symoff + UInt64(nsyms) * UInt64(entrySize) <= UInt64(sliceData.count),
              symtab.stroff + UInt64(symtab.strsize) <= UInt64(sliceData.count) else {
            return empty
        }
        let strStart = Int(symtab.stroff)
        let strSize = Int(symtab.strsize)
        let strtab = Data(sliceData[strStart..<(strStart + strSize)])

        func stringAt(_ strx: UInt32) -> String {
            guard strx < strtab.count else { return "" }
            var i = Int(strx)
            var bytes = [UInt8]()
            while i < strtab.count, strtab[i] != 0 {
                bytes.append(strtab[i]); i += 1
            }
            return String(decoding: bytes, as: UTF8.self)
        }

        var cur = ByteCursor(sliceData, order: order, offset: Int(symtab.symoff))
        var symbols: [BinarySymbol] = []
        var imports: [BinaryImport] = []
        var hasLocalDefined = false
        for _ in 0..<nsyms {
            let strx = try cur.u32()
            let ntype = try cur.u8()
            let nsect = try cur.u8()
            let ndesc = try cur.u16()
            let nvalue = is64 ? try cur.u64() : UInt64(try cur.u32())
            _ = nsect
            let rawName = stringAt(strx)
            guard !rawName.isEmpty else { continue }
            let type = ntype & NList.typeMask
            let isExt = (ntype & NList.ext) != 0 || (ntype & NList.pext) != 0
            let isUndef = type == NList.undef

            
            
            
            var demangled: String? = nil
            if rawName.hasPrefix("_") && !rawName.hasPrefix("__")
                && !rawName.hasPrefix("_$s") && !rawName.hasPrefix("_$S")
                && !rawName.hasPrefix("_Tt") && !rawName.hasPrefix("_Ts") {
                demangled = String(rawName.dropFirst())
            }

            let kind: BinarySymbol.Kind
            if isUndef {
                kind = .undefined
                imports.append(BinaryImport(
                    name: rawName, library: "",
                    address: nil,
                    isWeak: (ndesc & NList.weakRefDesc) != 0))
            } else if type == NList.abs_ {
                kind = .absolute
            } else if ntype & NList.pext != 0 {
                kind = .external
            } else if isExt {
                kind = .global
            } else {
                kind = .local
                hasLocalDefined = true
            }

            symbols.append(BinarySymbol(
                name: rawName, demangledName: demangled,
                address: isUndef ? nil : DecompilerAddress(virtual: nvalue),
                size: 0, kind: kind,
                source: AnalysisSource(provenance: .symbolTable, pass: "mach-o-symtab")))
        }
        return SymtabResult(symbols: symbols, imports: imports,
                            hasLocalDefined: hasLocalDefined)
    }

    

    private func parseFunctionStarts(sliceData: Data,
                                     info: (off: UInt64, size: UInt64),
                                     imageBase: UInt64,
                                     order: FormatByteOrder) throws -> [DecompilerAddress] {
        let off = Int(info.off)
        let size = Int(info.size)
        guard off >= 0, off + size <= sliceData.count, size > 0 else { return [] }
        var cur = ByteCursor(Data(sliceData[off..<(off + size)]), order: order)
        var out: [DecompilerAddress] = []
        var addr: UInt64 = 0
        while !cur.atEnd {
            let delta = try cur.uleb128()
            if delta == 0 && cur.atEnd { break }
            addr = addr &+ delta
            out.append(DecompilerAddress(virtual: imageBase &+ addr))
        }
        return out
    }

    

    
    
    private func parseExportsTrie(sliceData: Data, info: (off: UInt64, size: UInt64),
                                  imageBase: UInt64,
                                  order: FormatByteOrder) throws -> [BinaryExport] {
        let off = Int(info.off)
        let size = Int(info.size)
        guard off >= 0, off + size <= sliceData.count, size > 0 else { return [] }
        let blob = Data(sliceData[off..<(off + size)])
        var out: [BinaryExport] = []
        var visited = Set<Int>()

        
        var stack: [(nodeOffset: Int, prefix: String)] = [(0, "")]
        while let (nodeOff, prefix) = stack.popLast() {
            guard nodeOff >= 0, nodeOff < blob.count, visited.insert(nodeOff).inserted else { continue }
            var cur = ByteCursor(blob, order: order, offset: nodeOff)
            let terminalSize: UInt64
            do { terminalSize = try cur.uleb128() } catch { break }
            var name = prefix
            if terminalSize > 0 {
                guard let flags = try? cur.uleb128() else { continue }
                let isReexport = (flags & 0x10) != 0       
                let hasStubResolver = (flags & 0x08) != 0  
                var addr: UInt64? = nil
                if !isReexport {
                    addr = try? cur.uleb128()
                }
                if hasStubResolver {
                    _ = try? cur.uleb128() 
                    _ = try? cur.uleb128() 
                }
                if let nameOff = try? cur.uleb128(), nameOff < UInt64(blob.count) {
                    var nc = ByteCursor(blob, order: order, offset: Int(nameOff))
                    if let s = try? nc.cstring(), !s.isEmpty { name = s }
                }
                if let a = addr {
                    out.append(BinaryExport(
                        name: name, address: DecompilerAddress(virtual: imageBase &+ a),
                        kind: .symbol))
                }
            }
            guard let childCount = try? cur.uleb128() else { continue }
            guard childCount < 4096 else { continue } 
            for _ in 0..<Int(childCount) {
                guard let label = try? cur.cstring() else { break }
                guard let childRel = try? cur.uleb128() else { break }
                stack.append((Int(childRel), prefix + label))
            }
        }
        return out
    }

    

    
    
    private func stringAt(cmdStart: Int, nameOffset: Int, data: Data,
                          order: FormatByteOrder) throws -> String {
        let pos = cmdStart + nameOffset
        guard pos >= 0, pos < data.count else { return "" }
        var cur = ByteCursor(data, order: order, offset: pos)
        return (try? cur.cstring()) ?? ""
    }

    private func versionString(_ packed: UInt32) -> String? {
        packed == 0 ? nil : unpackVersion(packed)
    }

    
    
    private func platformID(_ p: UInt32) -> String? {
        switch p {
        case 1: return "macos"
        case 2: return "ios"
        case 3: return "tvos"
        case 4: return "watchos"
        case 5: return "bridgeos"
        case 6: return "mac-catalyst"
        case 7: return "ios-simulator"
        case 8: return "tvos-simulator"
        case 9: return "watchos-simulator"
        case 10: return "driverkit"
        case 11: return "xros"
        case 12: return "xros-simulator"
        default: return nil
        }
    }

    private func platformName(_ p: UInt32) -> String {
        switch p {
        case 1: return "macOS"
        case 2: return "iOS"
        case 3: return "tvOS"
        case 4: return "watchOS"
        case 5: return "bridgeOS"
        case 6: return "macCatalyst"
        case 7: return "iOSSimulator"
        case 8: return "tvOSSimulator"
        case 9: return "watchOSSimulator"
        case 10: return "driverKit"
        case 11: return "visionOS"
        case 12: return "visionOSSimulator"
        default: return "platform-\(p)"
        }
    }
}
