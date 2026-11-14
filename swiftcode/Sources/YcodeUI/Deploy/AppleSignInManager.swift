import Foundation
import Observation
import Security
import CryptoKit
import os.log
import YcodeAssistant

private let logger = Logger(subsystem: "com.swiftcode.Build", category: "AppleSignIn")

extension KeychainService {
    @discardableResult
    public func save(_ value: String, forKey key: String) -> Bool {
        return self.set(value, forKey: key)
    }
}

public struct AppStoreConnectJWT: Sendable {
    public static func generate(
        keyID: String,
        issuerID: String,
        privateKeyPEM: String,
        expirationMinutes: Int = 20
    ) throws -> String {
        let header: [String: String] = [
            "alg": "ES256",
            "kid": keyID,
            "typ": "JWT"
        ]
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [])
        let headerBase64 = base64URL(headerData)

        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": issuerID,
            "iat": now,
            "exp": now + (expirationMinutes * 60),
            "aud": "appstoreconnect-v1"
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let payloadBase64 = base64URL(payloadData)

        let unsignedToken = "\(headerBase64).\(payloadBase64)"
        guard let unsignedData = unsignedToken.data(using: .utf8) else {
            throw NSError(
                domain: "AppStoreConnectJWT",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert unsigned token to data"]
            )
        }

        var pem = privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pem.contains("-----BEGIN PRIVATE KEY-----") {
            pem = "-----BEGIN PRIVATE KEY-----\n\(pem)\n-----END PRIVATE KEY-----"
        }
        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: pem)

        let signature = try privateKey.signature(for: unsignedData)
        let signatureBase64 = base64URL(signature.rawRepresentation)

        return "\(unsignedToken).\(signatureBase64)"
    }

    private static func base64URL(_ data: Data) -> String {
        var base64 = data.base64EncodedString()
        base64 = base64.replacingOccurrences(of: "+", with: "-")
        base64 = base64.replacingOccurrences(of: "/", with: "_")
        base64 = base64.replacingOccurrences(of: "=", with: "")
        return base64
    }
}

@Observable
@MainActor
public final class AppleSignInManager: Sendable {
    public static let shared = AppleSignInManager()

    public var developerAccounts: [AppleDeveloperAccount] = []
    public var selectedTeamID: String?
    public var sessionState: SessionState = .signedOut
    public var lastError: String?

    
    
    public private(set) var twoFactorContext: AppleTwoFactorContext?
    
    public private(set) var twoFactorDelivery: AppleTwoFactorDelivery = .trustedDevice
    
    
    public private(set) var twoFactorCodeRequested = false

    private var authClient: AppleIDAuthClient?
    private var pendingAppleID = ""

    public enum SessionState: String, Sendable, Codable {
        case signedOut = "Signed Out"
        case loading = "Loading..."
        case signedIn = "Signed In"
        case expired = "Session Expired"
        case verificationRequired = "Verification Required"
    }

    public struct CertificateInfo: Identifiable, Sendable, Codable {
        public var id: String { serialNumber }
        public let name: String
        public let type: String
        public let displayName: String
        public let serialNumber: String
        public let expirationDate: String
        public let content: String
    }

    public struct AppleDeveloperAccount: Identifiable, Sendable, Codable {
        
        
        public var id: String { "\(appleID)#\(teamID)" }
        
        
        public let appleID: String
        public let teamName: String
        public let teamID: String
        public let certificateName: String
        public let keyID: String?
        public let issuerID: String?
        public let certificates: [CertificateInfo]?
        
        public let authMethod: String?

        public init(
            appleID: String,
            teamName: String,
            teamID: String,
            certificateName: String,
            keyID: String?,
            issuerID: String?,
            certificates: [CertificateInfo]?,
            authMethod: String? = nil
        ) {
            self.appleID = appleID
            self.teamName = teamName
            self.teamID = teamID
            self.certificateName = certificateName
            self.keyID = keyID
            self.issuerID = issuerID
            self.certificates = certificates
            self.authMethod = authMethod
        }
    }

    private init() {
        loadAccounts()
    }

    

