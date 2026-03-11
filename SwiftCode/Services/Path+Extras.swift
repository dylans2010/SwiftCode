import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import PathKit

extension Path {
    static func glob(_ pattern: String) -> [Path] {
        #if canImport(Darwin)
        var gt = glob_t()
        defer { globfree(&gt) }

        let flags = GLOB_TILDE | GLOB_BRACE
        if Darwin.glob(pattern, flags, nil, &gt) == 0 {
            let count = Int(gt.gl_pathc)
            return (0..<count).compactMap { index in
                if let pathPtr = gt.gl_pathv[index] {
                    return Path(String(cString: pathPtr))
                }
                return nil
            }
        }
        #elseif canImport(Glibc)
        // Fallback or Glibc specific glob implementation if needed
        #endif
        return []
    }
}
