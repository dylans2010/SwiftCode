import XCTest
@testable import SwiftCode

final class ConnectTests: XCTestCase {

    func testEnvelopeEncodingAndDecoding() throws {
        let payload = RemoteProjectStatePayload(
            projectName: "TestApp",
            projectPath: "/Users/dev/TestApp",
            activeScheme: "TestAppScheme",
            activeTarget: "TestAppTarget",
            activeBranch: "feature/connect",
            isGitDirty: true,
            aheadCount: 2,
            behindCount: 0,
            totalFileCount: 42
        )

        let envelope = try ConnectMessageEnvelope.makeEnvelope(
            type: .projectStateUpdate,
            payload: payload
        )

        XCTAssertEqual(envelope.type, .projectStateUpdate)
        XCTAssertEqual(envelope.protocolVersion, ConnectProtocolVersion.current)

        let decodedPayload = try envelope.decodePayload(RemoteProjectStatePayload.self)
        XCTAssertEqual(decodedPayload.projectName, "TestApp")
        XCTAssertEqual(decodedPayload.activeBranch, "feature/connect")
        XCTAssertTrue(decodedPayload.isGitDirty)
        XCTAssertEqual(decodedPayload.totalFileCount, 42)
    }

    func testProtocolErrorHandling() {
        let error = ConnectProtocolError.authenticationFailed
        XCTAssertEqual(error.rawValue, "authentication_failed")
        XCTAssertEqual(error.localizedDescription, "Authentication failed. Invalid auth token.")
    }

    func testTrustStorePairedMacLifecycle() {
        let trustStore = ConnectTrustStore.shared
        let testMacID = "mac_test_123"
        let testMac = PairedMacDevice(
            id: testMacID,
            name: "Dev MacBook Pro",
            hostName: "macbook-pro.local",
            port: 9480
        )
        let token = "token_secret_xyz"

        trustStore.savePairedMac(testMac, authToken: token)

        XCTAssertTrue(trustStore.isPaired(macID: testMacID))
        XCTAssertEqual(trustStore.getAuthToken(for: testMacID), token)

        trustStore.setAutoConnect(for: testMacID, enabled: false)
        if let stored = trustStore.pairedMacs.first(where: { $0.id == testMacID }) {
            XCTAssertFalse(stored.isAutoConnectEnabled)
        }

        trustStore.removePairedMac(macID: testMacID)
        XCTAssertFalse(trustStore.isPaired(macID: testMacID))
        XCTAssertNil(trustStore.getAuthToken(for: testMacID))
    }

    func testPermissionManagerGranularAuthorization() {
        let manager = ConnectPermissionManager.shared
        let macID = "mac_perm_test"

        manager.savePermissions([.projectInfo, .build, .logs], for: macID)

        XCTAssertTrue(manager.hasPermission(.projectInfo, for: macID))
        XCTAssertTrue(manager.hasPermission(.build, for: macID))
        XCTAssertTrue(manager.hasPermission(.logs, for: macID))
        XCTAssertFalse(manager.hasPermission(.terminal, for: macID))
        XCTAssertFalse(manager.hasPermission(.fileModification, for: macID))

        manager.setPermission(.terminal, isGranted: true, for: macID)
        XCTAssertTrue(manager.hasPermission(.terminal, for: macID))
    }

    func testLogFilteringAndLevelHierarchy() {
        let entry1 = RemoteLogEntryPayload(level: .debug, source: "App", category: "Core", message: "Debug line")
        let entry2 = RemoteLogEntryPayload(level: .info, source: "Network", category: "HTTP", message: "Request success")
        let entry3 = RemoteLogEntryPayload(level: .error, source: "Build", category: "Compiler", message: "Syntax error")

        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.error)

        let logs = [entry1, entry2, entry3]

        let filteredByMinLevel = logs.filter { $0.level >= LogLevel.info }
        XCTAssertEqual(filteredByMinLevel.count, 2)

        let filteredByQuery = logs.filter { $0.message.localizedCaseInsensitiveContains("Syntax") }
        XCTAssertEqual(filteredByQuery.count, 1)
        XCTAssertEqual(filteredByQuery.first?.source, "Build")
    }
}
