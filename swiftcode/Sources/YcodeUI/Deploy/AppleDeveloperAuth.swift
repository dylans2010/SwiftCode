import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Errors surfaced by the real Apple ID / developer-portal sign-in flow.
public enum AppleIDAuthError: Error, Equatable, LocalizedError {
    /// Apple rejected the Apple ID / password pair.
    case invalidCredentials
    /// The account must accept Apple's latest Apple ID / privacy terms first.
    case termsNotAccepted
    /// Apple reported a service-level failure (bad verification code, locked
    /// account, no trusted devices, ...). `message` is Apple's own text.
    case appleService(String)
    /// A non-2xx HTTP response from an Apple endpoint.
    case httpStatus(Int, String?)
    /// The JSON body could not be interpreted.
    case malformedResponse(String)
    /// The transport layer failed.
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Apple rejected the Apple ID or password. Check both and try again."
        case .termsNotAccepted:
            return "This Apple Account must accept Apple's latest terms first. "
                + "Sign in once at appleid.apple.com (or appstoreconnect.apple.com) in a browser, "
                + "accept the agreement, then try again."
        case .appleService(let message):
            return message
        case .httpStatus(let status, let detail):
            if let detail, !detail.isEmpty { return "Apple returned HTTP \(status): \(detail)" }
            return "Apple returned HTTP \(status)."
        case .malformedResponse(let what):
            return "Unexpected response from Apple while \(what)."
        case .transport(let message):
            return message
        }
    }
}

/// A trusted phone number Apple can text a two-factor code to.
public struct AppleTrustedPhone: Identifiable, Hashable, Sendable {
    public let id: String
    public let numberWithDialCode: String
    public let pushMode: String

    public init(id: String, numberWithDialCode: String, pushMode: String) {
        self.id = id
        self.numberWithDialCode = numberWithDialCode
        self.pushMode = pushMode
    }
}

/// A trusted device (2-step verification) that can display a code.
public struct AppleTrustedDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// How the user wants the second factor delivered.
public enum AppleTwoFactorDelivery: Hashable, Sendable {
    /// The code is pushed automatically to the user's trusted devices
    /// (modern two-factor authentication).
    case trustedDevice
    /// A specific trusted phone number; the code is texted/called to it.
    case phone(String)
    /// A specific legacy two-step trusted device; the code is requested on
    /// that device and verified through the phone/securitycode endpoint.
    case device(String)
}

/// State captured when Apple answers the password step with HTTP 409 and
/// asks for a two-factor / two-step code.
public struct AppleTwoFactorContext: Sendable {
    public let codeLength: Int
    public let phones: [AppleTrustedPhone]
    public let devices: [AppleTrustedDevice]
    /// True when the account has no trusted devices and Apple can only fall
    /// back to SMS (`noTrustedDevices` in the auth response).
    public let smsFallbackOnly: Bool

    public init(codeLength: Int, phones: [AppleTrustedPhone], devices: [AppleTrustedDevice], smsFallbackOnly: Bool) {
        self.codeLength = codeLength
        self.phones = phones
        self.devices = devices
        self.smsFallbackOnly = smsFallbackOnly
    }
}

/// How the Apple ID sign-in ended.
public enum AppleIDSignInOutcome: Sendable {
    /// Password accepted; the session cookie jar now holds a valid session.
    case signedIn
    /// Apple requires a verification code; `context` describes the options.
    case twoFactorRequired(AppleTwoFactorContext)
}

/// The `widgetKey` / `authServiceKey` Apple issues to first-party web clients.
/// It rotates, so it is fetched live (with a cached fallback) rather than
/// hard-coded.
public enum AppleServiceKey {
    public static let cacheKey = "apple.services.widgetKey"

    /// Fetches the current service key. Order matches what real clients do:
    /// the `/logout` redirect carries `widgetKey` in its Location header, and
    /// the olympus app-config endpoint exposes `authServiceKey` as a fallback.
    public static func fetch(defaults: UserDefaults = .standard) async throws -> String {
        if let cached = defaults.string(forKey: cacheKey), !cached.isEmpty {
            return cached
        }

        if let key = try? await fetchFromSignoutRedirect(), !key.isEmpty {
            defaults.set(key, forKey: cacheKey)
            return key
        }

        if let key = try? await fetchFromOlympusConfig(), !key.isEmpty {
            defaults.set(key, forKey: cacheKey)
            return key
        }

        throw AppleIDAuthError.appleService(
            "Could not obtain the Apple sign-in service key. Check your network connection and try again."
        )
    }

