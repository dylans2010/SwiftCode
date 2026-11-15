import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum AtomicFileIO {
    public static func writeAtomically(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent("." + url.lastPathComponent + ".tmp-\(UUID().uuidString)")
        try writeData(data, to: temp)
        let renamed = temp.path.withCString { tempCString in
            url.path.withCString { destCString in
                rename(tempCString, destCString)
            }
        }
        guard renamed == 0 else {
            try? FileManager.default.removeItem(at: temp)
            throw SpacesError.ioError("atomic rename failed for \(url.path): \(posixMessage())")
        }
        try fsyncDirectory(directory)
    }

    public static func append(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let existed = FileManager.default.fileExists(atPath: url.path)
        let fd = url.path.withCString { open($0, O_WRONLY | O_APPEND | O_CREAT, 0o644) }
        guard fd >= 0 else {
            throw SpacesError.ioError("cannot open \(url.path) for append: \(posixMessage())")
        }
        defer { close(fd) }
        try writeToDescriptor(data, fd: fd, path: url.path)
        guard fsync(fd) == 0 else {
            throw SpacesError.ioError("fsync failed for \(url.path): \(posixMessage())")
        }
        if !existed {
            try fsyncDirectory(directory)
        }
    }

    public static func fsyncFile(at url: URL) throws {
        let fd = url.path.withCString { open($0, O_RDONLY) }
        guard fd >= 0 else {
            throw SpacesError.ioError("cannot open \(url.path) for fsync: \(posixMessage())")
        }
        defer { close(fd) }
        guard fsync(fd) == 0 else {
            throw SpacesError.ioError("fsync failed for \(url.path): \(posixMessage())")
        }
    }

    public static func fsyncDirectory(_ directory: URL) throws {
        let fd = directory.path.withCString { open($0, O_RDONLY) }
        guard fd >= 0 else {
            throw SpacesError.ioError("cannot open directory \(directory.path) for fsync: \(posixMessage())")
        }
        defer { close(fd) }
        guard fsync(fd) == 0 else {
            throw SpacesError.ioError("fsync failed for directory \(directory.path): \(posixMessage())")
        }
    }

    public static func posixMessage() -> String {
        String(cString: strerror(errno))
    }

    private static func writeData(_ data: Data, to url: URL) throws {
        let fd = url.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, 0o644) }
        guard fd >= 0 else {
            throw SpacesError.ioError("cannot create temp file \(url.path): \(posixMessage())")
        }
        defer { close(fd) }
        try writeToDescriptor(data, fd: fd, path: url.path)
        guard fsync(fd) == 0 else {
            throw SpacesError.ioError("fsync failed for \(url.path): \(posixMessage())")
        }
    }

    private static func writeToDescriptor(_ data: Data, fd: Int32, path: String) throws {
        guard !data.isEmpty else { return }
        try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw SpacesError.ioError("cannot access data for \(path)")
            }
            var offset = 0
            while offset < buffer.count {
                let written = write(fd, baseAddress.advanced(by: offset), buffer.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw SpacesError.ioError("write failed for \(path): \(posixMessage())")
                }
                if written == 0 {
                    throw SpacesError.ioError("short write for \(path)")
                }
                offset += written
            }
        }
    }
}