    public func fetchCertificates(jwt: String) async throws -> [CertificateInfo] {
        guard let url = URL(string: "https://api.appstoreconnect.apple.com/v1/certificates") else {
            throw NSError(
                domain: "AppleSignInManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AppleSignInManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid server response"]
            )
        }

        if httpResponse.statusCode != 200 {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errors = errorJSON["errors"] as? [[String: Any]],
               let firstError = errors.first,
               let detail = firstError["detail"] as? String {
                throw NSError(
                    domain: "AppleSignInManager",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: detail]
                )
            }
            throw NSError(
                domain: "AppleSignInManager",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "App Store Connect API returned status \(httpResponse.statusCode)"]
            )
        }

        struct ASCertificatesResponse: Decodable {
            let data: [ASCertificateData]
        }
        struct ASCertificateData: Decodable {
            let id: String
            let attributes: ASCertificateAttributes
        }
        struct ASCertificateAttributes: Decodable {
            let name: String
            let certificateType: String
            let displayName: String
            let serialNumber: String
            let expirationDate: String
            let certificateContent: String
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(ASCertificatesResponse.self, from: data)

        return result.data.map { cert in
            CertificateInfo(
                name: cert.attributes.name,
                type: cert.attributes.certificateType,
                displayName: cert.attributes.displayName,
                serialNumber: cert.attributes.serialNumber,
                expirationDate: cert.attributes.expirationDate,
                content: cert.attributes.certificateContent
            )
        }
    }

    
    
    private func fetchAppCount(jwt: String) async throws -> Int {
        guard let url = URL(string: "https://api.appstoreconnect.apple.com/v1/apps?limit=1") else {
            throw NSError(domain: "AppleSignInManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "AppleSignInManager",
                          code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "App Store Connect API returned status \((response as? HTTPURLResponse)?.statusCode ?? -1)"])
        }
        struct AppsResponse: Decodable { let data: [AppsData] }
        struct AppsData: Decodable { let id: String }
        return (try? JSONDecoder().decode(AppsResponse.self, from: data))?.data.count ?? 0
    }

    
    
    
    
    public func addAppStoreConnectAPIKey(
        label: String,
        keyID: String,
        issuerID: String,
        privateKeyPEM: String
    ) async {
        sessionState = .loading
        lastError = nil
        twoFactorContext = nil

        let trimmedKeyID = keyID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIssuer = issuerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKeyID.isEmpty, !trimmedIssuer.isEmpty, !trimmedKey.isEmpty else {
            sessionState = developerAccounts.isEmpty ? .signedOut : .signedIn
            lastError = "Key ID, Issuer ID, and the .p8 private key are all required."
            return
        }

        do {
            let jwt = try AppStoreConnectJWT.generate(
                keyID: trimmedKeyID,
                issuerID: trimmedIssuer,
                privateKeyPEM: trimmedKey
            )

            
            
            var certificates: [CertificateInfo]?
            var keyValidated = false
            do {
                certificates = try await fetchCertificates(jwt: jwt)
                keyValidated = true
            } catch let error as NSError where error.code == 403 {
                _ = try await fetchAppCount(jwt: jwt)
                keyValidated = true
            }
            guard keyValidated else { throw AppleIDAuthError.invalidCredentials }

            let identity = Self.teamIdentity(from: certificates?.first)
            let accountLabel = trimmedLabel.isEmpty ? "App Store Connect API Key" : trimmedLabel

            let account = AppleDeveloperAccount(
                appleID: accountLabel,
                teamName: identity.teamName,
                teamID: identity.teamID,
                certificateName: certificates?.first?.name ?? "Apple Development",
                keyID: trimmedKeyID,
                issuerID: trimmedIssuer,
                certificates: certificates,
                authMethod: "appStoreConnectAPIKey"
            )

            let stored = KeychainService.shared.save(trimmedKey, forKey: "apple_asc_key_\(trimmedKeyID)")
                && KeychainService.shared.save(trimmedIssuer, forKey: "apple_asc_issuer_\(trimmedKeyID)")

            guard stored else {
                sessionState = .signedOut
                lastError = "The API key was verified, but SwiftCode could not store it in the local credential store."
                return
            }

            developerAccounts.removeAll { $0.authMethod == "appStoreConnectAPIKey" && $0.keyID == trimmedKeyID }
            developerAccounts.append(account)
            if !identity.teamID.isEmpty { selectedTeamID = identity.teamID }
            sessionState = .signedIn
            saveAccounts()
        } catch let error as AppleIDAuthError {
            sessionState = developerAccounts.isEmpty ? .signedOut : .signedIn
            lastError = error.localizedDescription
            logger.error("App Store Connect API key validation failed: \(error.localizedDescription, privacy: .public)")
        } catch {
            sessionState = developerAccounts.isEmpty ? .signedOut : .signedIn
            lastError = "API key validation failed: \(error.localizedDescription)"
            logger.error("API key validation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    
    
    
    
    private static func teamIdentity(from certificate: CertificateInfo?) -> (teamID: String, teamName: String) {
        guard let certificate, !certificate.content.isEmpty,
              let der = Data(base64Encoded: certificate.content) else {
            return ("", "App Store Connect Team")
        }

        var teamID = ""
        var teamName = ""

        if let ou = derStringValue(in: der, oid: [0x55, 0x04, 0x0B]) { 
            teamID = ou
        }
        if let org = derStringValue(in: der, oid: [0x55, 0x04, 0x0A]) { 
            teamName = org
        }
        if teamID.isEmpty {
            
            if let open = certificate.name.lastIndex(of: "("),
               certificate.name.hasSuffix(")") {
                let candidate = String(certificate.name[certificate.name.index(after: open)..<certificate.name.index(before: certificate.name.endIndex)])
                if candidate.count == 10, candidate.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    teamID = candidate
                }
            }
        }
        if teamName.isEmpty {
            teamName = teamID.isEmpty ? "App Store Connect Team" : "Team \(teamID)"
        }
        return (teamID, teamName)
    }

    
    
    
    private static func derStringValue(in data: Data, oid: [UInt8]) -> String? {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty, oid.count <= bytes.count else { return nil }
        var position = 0
        while position + oid.count <= bytes.count {
            var matches = true
            for offset in 0..<oid.count where bytes[position + offset] != oid[offset] {
                matches = false
                break
            }
            guard matches else {
                position += 1
                continue
            }
            
            
            
            guard position >= 2, bytes[position - 2] == 0x06, bytes[position - 1] == 0x03 else {
                position += 1
                continue
            }
            var index = position + oid.count
            guard index < bytes.count else { return nil }
            let tag = bytes[index]
            index += 1
            guard index < bytes.count else { return nil }
            var length = Int(bytes[index])
            index += 1
            if length & 0x80 != 0 {
                let numBytes = length & 0x7F
                guard numBytes > 0, numBytes <= 4, index + numBytes <= bytes.count else { return nil }
                length = 0
                for _ in 0..<numBytes {
                    length = (length << 8) | Int(bytes[index])
                    index += 1
                }
            }
            guard length > 0, index + length <= bytes.count else { return nil }
            
            
            if [0x0C, 0x13, 0x16, 0x1E].contains(tag) {
                let value = Data(bytes[index..<index+length])
                if let string = String(data: value, encoding: .utf8), !string.isEmpty {
                    return string
                }
            }
            position = index + length
        }
        return nil
    }

    

    
    
    
    
    
    public func signInWithAppleID(appleID: String, password: String) async {
        sessionState = .loading
        lastError = nil
        twoFactorContext = nil
        twoFactorCodeRequested = false

        let trimmedID = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !password.isEmpty else {
            sessionState = .signedOut
            lastError = "Apple ID and password are required."
            return
        }

        do {
            let widgetKey = try await AppleServiceKey.fetch()
            let client = AppleIDAuthClient(widgetKey: widgetKey)
            self.authClient = client
            self.pendingAppleID = trimmedID

            let outcome = try await client.signIn(appleID: trimmedID, password: password)
            switch outcome {
            case .signedIn:
                try await completeAppleIDSignIn()
            case .twoFactorRequired(let context):
                twoFactorContext = context
                if context.smsFallbackOnly, let phone = context.phones.first {
                    twoFactorDelivery = .phone(phone.id)
                } else if context.phones.isEmpty, let device = context.devices.first {
                    
                    
                    twoFactorDelivery = .device(device.id)
                } else {
                    twoFactorDelivery = .trustedDevice
                }
                sessionState = .verificationRequired
            }
        } catch {
            sessionState = developerAccounts.isEmpty ? .signedOut : .signedIn
            lastError = (error as? AppleIDAuthError)?.localizedDescription
                ?? "Sign-in failed: \(error.localizedDescription)"
            logger.error("Apple ID sign-in failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    
    
    public func cancelPendingSignIn() {
        twoFactorContext = nil
        twoFactorCodeRequested = false
        authClient = nil
        pendingAppleID = ""
        sessionState = developerAccounts.isEmpty ? .signedOut : .signedIn
        lastError = nil
    }

    
    public func selectTwoFactorDelivery(_ delivery: AppleTwoFactorDelivery) {
        guard twoFactorContext != nil else { return }
        twoFactorDelivery = delivery
        twoFactorCodeRequested = false
    }

    
    public func requestTwoFactorCode() async {
        guard sessionState == .verificationRequired,
              let context = twoFactorContext,
              let client = authClient else { return }
        sessionState = .loading
        lastError = nil
        do {
            try await client.requestTwoFactorCode(delivery: twoFactorDelivery, context: context)
            twoFactorCodeRequested = true
            sessionState = .verificationRequired
        } catch {
            sessionState = .verificationRequired
            lastError = (error as? AppleIDAuthError)?.localizedDescription
                ?? "Could not send the verification code: \(error.localizedDescription)"
        }
    }

    
    
    public func verifyTwoFactorCode(_ code: String) async {
        guard sessionState == .verificationRequired,
              let context = twoFactorContext,
              let client = authClient else { return }
        sessionState = .loading
        lastError = nil

        do {
            
            
            
            
            if !twoFactorCodeRequested {
                try? await client.requestTwoFactorCode(delivery: twoFactorDelivery, context: context)
            }
            try await client.verifyTwoFactorCode(code, delivery: twoFactorDelivery, context: context)
            
            
            
            try await completeAppleIDSignIn()
            twoFactorContext = nil
            twoFactorCodeRequested = false
        } catch {
            sessionState = .verificationRequired
            lastError = (error as? AppleIDAuthError)?.localizedDescription
                ?? "Verification failed: \(error.localizedDescription)"
            logger.error("Two-factor verification failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    
    
    private func completeAppleIDSignIn() async throws {
        guard let client = authClient else {
            throw AppleIDAuthError.malformedResponse("missing auth client")
        }
        let teams = try await client.fetchTeams()

        developerAccounts.removeAll {
            ($0.authMethod ?? "appleID") == "appleID" && $0.appleID == pendingAppleID
        }
        for team in teams {
            developerAccounts.append(AppleDeveloperAccount(
                appleID: pendingAppleID,
                teamName: team.name,
                teamID: team.teamID,
                certificateName: "Apple Development",
                keyID: nil,
                issuerID: nil,
                certificates: nil,
                authMethod: "appleID"
            ))
        }
        selectedTeamID = teams.first?.teamID
        sessionState = .signedIn
        authClient = nil
        pendingAppleID = ""
        saveAccounts()
    }

    public func removeAccount(at indexSet: IndexSet) {
        for index in indexSet {
            let account = developerAccounts[index]
            _ = KeychainService.shared.delete(forKey: "apple_dev_key_\(account.appleID)_\(account.teamID)")
            _ = KeychainService.shared.delete(forKey: "apple_dev_password_\(account.appleID)")
            if let keyID = account.keyID {
                _ = KeychainService.shared.delete(forKey: "apple_asc_key_\(keyID)")
                _ = KeychainService.shared.delete(forKey: "apple_asc_issuer_\(keyID)")
            }
        }
        developerAccounts.remove(atOffsets: indexSet)
        if developerAccounts.isEmpty {
            sessionState = .signedOut
            selectedTeamID = nil
        } else {
            selectedTeamID = developerAccounts.first?.teamID
        }
        saveAccounts()
    }

    public func codesign(appPath: String, withCertificateName certificateName: String) async throws -> Bool {
        guard !appPath.isEmpty, !certificateName.isEmpty else {
            throw NSError(
                domain: "AppleSignInManager",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Invalid app path or certificate name"]
            )
        }

        let url = URL(fileURLWithPath: "/usr/bin/codesign")
        let arguments = [
            "-s", certificateName,
            "--force",
            "--deep",
            appPath
        ]

        logger.info("Executing codesign at path \(appPath, privacy: .public) with certificate \(certificateName, privacy: .public)")

        let result = try await ProcessRunnerTool.shared.run(
            executableURL: url,
            arguments: arguments
        )

        if result.exitCode == 0 {
            return true
        } else {
            let errorMsg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "AppleSignInManager",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: errorMsg.isEmpty ? "Codesign failed with exit code \(result.exitCode)" : errorMsg]
            )
        }
    }

    public func generateP12File(
        appleID: String,
        teamID: String,
        certificateName: String,
        certContentBase64: String,
        privateKeyPEM: String,
        outputURL: URL,
        passwordForP12: String
    ) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let keyURL = tempDir.appendingPathComponent("key.pem")
        let certURL = tempDir.appendingPathComponent("cert.pem")

        var pem = privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pem.contains("-----BEGIN PRIVATE KEY-----") {
            pem = "-----BEGIN PRIVATE KEY-----\n\(pem)\n-----END PRIVATE KEY-----\n"
        }
        
        let pemBody = pem
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pemBody.isEmpty else {
            throw NSError(domain: "AppleSignInManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "No private key is stored for this account. The .p8 App Store Connect key does not match development certificates; export requires the private key that created the certificate."])
        }
        guard let keyData = pem.data(using: .utf8) else {
            throw NSError(domain: "AppleSignInManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Stored private key is not valid UTF-8."])
        }
        try keyData.write(to: keyURL)

        if certContentBase64.isEmpty {
            
            
            throw NSError(domain: "AppleSignInManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "No signing certificate is associated with this account. Certificates are only available for accounts added with an App Store Connect API key whose role permits certificate access."])
        }

        guard let certData = Data(base64Encoded: certContentBase64) else {
            throw NSError(domain: "AppleSignInManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base64 certificate content"])
        }
        let derURL = tempDir.appendingPathComponent("cert.der")
        try certData.write(to: derURL)

        let opensslPath = URL(fileURLWithPath: "/usr/bin/openssl")
        let convResult = try await ProcessRunnerTool.shared.run(
            executableURL: opensslPath,
            arguments: [
                "x509", "-inform", "der",
                "-in", derURL.path,
                "-out", certURL.path
            ]
        )
        guard convResult.exitCode == 0 else {
            throw NSError(domain: "AppleSignInManager", code: Int(convResult.exitCode), userInfo: [NSLocalizedDescriptionKey: "OpenSSL certificate conversion failed: \(convResult.stderr)"])
        }

        let p12Result = try await ProcessRunnerTool.shared.run(
            executableURL: opensslPath,
            arguments: [
                "pkcs12", "-export",
                "-out", outputURL.path,
                "-inkey", keyURL.path,
                "-in", certURL.path,
                "-passout", "pass:\(passwordForP12)",
                "-name", certificateName
            ]
        )

        guard p12Result.exitCode == 0 else {
            throw NSError(domain: "AppleSignInManager", code: Int(p12Result.exitCode), userInfo: [NSLocalizedDescriptionKey: "OpenSSL P12 package generation failed: \(p12Result.stderr)"])
        }
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(developerAccounts) {
            UserDefaults.standard.set(data, forKey: "apple_developer_accounts")
        }
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "apple_developer_accounts"),
           let decoded = try? JSONDecoder().decode([AppleDeveloperAccount].self, from: data) {
            developerAccounts = decoded
            if !developerAccounts.isEmpty {
                sessionState = .signedIn
                selectedTeamID = developerAccounts.first?.teamID
            }
        }
    }
}
