import AppKit
import UniformTypeIdentifiers
import YcodeAssistant





@MainActor
enum AttachmentPicker {
    
    static let maxInlineBytes = 200_000

    static func pickFile() -> Attachment? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Attach"
        panel.message = "Choose a file to attach to the message."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return attachment(for: url)
    }

    static func pickImage() -> Attachment? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic, .tiff, .bmp]
        panel.prompt = "Attach"
        panel.message = "Choose an image to attach to the message."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return imageAttachment(for: url)
    }

    static func attachment(for url: URL) -> Attachment? {
        let path = url.path
        guard let data = try? Data(contentsOf: url) else {
            NSSound.beep()
            return nil
        }
        if let image = imageAttachment(for: url, data: data) { return image }
        var text: String
        if let s = String(data: data, encoding: .utf8) {
            if data.count > maxInlineBytes {
                let head = String(s.prefix(maxInlineBytes))
                text = head + "\n[…file truncated at \(maxInlineBytes) bytes; use file tools to read the rest…]"
            } else {
                text = s
            }
        } else {
            text = "[Binary file \(url.lastPathComponent) — \(data.count) bytes. Not inlined; use file tools to inspect it.]"
        }
        return Attachment(kind: .file, path: path, text: text)
    }

    
    static func imageAttachment(for url: URL, data: Data? = nil) -> Attachment? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()), type.conforms(to: .image),
              let data = data ?? (try? Data(contentsOf: url)), !data.isEmpty else { return nil }
        let mime = type.preferredMIMEType ?? "image/png"
        return Attachment(
            kind: .file,
            path: url.path,
            text: "Attached image \(url.lastPathComponent) (\(mime), \(data.count) bytes). The image itself is included with this message.",
            image: AttachmentImage(mimeType: mime, data: data))
    }
}
