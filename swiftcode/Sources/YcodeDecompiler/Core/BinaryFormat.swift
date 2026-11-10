import Foundation

/// Container format of a binary slice.
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

/// Instruction-set architecture identifier. Registry-driven: a capability is
/// only advertised when a backend actually supports it.
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

    /// Address width in bits for this architecture's default address space.
    public var addressWidth: Int {
        switch self {
        case .arm64, .x86_64, .riscv64, .powerpc64: return 64
        case .arm64_32, .armv7, .armv7s, .armv6, .i386, .powerpc, .mips: return 32
        case .unknown: return 64
        }
    }

    /// Endianness of the instruction stream / integer fields.
    public var endianness: Endianness {
        switch self {
        case .powerpc, .mips: return .big
        default: return .little
        }
    }

    public enum Endianness: String, Sendable, Codable { case little, big }
}

/// CPU type / machine identifiers used by each container format.
public enum CPUTypeIdentifier: Hashable, Sendable {
    // Mach-O
    case machO(cpuType: UInt32, cpuSubtype: UInt32)
    // ELF e_machine
    case elfMachine(UInt16)
    // PE machine
    case peMachine(UInt16)
}

/// Maps raw format CPU identifiers onto our architecture registry.
public enum ArchitectureResolver {
    public static func resolve(format: BinaryFormat, identifier: CPUTypeIdentifier) -> BinaryArchitecture {
        switch identifier {
        case .machO(let cpuType, let cpuSubtype):
            // CPU_TYPE_ARM64 = 0x0100000C, CPU_TYPE_X86_64 = 0x01000007,
            // CPU_TYPE_ARM = 12, CPU_TYPE_I386 = 7, CPU_TYPE_POWERPC = 18, CPU_TYPE_POWERPC64 = 0x01000012
            let sub = cpuSubtype & 0x00FF_FFFF
            switch cpuType {
            case 0x0100_000C: return sub == 2 ? .arm64 : .arm64 // arm64e shares decoder
            case 0x0100_0007: return .x86_64
            case 12: // CPU_TYPE_ARM
                switch sub {
                case 9: return .armv7
                case 11: return .armv7s
                case 6, 5: return .armv6
                case 14: return .arm64_32 // CPU_SUBTYPE_ARM64_32
                default: return .armv7
                }
            case 7: return .i386
            case 18: return .powerpc
            case 0x0100_0012: return .powerpc64
            default: return .unknown
            }
        case .elfMachine(let machine):
            switch machine {
            case 183: return .arm64 // EM_AARCH64
            case 62: return .x86_64 // EM_X86_64
            case 40: return .armv7 // EM_ARM
            case 3: return .i386 // EM_386
            case 8: return .mips
            case 21: return .powerpc // EM_PPC
            case 243: return .riscv64 // EM_RISCV
            default: return .unknown
            }
        case .peMachine(let machine):
            switch machine {
            case 0x8664: return .x86_64 // IMAGE_FILE_MACHINE_AMD64
            case 0x014c: return .i386 // IMAGE_FILE_MACHINE_I386
            case 0xAA64: return .arm64 // IMAGE_FILE_MACHINE_ARM64
            case 0x01C0, 0x01C4: return .armv7 // ARM / ARMNT
            default: return .unknown
            }
        }
    }
}
