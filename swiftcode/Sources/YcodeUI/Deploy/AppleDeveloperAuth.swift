import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif


public enum AppleIDAuthError: Error, Equatable, LocalizedError {
    
    case invalidCredentials
    
    case termsNotAccepted
    
    
    case appleService(String)
    
    case httpStatus(Int, String?)
    
    case malformedResponse(String)
    
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


public struct AppleTrustedDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}


public enum AppleTwoFactorDelivery: Hashable, Sendable {
    
    
    case trustedDevice
    
    case phone(String)
    
    
    case device(String)
}



public struct AppleTwoFactorContext: Sendable {
    public let codeLength: Int
    public let phones: [AppleTrustedPhone]
    public let devices: [AppleTrustedDevice]
    
    
    public let smsFallbackOnly: Bool

    public init(codeLength: Int, phones: [AppleTrustedPhone], devices: [AppleTrustedDevice], smsFallbackOnly: Bool) {
        self.codeLength = codeLength
        self.phones = phones
        self.devices = devices
        self.smsFallbackOnly = smsFallbackOnly
    }
}


public enum AppleIDSignInOutcome: Sendable {
    
    case signedIn
    
    case twoFactorRequired(AppleTwoFactorContext)
}




public enum AppleServiceKey {
    public static let cacheKey = "apple.services.widgetKey"

    
    
    
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


private final class RedirectRefusingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}




public enum AppleHashcash {
    public static func mint(bits: Int, challenge: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let stamp = formatter.string(from: date)
        var counter = 0
        
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














public final class AppleIDAuthClient: @unchecked Sendable {
    
    
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

    

    
    
    
    public func signIn(appleID: String, password: String) async throws -> AppleIDSignInOutcome {
        
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

    

    
    
    
    public func requestTwoFactorCode(delivery: AppleTwoFactorDelivery, context: AppleTwoFactorContext) async throws {
        switch delivery {
        case .trustedDevice:
            
            
            break
        case .device(let deviceID):
            
            
            try await putVerificationPath("verify/device/\(deviceID)/securitycode", body: nil)
        case .phone(let phoneID):
            let pushMode = context.phones.first(where: { $0.id == phoneID })?.pushMode ?? "sms"
            try await putVerificationPath("verify/phone", body: [
                "phoneNumber": ["id": phoneID],
                "mode": pushMode,
            ])
        }
    }

    
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

    
    
    private func getTrustSession() async throws {
        guard let url = URL(string: "https://idmsa.apple.com/appleauth/auth/2sv/trust") else { return }
        var request = URLRequest(url: url)
        applySessionHeaders(to: &request)
        _ = try await Self.sharedSession.data(for: request)
    }

    

    
    public struct AppleTeam: Hashable, Sendable {
        public let teamID: String
        public let name: String
        
        public let source: String
    }

    
    
    
    
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
