import Foundation
import Network

/// In-app executable test suite for verifying SwiftCode Connect networking, framing, port validation, and protocol models.
public struct ConnectNetworkingTestSuite {
    public struct TestResult: Identifiable {
        public let id = UUID()
        public let name: String
        public let passed: Bool
        public let details: String
    }

    public static func runAllTests() -> [TestResult] {
        var results: [TestResult] = []

        func assertTest(_ name: String, _ condition: Bool, details: String = "") {
            results.append(TestResult(name: name, passed: condition, details: details))
        }

        // 1. Port Configuration & Validation
        assertTest("Valid default port (8088)", SwiftCodeConnectConfiguration.isValidPort(8088))
        assertTest("Valid custom port (47123)", SwiftCodeConnectConfiguration.isValidPort(47123))
        assertTest("Reject reserved port 0", !SwiftCodeConnectConfiguration.isValidPort(0))
        assertTest("Reject reserved HTTP port 80", !SwiftCodeConnectConfiguration.isValidPort(80))
        assertTest("Parse port string '47123'", SwiftCodeConnectConfiguration.validatePortString("47123") == 47123)
        assertTest("Reject invalid port string", SwiftCodeConnectConfiguration.validatePortString("invalid") == nil)

        // 2. Framing & Envelope Encoding (4-byte length prefix)
        do {
            let pairingPayload = ConnectPairingRequestPayload(
                deviceID: "device-12345",
                deviceName: "Alice's iPhone",
                deviceModel: "iPhone 15 Pro",
                clientVersion: "1.0",
                publicKeyPem: "",
                verificationCode: "842193"
            )

            let envelope = try MessageEnvelope.encode(
                payload: pairingPayload,
                type: .pairingRequest,
                correlationID: "corr-5678"
            )

            assertTest("Envelope protocolVersion matches 1", envelope.protocolVersion == 1)
            assertTest("Envelope type is pairingRequest", envelope.type == .pairingRequest)
            assertTest("Envelope correlationID preserved", envelope.correlationID == "corr-5678")

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(envelope)

            var length = UInt32(payloadData.count).bigEndian
            var packetData = Data(bytes: &length, count: 4)
            packetData.append(payloadData)

            assertTest("4-byte length header framing", packetData.count == payloadData.count + 4)

            let headerData = packetData.prefix(4)
            let extractedLength = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            assertTest("Length prefix matches byte count", Int(extractedLength) == payloadData.count)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let unpackedEnv = try decoder.decode(MessageEnvelope.self, from: Data(packetData.dropFirst(4)))
            let decodedPayload = try unpackedEnv.decodePayload(ConnectPairingRequestPayload.self)
            assertTest("Decoded verificationCode matches", decodedPayload.verificationCode == "842193")
            assertTest("Decoded deviceName matches", decodedPayload.deviceName == "Alice's iPhone")

        } catch {
            assertTest("Framing and envelope serialization", false, details: error.localizedDescription)
        }

        // 3. Discovered Mac Model & Dynamic Port
        let dummyEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("192.168.1.45"),
            port: NWEndpoint.Port(rawValue: 47123)!
        )
        let discovered = DiscoveredMacDevice(
            name: "MacBook Pro",
            hostName: "192.168.1.45",
            port: 47123,
            protocolVersion: "1",
            capabilities: ["project", "build"],
            endpoint: dummyEndpoint
        )
        assertTest("Discovered Mac remote port preserved (47123)", discovered.port == 47123)
        assertTest("Discovered Mac formatted endpoint (192.168.1.45:47123)", discovered.formattedEndpoint == "192.168.1.45:47123")

        // 4. Actionable Error Mapping
        let refused = ConnectProtocolError.connectionRefused
        assertTest("Connection refused actionable error", refused.errorDescription?.contains("nothing is accepting connections") == true)

        let timeout = ConnectProtocolError.timeout
        assertTest("Timeout actionable error", timeout.errorDescription?.contains("timed out") == true)

        let portUnavail = ConnectProtocolError.portUnavailable
        assertTest("Port unavailable actionable error", portUnavail.errorDescription?.contains("another application is using it") == true)

        let protoMismatch = ConnectProtocolError.protocolMismatch
        assertTest("Protocol mismatch actionable error", protoMismatch.errorDescription?.contains("Incompatible") == true)

        return results
    }
}

#if canImport(XCTest) && false
import XCTest
@testable import SwiftCode

final class ConnectNetworkingTests: XCTestCase {
    func testAllConnectRequirements() {
        let results = ConnectNetworkingTestSuite.runAllTests()
        for result in results {
            XCTAssertTrue(result.passed, "Test failed: \(result.name) - \(result.details)")
        }
    }
}
#endif
