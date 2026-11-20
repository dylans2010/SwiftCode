// Expansion toolkit: Network. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKHttpGetRequestTool: AssistTool {
    public init() {}
    public var id: String { "http_get_request" }
    public var name: String { "HTTP GET" }
    public var description: String { "Performs a real HTTP GET to `url` (optional `headers` object) and returns status, key headers and the body (truncated). Use for docs/API checks." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .externalSideEffect }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Performs a real HTTP GET to `url` (optional `headers` object) and returns status, key headers and the body (truncated). Use for docs/API checks.", properties: ["url": JSONSchema(type: "string", description: "Absolute http(s) URL."), "headers": JSONSchema(type: "object", description: "Optional request headers.")], required: ["url"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let url = AssistToolKit.validatedURL(AssistToolKit.string(input, "url")) else { return AssistToolKit.invalid("A valid http(s) url is required.") }
        let headers = (input["headers"] as? [String: Any])?.compactMapValues { "\($0)" } ?? [:]
        let r = await AssistToolKit.httpRequest(url: url, method: "GET", headers: headers)
        if let e = r.error { var f = AssistToolResult.failure("Request failed: \(e)"); f.toolErrorCode = .executionFailed; return f }
        let ct = r.headers.first { $0.key.lowercased() == "content-type" }?.value ?? "?"
        let body = String(data: r.body, encoding: .utf8) ?? "<\(r.body.count) bytes binary>"
        return .success("status: \(r.status)\ncontent-type: \(ct)\nbytes: \(r.body.count)\n\n" + AssistToolKit.output(body, limit: 15000), data: ["status": String(r.status)])
    }
}


public struct XKHttpHeadRequestTool: AssistTool {
    public init() {}
    public var id: String { "http_head_request" }
    public var name: String { "HTTP HEAD" }
    public var description: String { "Sends an HTTP HEAD request to `url` and returns the status code and all response headers." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .externalSideEffect }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Sends an HTTP HEAD request to `url` and returns the status code and all response headers.", properties: ["url": JSONSchema(type: "string", description: "Absolute http(s) URL.")], required: ["url"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let url = AssistToolKit.validatedURL(AssistToolKit.string(input, "url")) else { return AssistToolKit.invalid("A valid http(s) url is required.") }
        let r = await AssistToolKit.httpRequest(url: url, method: "HEAD")
        if let e = r.error { var f = AssistToolResult.failure("Request failed: \(e)"); f.toolErrorCode = .executionFailed; return f }
        return .success("status: \(r.status)\n" + r.headers.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n"), data: ["status": String(r.status)])
    }
}


public struct XKHttpPostJsonTool: AssistTool {
    public init() {}
    public var id: String { "http_post_json" }
    public var name: String { "HTTP POST JSON" }
    public var description: String { "Sends a JSON `body` (string or object) via HTTP POST to `url` and returns the status and response. Has external side effects — only call when the user asked for it." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .externalSideEffect }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Sends a JSON `body` (string or object) via HTTP POST to `url` and returns the status and response. Has external side effects — only call when the user asked for it.", properties: ["url": JSONSchema(type: "string", description: "Absolute http(s) URL."), "body": JSONSchema(type: "string", description: "JSON body (string)."), "headers": JSONSchema(type: "object", description: "Optional headers.")], required: ["url", "body"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let url = AssistToolKit.validatedURL(AssistToolKit.string(input, "url")) else { return AssistToolKit.invalid("A valid http(s) url is required.") }
        let bodyData: Data
        if let s = input["body"] as? String { guard AssistToolKit.parseJSON(s) != nil else { return AssistToolKit.invalid("body must be valid JSON.") }; bodyData = Data(s.utf8) }
        else if let o = input["body"], JSONSerialization.isValidJSONObject(o) { bodyData = try JSONSerialization.data(withJSONObject: o) }
        else { return AssistToolKit.missing("body") }
        var headers = (input["headers"] as? [String: Any])?.compactMapValues { "\($0)" } ?? [:]
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"
        let r = await AssistToolKit.httpRequest(url: url, method: "POST", headers: headers, body: bodyData)
        if let e = r.error { var f = AssistToolResult.failure("Request failed: \(e)"); f.toolErrorCode = .executionFailed; return f }
        return .success("status: \(r.status)\n\n" + AssistToolKit.output(String(data: r.body, encoding: .utf8) ?? "<binary>", limit: 15000), data: ["status": String(r.status)])
    }
}


