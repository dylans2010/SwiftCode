# SwiftCode Connect Protocol Contract Specification

This document defines the authoritative inter-application protocol contract between **SwiftCode iOS** (companion client) and **SwiftCode macOS** (host IDE server).

---

## 1. Overview & Architecture

SwiftCode Connect enables the SwiftCode iOS application and SwiftCode macOS to discover each other bidirectionally, pair securely, and synchronize project/build/log/assist state over local networks.

```
┌──────────────────────────────────────────────────────────┐
│                   Bonjour Discovery                      │
│             _swiftcodeconnect._tcp (local.)              │
└──────────────────────────────────────────────────────────┘
             ▲                                ▲
             │ (Advertises & Browses)         │ (Advertises & Browses)
┌──────────────────────────┐     Framed TCP     ┌──────────────────────────┐
│      SwiftCode iOS       │ <================> │     SwiftCode macOS      │
│  • Configurable Port     │   4-Byte Length    │  • Configurable Port     │
│  • Local NWListener      │   Prefix Framing   │  • Primary NWListener    │
│  • Bidirectional Bonjour │                    │  • Bidirectional Bonjour │
└──────────────────────────┘                    └──────────────────────────┘
```

---

## 2. Network Discovery (Bonjour)

Both applications advertise and browse Bonjour TCP services:

* **Service Type:** `_swiftcodeconnect._tcp`
* **Domain:** `local.`
* **Default Port:** `8088` (User-configurable: `1024` – `65535`)
* **Authoritative TXT Records:**
  * `txtvers`: `"1"`
  * `proto`: `"1"`
  * `macName` (or `deviceName`): `"Dylan's MacBook Pro"` / `"Dylan's iPhone"`
  * `deviceType`: `"mac"` or `"ios"`
  * `appVers`: `"1.0"`
  * `caps`: `"project,build,logs,assist"`

---

## 3. Transport & Framing

Communication uses raw TCP managed via Apple's `Network.framework` (`NWConnection` and `NWListener`).

### Framing Model: 4-Byte Big-Endian Length Prefix
Every packet transmitted over the socket begins with a 4-byte `UInt32` big-endian integer indicating the byte length of the subsequent JSON-encoded `MessageEnvelope`.

```
┌───────────────────────────┬───────────────────────────────────────────┐
│ Length: UInt32 (4 bytes)  │ Payload: JSON MessageEnvelope (N bytes)   │
│ Big-Endian Byte Order     │ ISO-8601 Timestamps, UTF-8 Encoded        │
└───────────────────────────┴───────────────────────────────────────────┘
```

---

## 4. Message Envelope (`MessageEnvelope`)

```json
{
  "protocolVersion": 1,
  "messageID": "3FA85F64-5717-4562-B3FC-2C963F66AFA6",
  "correlationID": "OPTIONAL-UUID-STRING",
  "type": "pairing_request",
  "timestamp": "2026-08-26T22:00:00Z",
  "payload": { ... }
}
```

---

## 5. Message Types & Directionality

| Type String | Direction | Description |
|---|---|---|
| `pairing_request` | iOS → Mac | 6-digit verification code & device identity |
| `pairing_response` | Mac → iOS | Pairing approval & session bearer token |
| `auth_request` | iOS → Mac | Session authentication presenting bearer token |
| `auth_response` | Mac → iOS | Authentication confirmation & permissions |
| `ping` / `pong` | Both | Socket heartbeat keeping connection alive |
| `project_request` | iOS → Mac | Query active project details & schemes |
| `project_response` | Mac → iOS | Active project information & target snapshot |
| `git_status_request` | iOS → Mac | Request branch, clean status, ahead/behind |
| `git_status_response` | Mac → iOS | Authoritative Git repository status |
| `build_request` | iOS → Mac | Trigger remote build for scheme/config |
| `cancel_build_request` | iOS → Mac | Cancel running remote build |
| `build_started` | Mac → iOS | Notification that compiler process started |
| `build_progress` | Mac → iOS | Build task progression (steps, fraction, message) |
| `build_diagnostic` | Mac → iOS | Compiler errors, warnings, and notes |
| `build_completed` | Mac → iOS | Final build status (duration, exit outcome) |
| `logs_subscribe_request` | iOS → Mac | Subscribe to live system/console log stream |
| `logs_unsubscribe_request` | iOS → Mac | Stop live log stream |
| `log_event` | Mac → iOS | Live log line entry |
| `assist_query_request` | iOS → Mac | AI Assist query with project context |
| `assist_response` | Mac → iOS | AI Assist answer & suggested actions |
| `device_list_request` | iOS → Mac | Request Mac device metrics |
| `device_list_response` | Mac → iOS | Hardware CPU, memory, OS, and disk status |
| `error_response` | Both | Structured protocol error |

---

## 6. Pairing & Authentication Workflow

```
1. iOS & Mac Start Listeners & Advertise via Bonjour
2. iOS Resolves Mac's Real Advertised Port & IP
3. User Initiates Pairing in iOS UI
4. iOS Opens Framed TCP Connection to Mac Port
5. iOS Displays 6-digit Code & Sends `pairing_request`
6. Mac Displays Prompt & User Confirms
7. Mac Generates `sessionToken` & Sends `pairing_response`
8. iOS Stores `sessionToken` in Keychain
9. On Subsequent Connections, iOS Sends `auth_request`
10. Mac Verifies Token & Sends `auth_response`
11. iOS Performs Automatic Workspace Synchronization
```

---

## 7. Port Synchronization Architecture

- **Single Source of Truth**: Port configuration is stored in `SwiftCodeConnectConfiguration`.
- **Independent Local & Remote Ports**: Local listening port and remote target port are tracked separately.
- **Port Re-binding**: Changing the port rebinds the `NWListener`, updates Bonjour TXT records, and notifies active sessions.
- **Manual Endpoint Fallback**: When Bonjour discovery is filtered across subnets, users can manually configure the remote Mac's IP and port.

---

*Specification Version: 1.0.0 (Framed TCP Protocol)*
