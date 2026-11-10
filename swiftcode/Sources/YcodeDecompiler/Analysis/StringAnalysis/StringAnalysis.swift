import Foundation

/// String extraction: ASCII / UTF-8 / UTF-16 sequences in non-executable
/// sections, mapped back to virtual addresses.
public enum StringAnalysis {
    public static let minLength = 4

    public static func extract(image: BinaryImage) -> [BinaryString] {
        var out: [BinaryString] = []
        let sections = image.segments.flatMap(\.sections)
            .filter { !$0.isExecutable }
            .sorted { $0.address.value < $1.address.value }

        for section in sections {
            guard section.size > 0, section.size < AnalysisSecurityPolicy.maxBinarySize else { continue }
            guard let data = try? image.bytes(fileOffset: section.fileOffset,
                                              length: Int(min(section.size, 256 * 1024 * 1024))) else { continue }
            extractASCII(data: data, section: section, image: image, into: &out)
            extractUTF16(data: data, section: section, image: image, into: &out)
            if out.count >= AnalysisSecurityPolicy.maxStrings { break }
        }
        return out
    }

    private static func sectionVirtualAddress(forFileOffset offset: UInt64, in image: BinaryImage) -> UInt64? {
        for seg in image.segments {
            guard offset >= seg.fileOffset, offset < seg.fileOffset + seg.fileSize else { continue }
            return seg.vmAddress + (offset - seg.fileOffset)
        }
        return nil
    }

    private static func extractASCII(data: Data, section: BinarySectionInfo,
                                     image: BinaryImage, into out: inout [BinaryString]) {
        var start = 0
        var i = 0
        while i < data.count {
            let b = data[i]
            let printable = b >= 0x20 && b < 0x7F
            if printable {
                if start < 0 { start = i }
            } else {
                if start >= 0 {
                    let len = i - start
                    if len >= minLength, let str = String(data: data[start..<i], encoding: .utf8),
                       !str.contains("\0") {
                        let fileOff = section.fileOffset + UInt64(start)
                        let va = section.address.value + UInt64(start)
                        out.append(BinaryString(text: str,
                                                address: DecompilerAddress(virtual: va),
                                                fileOffset: fileOff,
                                                encoding: .ascii, isReferenced: false))
                    }
                    start = -1
                }
            }
            i += 1
        }
        if start >= 0, data.count - start >= minLength,
           let str = String(data: data[start...], encoding: .utf8) {
            out.append(BinaryString(text: str,
                                    address: DecompilerAddress(virtual: section.address.value + UInt64(start)),
                                    fileOffset: section.fileOffset + UInt64(start),
                                    encoding: .ascii, isReferenced: false))
        }
    }

    private static func extractUTF16(data: Data, section: BinarySectionInfo,
                                     image: BinaryImage, into out: inout [BinaryString]) {
        // Scan for runs of (ASCII byte, 0x00) pairs — UTF-16LE strings.
        var i = 0
        while i + 1 < data.count {
            if data[i + 1] == 0, data[i] >= 0x20, data[i] < 0x7F {
                var j = i
                var chars: [UInt8] = []
                while j + 1 < data.count, data[j + 1] == 0, data[j] >= 0x20, data[j] < 0x7F {
                    chars.append(data[j]); j += 2
                }
                if chars.count >= minLength, let str = String(bytes: chars, encoding: .utf8) {
                    out.append(BinaryString(text: str,
                                            address: DecompilerAddress(virtual: section.address.value + UInt64(i)),
                                            fileOffset: section.fileOffset + UInt64(i),
                                            encoding: .utf16LE, isReferenced: false))
                }
                i = j
            } else {
                i += 2
            }
        }
    }
}