public struct XKHttpStatusCheckTool: AssistTool {
    public init() {}
    public var id: String { "http_status_check" }
    public var name: String { "HTTP Status Check" }
    public var description: String { "Checks a list of `urls` concurrently (HEAD, falling back to GET) and reports status code and latency for each — useful for verifying links in docs." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .externalSideEffect }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Checks a list of `urls` concurrently (HEAD, falling back to GET) and reports status code and latency for each — useful for verifying links in docs.", properties: ["urls": JSONSchema(type: "array", description: "URLs to check (max 50).", items: JSONSchema(type: "string"))], required: ["urls"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let urls = AssistToolKit.stringArray(input, "urls").prefix(50).compactMap { AssistToolKit.validatedURL($0) }
        guard !urls.isEmpty else { return AssistToolKit.missing("urls") }
        let results = await withTaskGroup(of: (Int, String).self) { group -> [(Int, String)] in
            for (i, u) in urls.enumerated() {
                group.addTask {
                    let start = Date()
                    var r = await AssistToolKit.httpRequest(url: u, method: "HEAD", timeout: 15)
                    if r.error == nil && (r.status == 405 || r.status == 403) { r = await AssistToolKit.httpRequest(url: u, method: "GET", timeout: 15) }
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    return (i, r.error.map { "ERR  \(u.absoluteString) — \($0)" } ?? "\(r.status)  \(ms)ms  \(u.absoluteString)")
                }
            }
            var out: [(Int, String)] = []; for await x in group { out.append(x) }; return out
        }
        return .success(results.sorted { $0.0 < $1.0 }.map { $0.1 }.joined(separator: "\n"), data: ["checked": String(results.count)])
    }
}


public struct XKDnsLookupTool: AssistTool {
    public init() {}
    public var id: String { "dns_lookup" }
    public var name: String { "DNS Lookup" }
    public var description: String { "Resolves `host` to its IPv4/IPv6 addresses using the system resolver (getaddrinfo)." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Resolves `host` to its IPv4/IPv6 addresses using the system resolver (getaddrinfo).", properties: ["host": JSONSchema(type: "string", description: "Hostname.")], required: ["host"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let host = AssistToolKit.string(input, "host")?.trimmingCharacters(in: .whitespaces), !host.isEmpty else { return AssistToolKit.missing("host") }
        var hints = addrinfo(); hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(host, nil, &hints, &res)
        guard rc == 0, let first = res else { return AssistToolKit.notFound("Resolution failed: \(String(cString: gai_strerror(rc)))") }
        defer { freeaddrinfo(res) }
        var addrs: [String] = []; var p: UnsafeMutablePointer<addrinfo>? = first
        while let a = p {
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(a.pointee.ai_addr, a.pointee.ai_addrlen, &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST) == 0 {
                let s = String(cString: buf); if !addrs.contains(s) { addrs.append(s) } }
            p = a.pointee.ai_next
        }
        return .success("\(host):\n" + addrs.map { "  " + $0 }.joined(separator: "\n"), data: ["count": String(addrs.count)])
    }
}


