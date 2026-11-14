import Foundation


public enum BinaryFormat: String, Sendable, Codable, CaseIterable {
    case machO = "mach-o"
    case elf
    case pe
    case unknown

    public var displayName: String {
        switch self {
        case .machO: return "Mach-O"
        case .elf: return "ELF"
        case .pe: return "PE"
        case .unknown: return "Unknown"
        }
    }
}



public enum BinaryArchitecture: String, Sendable, Codable, CaseIterable {
    case arm64
    case arm64_32
    case x86_64
    case armv7
    case armv7s
    case armv6
    case i386
    case riscv64
    case powerpc
    case powerpc64
    case mips
    case unknown

    public var displayName: String {
        switch self {
        case .arm64: return "ARM64"
        case .arm64_32: return "ARM64_32"
        case .x86_64: return "x86_64"
        case .armv7: return "ARMv7"
        case .armv7s: return "ARMv7s"
        case .armv6: return "ARMv6"
        case .i386: return "i386"
        case .riscv64: return "RISC-V 64"
        case .powerpc: return "PowerPC"
        case .powerpc64: return "PowerPC64"
        case .mips: return "MIPS"
        case .unknown: return "Unknown"
        }
    }

    
    public var addressWidth: Int {
        switch self {
        case .arm64, .x86_64, .riscv64, .powerpc64: return 64
        case .arm64_32, .armv7, .armv7s, .armv6, .i386, .powerpc, .mips: return 32
        case .unknown: return 64
        }
    }

    
    public var endianness: Endianness {
        switch self {
        case .powerpc, .mips: return .big
        default: return .little
        }
    }

    public enum Endianness: String, Sendable, Codable { case little, big }
}


public enum CPUTypeIdentifier: Hashable, Sendable {
    
    case machO(cpuType: UInt32, cpuSubtype: UInt32)
    
    case elfMachine(UInt16)
    
    case peMachine(UInt16)
}


public enum ArchitectureResolver {
    public static func resolve(format: BinaryFormat, identifier: CPUTypeIdentifier) -> BinaryArchitecture {
        switch identifier {
        case .machO(let cpuType, let cpuSubtype):
            
            
            let sub = cpuSubtype & 0x00FF_FFFF
            switch cpuType {
            case 0x0100_000C: return sub == 2 ? .arm64 : .arm64 
            case 0x0100_0007: return .x86_64
            case 12: 
                switch sub {
                case 9: return .armv7
                case 11: return .armv7s
                case 6, 5: return .armv6
                case 14: return .arm64_32 
                default: return .armv7
                }
            case 7: return .i386
            case 18: return .powerpc
            case 0x0100_0012: return .powerpc64
            default: return .unknown
            }
        case .elfMachine(let machine):
            switch machine {
            case 183: return .arm64 
            case 62: return .x86_64 
            case 40: return .armv7 
            case 3: return .i386 
            case 8: return .mips
            case 21: return .powerpc 
            case 243: return .riscv64 
            default: return .unknown
            }
        case .peMachine(let machine):
            switch machine {
            case 0x8664: return .x86_64 
            case 0x014c: return .i386 
            case 0xAA64: return .arm64 
            case 0x01C0, 0x01C4: return .armv7 
            default: return .unknown
            }
        }
    }
}
