# SwiftCode Connect Protocol Contract Specification

This document defines the authoritative inter-application protocol contract between **SwiftCode iOS** (companion client) and **SwiftCode macOS** (host IDE server).

---

## 1. Overview & Architecture

SwiftCode Connect enables the SwiftCode iOS application to discover, pair with, and securely communicate with SwiftCode macOS over local networks.

```
┌─────────────────┐       Bonjour Discovery        ┌──────────────────┐
│  SwiftCode iOS  │ ----------------------------> │ SwiftCode macOS  │
│  (Companion)    │  ws://<mac-host>:9480/connect │    (Host IDE)    │
└─────────────────┘ <===========================> └──────────────────┘
                    Authenticated WebSocket (TLS)
```

---

## 2. Network Discovery (Bonjour)

The SwiftCode macOS application MUST advertise a Bonjour TCP service with the following configuration:

* **Service Type:** `_swiftcodeconnect._tcp`
* **Domain:** `local.`
* **Default Port:** `9480`
* **TXT Records (Optional):**
  * `version`: `"1.0.0"`
  * `deviceName`: `"User's Mac Studio"`

---

## 3. Protocol Envelope

All frame transmissions over the WebSocket connection MUST be formatted as JSON-encoded `ConnectMessageEnvelope` instances.

### Envelope Schema (`ConnectMessageEnvelope`)
```json
{
  "id": "UUID-STRING",
  "protocolVersion": "1.0.0",
  "type": "MESSAGE_TYPE_STRING",
  "correlationID": "OPTIONAL-UUID-STRING",
  "timestamp": "ISO8601-TIMESTAMP",
  "payloadData": "BASE64-OR-JSON-PAYLOAD-DATA"
}
```

---

## 4. Message Types (`ConnectMessageType`)

| Type String | Direction | Description |
|---|---|---|
| `pair_request` | iOS → Mac | Pairing request containing 6-digit verification code. |
| `pair_response` | Mac → iOS | Pairing outcome and generated bearer authentication token. |
| `auth_request` | iOS → Mac | Socket authentication request presenting stored auth token. |
| `auth_response` | Mac → iOS | Authentication confirmation. |
| `ping` / `pong` | Both | Socket heartbeat keeping connection alive. |
| `get_project_state` | iOS → Mac | Request active project, target, scheme, and Git state. |
| `project_state_update` | Mac → iOS | Authoritative active project state snapshot. |
| `build_start` | iOS → Mac | Trigger remote build execution for specified scheme. |
| `build_cancel` | iOS → Mac | Cancel running remote build. |
| `build_progress` | Mac → iOS | Real-time build progress event stream. |
| `build_completed` | Mac → iOS | Final build completion status event. |
| `build_diagnostic` | Mac → iOS | Compiler error/warning/note diagnostic item. |
| `log_stream_subscribe` | iOS → Mac | Subscribe to live system/console log stream. |
| `log_entry` | Mac → iOS | Live log line entry. |
| `assist_context_request` | iOS → Mac | Assist querying Mac for active project context. |
| `assist_context_response` | Mac → iOS | Mac returning project context snippet & errors. |
| `get_device_info` | iOS → Mac | Query Mac hardware performance metrics. |
| `device_info_response` | Mac → iOS | CPU, memory, OS, and disk status from Mac. |
| `permission_request` | Mac → iOS | Explicit permission request prompt. |

---

## 5. Pairing & Authentication Flow

1. **Discovery:** iOS discovers macOS via Bonjour `_swiftcodeconnect._tcp`.
2. **Pairing Handshake:**
   - iOS displays 6-digit code to user and sends `pair_request`:
     ```json
     {
       "deviceID": "IPHONE-UUID",
       "deviceName": "Alice's iPhone",
       "pairingCode": "849201"
     }
     ```
   - User approves prompt on macOS.
   - macOS responds with `pair_response`:
     ```json
     {
       "isSuccess": true,
       "macID": "MAC-UUID",
       "macName": "MacBook Pro",
       "authToken": "BEARER-SECRET-TOKEN-KEY"
     }
     ```
3. **Keychain Trust Store:** iOS securely persists `authToken` in Keychain under `com.swiftcode.connect.token.<macID>`.
4. **Connection Header:** WebSocket requests pass `Authorization: Bearer <authToken>`.

---

## 6. Remote Build Request & Event Model

### RemoteBuildRequestPayload
```json
{
  "projectPath": "/Users/dev/Projects/MyApp",
  "scheme": "MyAppScheme",
  "configuration": "Debug",
  "cleanBuild": false
}
```

### RemoteBuildProgressPayload
```json
{
  "buildID": "UUID-STRING",
  "state": "building", // preparing, building, succeeded, failed, cancelled
  "progressFraction": 0.45,
  "currentTaskName": "Compiling SwiftSources (14/32)...",
  "elapsedTimeSeconds": 4.2,
  "errorCount": 0,
  "warningCount": 1
}
```

### RemoteBuildDiagnosticPayload
```json
{
  "id": "UUID-STRING",
  "severity": "error", // error, warning, note
  "message": "Cannot find 'UserSessionManager' in scope",
  "filePath": "Sources/Views/ContentView.swift",
  "line": 42,
  "column": 12,
  "source": "swiftc",
  "code": "UserSessionManager.shared.reload()"
}
```

---

## 7. Permission Architecture

The protocol enforces granular capabilities. macOS must verify that requested capabilities are granted:

- `project_info`: View active workspace & Git branch
- `build`: Trigger and cancel builds
- `tests`: Execute test suites
- `logs`: Stream diagnostic & app logs
- `assist`: Access codebase context for AI Assist queries
- `device_info`: Read Mac hardware metrics
- `terminal`: Sensitive command execution
- `file_modification`: Sensitive source editing

---

## 8. Error Codes (`ConnectProtocolError`)

| Error Code | Meaning |
|---|---|
| `missing_payload` | Expected payload missing from envelope |
| `invalid_payload` | Payload JSON decoding failed |
| `authentication_failed` | Invalid bearer authentication token |
| `pairing_rejected` | User rejected pairing prompt on Mac |
| `protocol_mismatch` | Incompatible protocol version |
| `permission_denied` | Operation not granted by permission settings |
| `device_unavailable` | Mac host disconnected or unreachable |
| `build_failed` | Xcode build returned non-zero exit code |

---

*Specification Version: 1.0.0*
*SwiftCode Connect Subsystem — SwiftCode iOS*