public struct XKHttpDownloadFileTool: AssistTool {
    public init() {}
    public var id: String { "http_download_file" }
    public var name: String { "HTTP Download File" }
    public var description: String { "Downloads `url` into the workspace at `destination` (refuses to overwrite unless `overwrite`), reporting size and SHA-256." }
    public var capability: ToolCapability { .fileModification }
    public var riskLevel: ToolRiskLevel { .safeMutation }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { true }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Downloads `url` into the workspace at `destination` (refuses to overwrite unless `overwrite`), reporting size and SHA-256.", properties: ["url": JSONSchema(type: "string", description: "Absolute http(s) URL."), "destination": JSONSchema(type: "string", description: "Workspace-relative destination path."), "overwrite": JSONSchema(type: "boolean", description: "Replace existing file.")], required: ["url", "destination"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let url = AssistToolKit.validatedURL(AssistToolKit.string(input, "url")) else { return AssistToolKit.invalid("A valid http(s) url is required.") }
        guard let destRaw = AssistToolKit.string(input, "destination"), let dest = AssistWorkspacePaths.resolve(destRaw, workspaceRoot: context.workspaceRoot) else { return AssistToolKit.invalid("destination must be inside the workspace.") }
        if FileManager.default.fileExists(atPath: dest.path), !AssistToolKit.bool(input, "overwrite", default: false) { return AssistToolKit.invalid("\(destRaw) exists; pass overwrite=true.") }
        let r = await AssistToolKit.httpRequest(url: url, method: "GET", timeout: 120)
        if let e = r.error { var f = AssistToolResult.failure("Download failed: \(e)"); f.toolErrorCode = .executionFailed; return f }
        guard (200..<300).contains(r.status) else { var f = AssistToolResult.failure("Server returned HTTP \(r.status)."); f.toolErrorCode = .executionFailed; return f }
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try r.body.write(to: dest, options: .atomic)
        return .success("Downloaded \(r.body.count) bytes to \(destRaw)\nsha256: \(AssistToolKit.digest(r.body, algorithm: "sha256") ?? "")", data: ["bytes": String(r.body.count)], filesChanged: [destRaw])
    }
}


public struct XKGithubRepositoryInfoTool: AssistTool {
    public init() {}
    public var id: String { "github_repository_info" }
    public var name: String { "GitHub Repository Info" }
    public var description: String { "Fetches public metadata for GitHub repository `repo` (owner/name): description, stars, default branch, license, topics, latest release." }
    public var capability: ToolCapability { .general }
    public var riskLevel: ToolRiskLevel { .externalSideEffect }
    public var isReadOnly: Bool { false }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Fetches public metadata for GitHub repository `repo` (owner/name): description, stars, default branch, license, topics, latest release.", properties: ["repo": JSONSchema(type: "string", description: "owner/name")], required: ["repo"])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        guard let repo = AssistToolKit.string(input, "repo"), repo.split(separator: "/").count == 2, repo.allSatisfy({ $0.isLetter || $0.isNumber || "-_./".contains($0) }) else { return AssistToolKit.invalid("repo must be owner/name.") }
        let h = ["Accept": "application/vnd.github+json", "User-Agent": "SwiftCode-Assist"]
        let r = await AssistToolKit.httpRequest(url: URL(string: "https://api.github.com/repos/\(repo)")!, method: "GET", headers: h)
        guard r.error == nil, r.status == 200, let o = try? JSONSerialization.jsonObject(with: r.body) as? [String: Any] else { return AssistToolKit.notFound("GitHub API returned \(r.status) \(r.error ?? "").") }
        let rel = await AssistToolKit.httpRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!, method: "GET", headers: h)
        let tag = (try? JSONSerialization.jsonObject(with: rel.body) as? [String: Any])?["tag_name"] as? String ?? "none"
        let lic = (o["license"] as? [String: Any])?["spdx_id"] as? String ?? "none"
        func field(_ k: String) -> String { o[k].map { "\($0)" } ?? "" }
        let topics: String = (o["topics"] as? [String])?.joined(separator: ", ") ?? ""
        var lines: [String] = []
        lines.append("repo: " + (field("full_name").isEmpty ? repo : field("full_name")))
        lines.append("description: " + field("description"))
        lines.append("stars: " + field("stargazers_count"))
        lines.append("forks: " + field("forks_count"))
        lines.append("open_issues: " + field("open_issues_count"))
        lines.append("default_branch: " + field("default_branch"))
        lines.append("license: " + lic)
        lines.append("topics: " + topics)
        lines.append("latest_release: " + tag)
        lines.append("pushed_at: " + field("pushed_at"))
        return .success(lines.joined(separator: "\n"))
    }
}