    /// `HEAD https://appstoreconnect.apple.com/logout` answers 302 with a
    /// `Location: .../signout?...&widgetKey=<key>` header. The request must
    /// not follow the redirect (that would sign out) and must not send the
    /// session cookies, so it uses a dedicated session with a delegate that
    /// refuses redirects.
    private static func fetchFromSignoutRedirect() async throws -> String {
        guard let url = URL(string: "https://appstoreconnect.apple.com/logout") else {
            throw AppleIDAuthError.malformedResponse("logout URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: RedirectRefusingDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let location = http.value(forHTTPHeaderField: "Location"),
              !location.isEmpty,
              let components = URLComponents(string: location),
              let items = components.queryItems,
              let key = items.first(where: { $0.name == "widgetKey" })?.value,
              !key.isEmpty else {
            throw AppleIDAuthError.malformedResponse("sign-out redirect")
        }
        return key
    }

    /// `GET https://appstoreconnect.apple.com/olympus/v1/app/config?hostname=itunesconnect.apple.com`
    /// returns JSON containing `authServiceKey`.
    private static func fetchFromOlympusConfig() async throws -> String {
        guard let url = URL(string: "https://appstoreconnect.apple.com/olympus/v1/app/config?hostname=itunesconnect.apple.com") else {
            throw AppleIDAuthError.malformedResponse("olympus config URL")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await AppleIDAuthClient.sharedSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppleIDAuthError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1, nil)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = object["authServiceKey"] as? String, !key.isEmpty else {
            throw AppleIDAuthError.malformedResponse("olympus app config")
        }
        return key
    }
}

/// Prevents URLSession from following the `/logout` redirect.
private final class RedirectRefusingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Apple's hashcash challenge (`X-Apple-HC`): a SHA-1 partial preimage over
/// `1:<bits>:<yyyyMMddHHmmss>:<challenge>::<counter>` requiring `bits`
/// leading zero bits. Required by the idmsa sign-in endpoints.
public enum AppleHashcash {
    public static func mint(bits: Int, challenge: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let stamp = formatter.string(from: date)
        var counter = 0
        // bits is small (Apple uses ~11-20); cap defensively at the digest size.
        let effectiveBits = max(0, min(bits, 160))
        while true {
            let candidate = "1:\(effectiveBits):\(stamp):\(challenge)::\(counter)"
            #if canImport(CryptoKit)
            let digest = Insecure.SHA1.hash(data: Data(candidate.utf8))
            var leading = 0
            for byte in digest {
                if byte == 0 {
                    leading += 8
                } else {
                    leading += byte.leadingZeroBitCount
                    break
                }
            }
            if leading >= effectiveBits { return candidate }
            #else
            return candidate
            #endif
            counter += 1
        }
    }
}

/// A real client for Apple's account sign-in endpoints (the same endpoints
/// Xcode and other developer tools use):
///
///   idmsa.apple.com/appleauth/auth/signin          — password step
///   idmsa.apple.com/appleauth/auth                 — 2FA options
///   idmsa.apple.com/appleauth/auth/verify/...      — code verification
///   idmsa.apple.com/appleauth/auth/2sv/trust       — mark session trusted
///   appstoreconnect.apple.com/olympus/v1/session   — team/provider list
///   developer.apple.com/services-account/QH65B2/…  — developer portal teams
///
/// Session state lives in the shared `HTTPCookieStorage`, exactly like a
/// browser session: Apple sets `.apple.com` domain cookies that are then sent
/// to both idmsa and appstoreconnect/developer hosts.
public final class AppleIDAuthClient: @unchecked Sendable {
    /// Shared session so cookies set by idmsa.apple.com are visible to
    /// appstoreconnect.apple.com and developer.apple.com.
    public static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        return URLSession(configuration: configuration)
    }()

    private let widgetKey: String
    private var xAppleIDSessionID = ""
    private var scnt = ""

    public init(widgetKey: String) {
        self.widgetKey = widgetKey
    }

    // MARK: - Password step

    /// Performs the password sign-in. Returns `.twoFactorRequired` when Apple
    /// answers 409 (2FA/2-step enabled) — the verification code has already
    /// been pushed to the account's trusted devices at that point.
    public func signIn(appleID: String, password: String) async throws -> AppleIDSignInOutcome {
        // 1. Hashcash challenge for the sign-in endpoints.
        var hashcash: String?
        if let hc = try? await fetchHashcashChallenge() {
            hashcash = hc
        }

        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth/signin") else {
            throw AppleIDAuthError.malformedResponse("sign-in URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(widgetKey, forHTTPHeaderField: "X-Apple-Widget-Key")
        if let hashcash { request.setValue(hashcash, forHTTPHeaderField: "X-Apple-HC") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "accountName": appleID,
            "password": password,
            "rememberMe": true,
        ])

        let (data, response) = try await Self.sharedSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppleIDAuthError.malformedResponse("sign-in response")
        }
        let bodyText = String(data: data, encoding: .utf8) ?? ""

        switch http.statusCode {
        case 200:
            return .signedIn
        case 401, 403:
            throw AppleIDAuthError.invalidCredentials
        case 409:
            xAppleIDSessionID = http.value(forHTTPHeaderField: "x-apple-id-session-id") ?? ""
            scnt = http.value(forHTTPHeaderField: "scnt") ?? ""
            return .twoFactorRequired(try await fetchTwoFactorOptions())
        case 412:
            // Apple ID / privacy acknowledgement or 2FA-upgrade required.
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let authType = object["authType"] as? String,
               ["sa", "hsa", "non-sa", "hsa2"].contains(authType) {
                throw AppleIDAuthError.termsNotAccepted
            }
            throw AppleIDAuthError.termsNotAccepted
        default:
            if bodyText.contains("invalid=\"true\"") {
                throw AppleIDAuthError.invalidCredentials
            }
            throw AppleIDAuthError.appleService(serviceErrorMessage(from: data) ?? "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Two-factor options

    /// `GET https://idmsa.apple.com/appleauth/auth` lists the trusted devices
    /// and phone numbers a code can be sent to.
    private func fetchTwoFactorOptions() async throws -> AppleTwoFactorContext {
        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth") else {
            throw AppleIDAuthError.malformedResponse("auth options URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applySessionHeaders(to: &request)

        let (data, response) = try await Self.sharedSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppleIDAuthError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1,
                                              serviceErrorMessage(from: data))
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppleIDAuthError.malformedResponse("two-factor options")
        }

        if let serviceErrors = object["serviceErrors"] as? [[String: Any]], !serviceErrors.isEmpty {
            let message = serviceErrors.compactMap { $0["message"] as? String }.joined(separator: " ")
            var suffix = ""
            if object["noTrustedDevices"] as? Bool == true {
                suffix = " This Apple ID has no trusted devices: signing in to it on an Apple device adds one."
            }
            throw AppleIDAuthError.appleService("Apple could not start two-factor authentication: \(message)\(suffix)")
        }

        let codeLength = (object["securityCode"] as? [String: Any])?["length"] as? Int ?? 6

        let phones: [AppleTrustedPhone] = (object["trustedPhoneNumbers"] as? [[String: Any]] ?? []).compactMap { phone in
            guard let id = phone["id"] as? String else { return nil }
            return AppleTrustedPhone(
                id: id,
                numberWithDialCode: phone["numberWithDialCode"] as? String ?? "",
                pushMode: phone["pushMode"] as? String ?? "sms"
            )
        }

        let devices: [AppleTrustedDevice] = (object["trustedDevices"] as? [[String: Any]] ?? []).compactMap { device in
            guard let id = device["id"] as? String else { return nil }
            let name = device["name"] as? String ?? device["modelName"] as? String ?? "Trusted device"
            return AppleTrustedDevice(id: id, name: name)
        }

        return AppleTwoFactorContext(
            codeLength: codeLength,
            phones: phones,
            devices: devices,
            smsFallbackOnly: object["noTrustedDevices"] as? Bool == true
        )
    }

    // MARK: - Verification

    /// Asks Apple to send a code to the chosen destination. For the modern
    /// flow the code is pushed automatically and this is a no-op unless an
    /// SMS/phone fallback was picked.
    public func requestTwoFactorCode(delivery: AppleTwoFactorDelivery, context: AppleTwoFactorContext) async throws {
        switch delivery {
        case .trustedDevice:
            // Modern two-factor authentication pushes the code automatically
            // when the password step returned 409 — nothing to request.
            break
        case .device(let deviceID):
            // Legacy two-step verification: poke the chosen device so it
            // displays a code.
            try await putVerificationPath("verify/device/\(deviceID)/securitycode", body: nil)
        case .phone(let phoneID):
            let pushMode = context.phones.first(where: { $0.id == phoneID })?.pushMode ?? "sms"
            try await putVerificationPath("verify/phone", body: [
                "phoneNumber": ["id": phoneID],
                "mode": pushMode,
            ])
        }
    }

    /// Submits the code the user received.
    public func verifyTwoFactorCode(_ code: String, delivery: AppleTwoFactorDelivery, context: AppleTwoFactorContext) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppleIDAuthError.appleService("Enter the verification code Apple sent you.")
        }

        let path: String
        let body: [String: Any]
        switch delivery {
        case .trustedDevice:
            if context.phones.isEmpty, let device = context.devices.first {
                // Two-step verification fallback: the code goes back keyed
                // by the trusted device id.
                path = "verify/phone/securitycode"
                body = [
                    "phoneNumber": ["id": device.id],
                    "securityCode": ["code": trimmed],
                    "mode": "sms",
                ]
            } else {
                path = "verify/trusteddevice/securitycode"
                body = ["securityCode": ["code": trimmed]]
            }
        case .device(let deviceID):
            path = "verify/phone/securitycode"
            body = [
                "phoneNumber": ["id": deviceID],
                "securityCode": ["code": trimmed],
                "mode": "sms",
            ]
        case .phone(let phoneID):
            let pushMode = context.phones.first(where: { $0.id == phoneID })?.pushMode ?? "sms"
            path = "verify/phone/securitycode"
            body = [
                "securityCode": ["code": trimmed],
                "phoneNumber": ["id": phoneID],
                "mode": pushMode,
            ]
        }

        try await postVerificationPath(path, body: body)

        // Mark the browser-like session as trusted so Apple issues longer
        // lived cookies. Best effort: failure here does not invalidate the
        // session we just created.
        try? await getTrustSession()
    }

