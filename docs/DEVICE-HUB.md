# Device Hub

The Device Hub is the one place in SwiftCode for working with Apple devices and
simulators: physical iPhones, iPads, Apple Watches and Apple Vision Pro headsets
connected over USB, plus local simulators for iOS, watchOS, tvOS and visionOS.

Open it from the Command Palette ("Device Hub"). It opens a single window
(`DevicesController`); Device Connect is a separate SwiftUI companion window and
is not part of the Hub.

## Requirements

- **Xcode** (reference target: Xcode 27.1) with its Command Line Tools. The Hub
  reads the selected developer directory (`xcode-select -p`) and shows the active
  Xcode version on the Overview page.
- **Command Line Tools only is not enough** for simulators: the Hub says so
  plainly on the Overview and Diagnostics pages instead of failing silently.
- A Mac for local simulators. Physical devices connect over USB and must be
  trusted and have Developer Mode enabled; the Hub reports the detected trust /
  Developer Mode state when a deploy fails instead of guessing.

## What it does

### Devices and simulators

- Lists connected physical devices (via `devicectl`) and local simulators
  (via `xcrun simctl list`), with state, OS version and availability.
- Boot, shut down, erase, rename, clone and screenshot simulators. Cloning goes
  through `SimulatorManager.cloneDevice`.
- Create simulators from the installer create sheet — the one creation path.
  The sheet validates the device type against the selected runtime *before*
  calling simctl: family compatibility, the runtime's supported device types,
  and the device type's minimum/maximum runtime version window. A version
  mismatch is refused in the UI and the error names both versions (for example,
  a device type requiring runtime 26.0 or later with 25.1 selected).
- Physical-device readiness is probed (`DeviceReadinessCommand`): trust,
  Developer Mode, connection state. A disconnected device is marked
  unavailable in both the Hub and the Device Connect window.

### Groups

Create named device groups, add devices to them, and boot or shut down a whole
group. Per-device failures are reported by name; a group action never claims
success for a device that did not change state. Groups, preferred devices and
the selected simulator are persisted in UserDefaults under
`SwiftCode.deviceHub.*` keys.

### Platforms and runtimes

- **Platforms** shows the six-platform catalog (iOS, macOS, watchOS, tvOS,
  visionOS, plus the driver platform set) built from the real SDK registry,
  simulator runtimes and simctl: SDKs, runtimes, install status, issues with
  remediation, and installation locations.
- **Runtimes** is a browser over `xcrun simctl list -j runtimes`: list, verify,
  remove and install simulator runtimes. Sizes are the real size measured from
  the runtime directory on disk, or `"unknown"` when the size cannot be
  determined — never fabricated. After any runtime install, the Hub verifies
  the runtime appears in a fresh simctl list before reporting success.

### Diagnostics

Environment summary (Xcode version, developer directory, toolchain health)
plus global and per-platform issues with the remediation for each. Deploy
failures attach a readiness-aware report to the log: the detected device state
and the action that follows from it.

### Device utilities

The context menu's "Device Utilities…" opens the utilities sheet for the
selected device: open a URL on the device, push a file, pull a file, and (for
simulators) set orientation, appearance, battery and related state. Actions
that only make sense for simulators are disabled with a reason for physical
devices.

### Settings

One settings surface: the Device Connect preferences (automation controls and
log/history retention) plus the device-type settings (remote device, camera,
headset, local simulator) that used to live on three separate surfaces. Every
setting from the old surfaces is preserved.

## How each capability maps to Apple tooling

| Capability | Apple tooling used |
|---|---|
| Simulator list, boot, shutdown, erase, clone, rename, screenshot, record | `xcrun simctl` |
| Runtime list, install, verify, remove | `xcrun simctl` (`list -j runtimes`, `runtime delete`) and the Xcode runtime installer |
| Physical device discovery, install, launch, logs | `devicectl` |
| Xcode version / developer directory | `xcode-select -p`, Xcode bundle metadata |
| SDK and platform catalog | Xcode SDK registry + `simctl` runtimes |
| Signing validation on deploy | codesigning identity lookup + `syslog` |
| Device trust / Developer Mode | `devicectl` device info + readiness probe |

No capability in the Hub talks to a mock, a simulated device, or a hardcoded
inventory. If Apple exposes no value, the Hub shows an honest unknown or an
error instead of inventing one.

## Honest limitations

- **Orientation** is simulator-only; there is no Apple CLI for rotating a
  physical device, so the action is disabled with a reason for physical
  devices.
- **Unpair** has no Apple command-line equivalent; a locally created Watch is
  unpaired, and pairing stays in the Pairing flows.
- **Battery level has no simctl readback.** The battery slider opens at the
  last value SwiftCode applied, not at a live reading from the simulator. The
  appearance popup, by contrast, reads the live value
  (`com.apple.uikitservices.userInterfaceStyleMode`).
- **Metrics** are shown only where Apple exposes them; where the platform
  exposes no metric, the Hub says the metric is unavailable rather than
  showing a plausible-looking number.
- **Version-window compatibility** is enforced from the data simctl reports
  (`supportedDeviceTypes`, `minRuntimeVersion`, `maxRuntimeVersion`). If a
  runtime does not report those fields, the Hub falls back to the family check.
- **Physical-device actions** need a trusted device with Developer Mode on.
  The Hub reports the detected state; it cannot fix trust or Developer Mode
  for you.
- **Live verification on a Mac is still pending.** The Hub was built and
  statically verified in an environment with no Swift toolchain, Xcode,
  simctl or devices. The Xcode build, `swift test`, and live device/simulator
  checks on a Mac remain the gate — see
  `docs/DEVICE-HUB-COMPLETION-REPORT.md`.