    private func putVerificationPath(_ path: String, body: [String: Any]?) async throws {
        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth/\(path)") else {
            throw AppleIDAuthError.malformedResponse(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySessionHeaders(to: &request)
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await Self.sharedSession.data(for: request)
        try checkVerificationResponse(data: data, response: response)
    }

    private func postVerificationPath(_ path: String, body: [String: Any]) async throws {
        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth/\(path)") else {
            throw AppleIDAuthError.malformedResponse(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySessionHeaders(to: &request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await Self.sharedSession.data(for: request)
        try checkVerificationResponse(data: data, response: response)
    }

    private func checkVerificationResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AppleIDAuthError.malformedResponse("verification response")
        }
        if let message = serviceErrorMessage(from: data), !message.isEmpty {
            throw AppleIDAuthError.appleService(message)
        }
        guard (200...299).contains(http.statusCode) else {
            throw AppleIDAuthError.httpStatus(http.statusCode, nil)
        }
    }

    /// `GET https://idmsa.apple.com/appleauth/auth/2sv/trust` upgrades the
    /// session cookies. Returns normally on success; callers ignore errors.
    private func getTrustSession() async throws {
        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth/2sv/trust") else { return }
        var request = URLRequest(url: url)
        applySessionHeaders(to: &request)
        _ = try await Self.sharedSession.data(for: request)
    }

    // MARK: - Teams

    /// A developer team the signed-in Apple Account belongs to.
    public struct AppleTeam: Hashable, Sendable {
        public let teamID: String
        public let name: String
        /// "developerPortal" or "appStoreConnect" — where the row came from.
        public let source: String
    }

    /// Fetches the teams for the current session. The developer portal
    /// `listTeams.action` endpoint returns the real Developer Program team
    /// IDs used for code signing; the App Store Connect olympus session lists
    /// `availableProviders`. Both are merged, de-duplicated by team ID.
    public func fetchTeams() async throws -> [AppleTeam] {
        var teams: [AppleTeam] = []
        var seen = Set<String>()

        if let portalTeams = try? await fetchDeveloperPortalTeams() {
            for team in portalTeams where !seen.contains(team.teamID) {
                seen.insert(team.teamID)
                teams.append(team)
            }
        }

        if let providers = try? await fetchAppStoreConnectProviders() {
            for provider in providers where !seen.contains(provider.teamID) {
                seen.insert(provider.teamID)
                teams.append(provider)
            }
        }

        guard !teams.isEmpty else {
            throw AppleIDAuthError.appleService(
                "Signed in successfully, but Apple did not return any developer teams for this account. "
                + "Make sure the account has an active Apple Developer Program or App Store Connect membership."
            )
        }
        return teams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// `POST https://developer.apple.com/services-account/QH65B2/account/listTeams.action`
    /// — the developer portal endpoint behind Xcode's account team list.
    private func fetchDeveloperPortalTeams() async throws -> [AppleTeam] {
        guard let url = URL(string: "https://developer.apple.com/services-account/QH65B2/account/listTeams.action") else {
            throw AppleIDAuthError.malformedResponse("listTeams URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, response) = try await Self.sharedSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppleIDAuthError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1, nil)
        }

        // The QH65B2 protocol answers JSON; guard against plist just in case.
        var object: [String: Any]?
        if let json = try? JSONSerialization.jsonObject(with: data) {
            object = json as? [String: Any]
        } else if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
            object = plist as? [String: Any]
        }
        guard let root = object else {
            throw AppleIDAuthError.malformedResponse("listTeams response")
        }

        if let resultString = root["resultString"] as? String,
           resultString.localizedCaseInsensitiveContains("notallowed") {
            throw AppleIDAuthError.appleService("This Apple Account does not have permission to list developer teams.")
        }

        let rows = (root["teams"] as? [[String: Any]]) ?? []
        return rows.compactMap { row in
            guard let teamID = row["teamId"] as? String, !teamID.isEmpty else { return nil }
            let name = (row["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? teamID
            return AppleTeam(teamID: teamID, name: name, source: "developerPortal")
        }
    }

    /// `GET https://appstoreconnect.apple.com/olympus/v1/session` — returns
    /// the signed-in user plus `availableProviders` (App Store Connect teams).
    private func fetchAppStoreConnectProviders() async throws -> [AppleTeam] {
        guard let url = URL(string: "https://appstoreconnect.apple.com/olympus/v1/session") else {
            throw AppleIDAuthError.malformedResponse("olympus session URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await Self.sharedSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppleIDAuthError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1, nil)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppleIDAuthError.malformedResponse("olympus session")
        }

        let providers = (object["availableProviders"] as? [[String: Any]]) ?? []
        return providers.compactMap { provider in
            guard let teamID = provider["providerId"] as? String, !teamID.isEmpty else { return nil }
            let name = (provider["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? teamID
            return AppleTeam(teamID: teamID, name: name, source: "appStoreConnect")
        }
    }

    // MARK: - Helpers

    /// `GET https://idmsa.apple.com/appleauth/auth/signin?widgetKey=…` returns
    /// the `X-Apple-HC-Bits` / `X-Apple-HC-Challenge` headers used to mint the
    /// hashcash stamp.
    private func fetchHashcashChallenge() async throws -> String? {
        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth/signin?widgetKey=\(widgetKey)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (_, response) = try await Self.sharedSession.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let bitsString = http.value(forHTTPHeaderField: "X-Apple-HC-Bits"),
              let bits = Int(bitsString),
              let challenge = http.value(forHTTPHeaderField: "X-Apple-HC-Challenge"),
              !challenge.isEmpty else {
            return nil
        }
        return AppleHashcash.mint(bits: bits, challenge: challenge)
    }

    private func applySessionHeaders(to request: inout URLRequest) {
        if !xAppleIDSessionID.isEmpty {
            request.setValue(xAppleIDSessionID, forHTTPHeaderField: "X-Apple-Id-Session-Id")
        }
        request.setValue(widgetKey, forHTTPHeaderField: "X-Apple-Widget-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !scnt.isEmpty {
            request.setValue(scnt, forHTTPHeaderField: "scnt")
        }
    }

    /// Extracts Apple's `serviceErrors[].message` text from a JSON body, if
    /// present. Verification failures (e.g. a wrong code) arrive this way with
    /// HTTP 200.
    private func serviceErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var parts: [String] = []
        if let errors = object["serviceErrors"] as? [[String: Any]] {
            parts += errors.compactMap { $0["message"] as? String }
        }
        if let errors = object["validationErrors"] as? [[String: Any]] {
            parts += errors.compactMap { ($0["message"] ?? $0["title"]) as? String }
        }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
}
