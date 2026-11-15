# Device Hub — Completion Report

Wave 2 (final integration) of the Device Hub expansion on SwiftCode `main`.
Base: remote main `bfd4b7e6` (local HEAD `40e214e`, tree-identical, tree clean
at start). No commit or push was made by this wave; the coordinator commits
and pushes.

## Per-subsystem status

Statuses are honest: a subsystem is COMPLETE only when the real behavior is
implemented end to end. PARTIAL means the behavior exists but has a known,
documented gap. BLOCKED means verification could not run in this environment.

| Subsystem | Status | Notes |
|---|---|---|
| Runtime browser (list / verify / remove / install / size) | COMPLETE | Real simctl list + disk-size measurement; `"unknown"` when not determinable; post-install verification against a fresh simctl list before success is reported. |
| Version-window compatibility in the create sheet | COMPLETE | `supportedDeviceTypes` + `minRuntimeVersion` / `maxRuntimeVersion` surfaced through fetch records; mismatch refused in UI naming both values; family check stays as fallback. |
| Duplicate creation path removal | COMPLETE | `DeviceHubLocalUI.presentNewSimulatorSheet` and the Window `SimulatorCreationView` removed; installer create sheet is the one path. The separate `ycode-ide` `SimulatorCreationView` (different target) was deliberately left alone. |
| Device groups + persistence | COMPLETE | Model + `DeviceGroupStore` under `SwiftCode.deviceHub.*` UserDefaults keys; sidebar group sections; group boot/shutdown via `SimulatorManager` with per-device errors named; preferred devices + simulator selection persisted. |
| Overview stats page | COMPLETE | Connected devices, available/booted simulators, installed/missing platforms, installed/available runtimes, Xcode version, developer directory, toolchain health — all from `PlatformManager` / `SimulatorManager` / `DevicesController`. |
| Navigation (Platforms / Runtimes / Groups / Diagnostics) | COMPLETE | `DeviceHubSection` (8 sections) + section popup + per-section SwiftUI pages hosted in the one hub window. |
| Orphaned `DeviceConnectSidebar.swift` | COMPLETE | Deleted; verified never referenced; pbxproj entries removed. |
| Unused `iPadPresets` | COMPLETE | Deleted (6 entries, never used). |
| Unified settings surface | COMPLETE | One surface; every setting preserved (Device Connect preferences + remote/camera/headset/local settings embedded, not reimplemented). |
| Watch / Vision menu routing | COMPLETE | Local creation routes to the installer create sheet when `canCreateWatches` / `canCreateVisionDevices`; pairing stays in the Pairing flows. |
| Utilities menu wiring | COMPLETE | "Device Utilities…" in the context menu; simulator-only actions disabled with reasons for physical devices. |
| Clone-sheet rewire | COMPLETE | Installer `cloneSimulator`, `CloneSimulatorSheet`, and the workspace path all call `SimulatorManager.cloneDevice`. |
| `DeviceHubSimctl.stopRecording` shim | COMPLETE | Deleted; `DevicesController.stopLocalDeviceRuntime` calls `SimulatorManager.stopScreenRecording` directly. |
| Swallowed errors in `DevicesController` | COMPLETE | Quick boot-all, shut-down-all, erase-all, appearance, increase-contrast, reduce-motion, battery/network, Stage Manager and pencil actions now succeed only after the real call succeeds and show the real error on failure. Contrast / reduce-motion / Stage Manager now read the current value and toggle it instead of always forcing `enabled: true`. Installer `setStageManager` / `simulateApplePencilAction` now throw on non-zero simctl status. |
| QuickView Run / Stop silent failures | COMPLETE | Errors surfaced in red; a launch that reports no pid is reported instead of silently monitoring; Stop only stops monitoring when the app really stopped. |
| Appearance popup / battery slider initial values | PARTIAL | Appearance reads the live value at open via `SimPrefs.styleDomain` / `styleKey` (`simctl spawn defaults read`). Battery has no simctl readback, so the slider opens at the last value SwiftCode applied — honestly the last-applied value, not a live reading. |
| Diagnostics readiness reporting | COMPLETE | Deploy failures attach a readiness-aware report (`DeviceReadinessCommand` + `PhysicalDeviceReadiness`) instead of the generic Developer Mode hint; the sync formatter now says readiness was not probed when it was not. |
| `deviceDisconnected` in Device Connect | COMPLETE | `DeviceConnectDeviceManager` observes the notification and marks the device unavailable (`markingDisconnected()`), matching the DevicesController side from Wave 1. |
| `DevicesList.devices` error surfacing | COMPLETE | Now `throws` and delegates to `parsePhysicalDevices` instead of silently returning `[]`; 4 test call sites updated. |
| Wave 0 leftovers | COMPLETE | `Destinations.simulators(fromSimctlJSON:)` uses the canonical `DevicePlatform(parsing:)` (handles `xrOS` → visionOS); `LayoutProbe` hardcoded `osVersion = "27.1"` removed; QuickView fallback architecture is now `"unknown"` instead of `"arm64"`. |
| `Process()` migration (stretch) | PARTIAL | 4 one-shot sites migrated to `DeviceConnectProcessRunner.runBlocking`: `Simctl.xcrun`, `newestProcess` (pgrep), `RemoteRun.runLocalData`, `SDKInfo.run`. 4 long-running / streaming sites remain — see Remaining work. |
| Tests (written) | COMPLETE | 33 new `@Test` functions; 159 total across Device Hub areas (recounted by grep, see below). |
| Build / test execution | BLOCKED | No Swift toolchain, Xcode, simctl or devices in this environment. Nothing was built or run here; nothing is claimed build-verified. |
| Live device / simulator verification | BLOCKED | Requires Dylan's Mac (see Mac-gate checklist). |

## Files changed in Wave 2

### Created (9)

- `swiftcode/Sources/YcodeDeviceModel/DeviceHubGroups.swift` — `DeviceGroup`, `DeviceGroupStore`, `DeviceGroupOperationResult`, `DeviceHubStoreKeys`.
- `swiftcode/Sources/YcodeDeviceModel/DeviceHubRuntimeBrowser.swift` — `DeviceHubRuntimeEntry`, `DeviceHubRuntimeBrowser` (list / verify / remove via simctl).
- `swiftcode/Sources/YcodeDeviceModel/DeviceHubOverview.swift` — `DeviceHubSection`, `DeviceHubOverviewSnapshot`.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DevicesController+HubSections.swift` — section navigation, overview snapshot, group boot/shutdown, utilities presentation, Watch/Vision creation routing.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubRuntimeBrowserView.swift` — runtime browser UI + view model.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubOverviewView.swift` — Overview, Platforms and Diagnostics pages.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubGroupsView.swift` — groups UI.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubSettingsView.swift` — unified settings surface.
- `swiftcode/Tests/YcodeDeviceModelTests/DeviceHubWave2Tests.swift` — 25 new `@Test` functions.

### Deleted (2)

- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceConnectSidebar.swift`
- `swiftcode/Sources/YcodeUI/Window/SimulatorCreationView.swift`

### Modified (28 tracked files)

- `project.yml`, `swiftcode/Package.swift` — YcodeBuild now depends on YcodeDeviceModel (canonical platform map use in `Destinations`).
- `SwiftCode.xcodeproj/project.pbxproj` — 8 new files registered (PBXBuildFile + PBXFileReference + group child + Sources entry each); deleted files' entries removed; YcodeBuild → YcodeDeviceModel target dependency added. Test files are not in the pbxproj, consistent with all existing test files (tests exist via SwiftPM only).
- `swiftcode/Sources/YcodeBuild/Models/Destinations.swift` — canonical `DevicePlatform` map replaces the hand map.
- `swiftcode/Sources/YcodeDeviceModel/DeviceConnectManagers.swift` — `deviceDisconnected` observer, deploy-failure readiness report.
- `swiftcode/Sources/YcodeDeviceModel/DeviceConnectModels.swift` — `ConnectedDevice.markingDisconnected()`, `SimulatorDefaultsValue.parseInt`.
- `swiftcode/Sources/YcodeDeviceModel/DeviceConnectParsers.swift` — readiness-aware `formatPipelineFailure` overloads.
- `swiftcode/Sources/YcodeDeviceModel/HubSidebarModel.swift` — group state + group sections.
- `swiftcode/Sources/YcodeIDECore/Session/DevicesList.swift` — `devices(devicectlJSON:)` now throws.
- `swiftcode/Sources/YcodeIDECore/Session/RemoteRun.swift` — `runLocalData` on the process runner.
- `swiftcode/Sources/YcodeIDECore/Session/SimulatorRun.swift` — `Simctl.xcrun` + `newestProcess` on the process runner.
- `swiftcode/Sources/YcodeIDECore/Session/WorkspaceSession+Product.swift` — `SDKInfo.run` on the process runner.
- `swiftcode/Sources/YcodeIDECore/Simctl/SimulatorManager.swift` — simulator-selection persistence.
- `swiftcode/Sources/YcodeUI/App/LayoutProbe.swift` — hardcoded `"27.1"` removed.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceConnectQuickView.swift` — Run/Stop errors surfaced, pid optionality handled, architecture fallback `"unknown"`.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceConnectSettingsView.swift` — body is the shared preferences section.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubLocalLive.swift` — `stopRecording` shim deleted.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubLocalUI.swift` — duplicate creation path removed; appearance/battery initial values; `readSimulatorAppearanceIsDark`.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubSimulatorInstaller.swift` — runtime records with supported device types + version window; post-install verification; clone delegates to `SimulatorManager`; installer throws on simctl failure.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubToolbar.swift` — Watch/Vision menu routing.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceHubUnifiedWorkspace.swift` — clone via `SimulatorManager`; unused `iPadPresets` / `TabletPreset` deleted.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DeviceManagementView.swift` — creation via the installer sheet.
- `swiftcode/Sources/YcodeUI/Window/DeviceConnect/DevicesController.swift` — section state, group store, settings hosting, swallowed-error fixes, section popup in the sidebar, utilities menu item, `workspaceContainer` made internal.
- `swiftcode/Sources/YcodeUI/Window/SimulatorSidebar.swift` — creation via the installer sheet.
- `swiftcode/Tests/YcodeIDECoreTests/DeviceDiscoveryServiceTests.swift` — updated for throwing `DevicesList.devices`.
- `swiftcode/Tests/YcodeUITests/DeviceHubCreateValidationTests.swift` — 8 new `@Test` functions (version window + `RuntimeRecord` compatibility).
- `swiftcode/Tests/YcodeUITests/OrganizerTests.swift` — updated for throwing `DevicesList.devices`.

## Files changed in Waves 0 and 1 (for context; per the Wave 0/1 reports)

- Wave 0: `DeviceDiscoveryService` + canonical `DevicePlatform` map,
  `DeviceConnectProcessRunner` (timeout/validation), async `xcode-select -p`,
  deploy-stage signing validation + syslog, session/history persistence in
  UserDefaults.
- Wave 1: `PlatformManager` (dynamic six-platform catalog over `SDKRegistry` +
  `SimulatorRuntimeManager` + simctl), `SimulatorManager` real listapps /
  screenshot / record / clone / rename, creation-sheet family validation +
  duplicate-name guard + Watch/visionOS local create, physical-device
  readiness detection + `deviceDisconnected` diff, unified console with
  pause/export + honest metrics, `DeviceUtilities` + `DeviceHubUtilitiesView`.

## Tests

Recounted by grep at the end of Wave 2 — do not copy an older number:

| File | @Test count |
|---|---|
| `swiftcode/Tests/YcodeUITests/DeviceHubCreateValidationTests.swift` | 41 |
| `swiftcode/Tests/YcodeUITests/DeviceHubR3Tests.swift` | 4 |
| `swiftcode/Tests/YcodeIDECoreTests/DeviceDiscoveryServiceTests.swift` | 6 |
| `swiftcode/Tests/YcodeIDECoreTests/DeviceUtilitiesTests.swift` | 22 |
| `swiftcode/Tests/YcodeDeviceModelTests/DeviceConnectTests.swift` | 17 |
| `swiftcode/Tests/YcodeDeviceModelTests/DeviceControlsLayoutTests.swift` | 5 |
| `swiftcode/Tests/YcodeDeviceModelTests/DeviceDiscoveryTests.swift` | 19 |
| `swiftcode/Tests/YcodeDeviceModelTests/DeviceHubWave2Tests.swift` | 25 |
| `swiftcode/Tests/YcodeDeviceModelTests/DeviceModelTests.swift` | 20 |
| **Total, Device Hub areas** | **159** |

Wave 2 added 33: 25 in `DeviceHubWave2Tests.swift` (groups persistence
round-trip, runtime-browser parsing/merging/sizing, navigation state,
overview toolchain summaries, readiness-aware pipeline failure,
disconnect marking, sidebar group sections) and 8 in
`DeviceHubCreateValidationTests.swift` (version-window refusal naming both
values, version comparison, `RuntimeRecord` compatibility).

`OrganizerTests.swift` has 5 `@Test` functions total (mixed file; only its
`DevicesList` call sites were touched for the throwing change).

**Zero tests were executed in this environment** — no Swift toolchain exists
here. The counts above are a static recount of `@Test` functions in source.

## What was verified statically

- Balanced delimiters in all 34 changed Swift files (scripted check, strings
  stripped).
- Zero comments in all newly written or modified Swift files (scripted check,
  string literals stripped). The single `//` hit is the pre-existing
  `// swift-tools-version: 6.0` manifest marker in `Package.swift`, which was
  already there and is required by SwiftPM.
- Every symbol referenced by the new/edited code was confirmed to exist by
  grep (models, views, managers, installer APIs, `SimPrefs`, readiness
  types, runner APIs).
- No leftover references to deleted symbols (`DeviceConnectSidebar`, Window
  `SimulatorCreationView`, `iPadPresets`, `TabletPreset`,
  `DeviceHubSimctl.stopRecording`, `DestinationCatalog.runtimePlatforms`).
  Remaining `"arm64"` hits are unrelated host-architecture defaults, not the
  removed QuickView fallback.
- pbxproj: all 8 new files have exactly one PBXBuildFile, one
  PBXFileReference, one group child and one Sources entry; deleted files have
  zero references; YcodeBuild now lists 5 target dependencies including the
  new YcodeDeviceModel one; the brace/paren delta matches the objects added
  and removed exactly.
- Two real defects were caught and fixed during this verification pass:
  `DeviceConnectQuickView` passed the optional pid from `launch` (returns
  `Int32?`) into `startMonitoring` (takes `Int32`), and
  `overviewSnapshot()` read `catalog.lastError`, which does not exist on
  `PlatformCatalogSnapshot` (it now reads
  `PlatformManager.shared.lastError`).

## Mac-gate checklist (Dylan's Mac)

1. Open `SwiftCode.xcodeproj` in Xcode — confirm the project opens and the 8
   new files are in their targets (YcodeDeviceModel × 3, YcodeUI × 5).
2. Build the app target; fix any member-level or conformance issues the
   static check cannot see.
3. `swift test` — run the Device Hub areas (159 `@Test` functions); expect
   all green.
4. Live simulator checks: create a simulator through the installer sheet
   (including a version-window refusal case), install and verify a runtime,
   create/rename/delete a group, boot and shut down a group, open the
   Overview / Platforms / Runtimes / Groups / Diagnostics pages.
5. Live physical-device checks (needs a trusted device with Developer Mode):
   deploy failure shows the detected readiness state; disconnect marks the
   device unavailable in both the Hub and the Device Connect window.
6. Battery slider: confirm it opens at the last-applied value (known partial
   — no simctl readback).

## Remaining work and limitations

- `Process()` migration (stretch), 4 sites left — all long-running or
  streaming, not one-shot, so they do not fit the run-and-wait runner:
  `RuntimeArchiveExpander.swift:74` (interactive decryptor with stdin key +
  piped stdout + cancellation), `RuntimeSetupSession.swift:486`
  (`SetupProcess`, long-running), `RemoteRun.swift:584` (long-running ssh
  forward held in state), `SimulatorRun.swift:76` (`StreamingProcess`,
  long-running stream). These need the runner's `start` API or a dedicated
  streaming path; they were deliberately left untouched.
- Battery slider initial value is the last-applied value, not a live read
  (simctl exposes no battery readback).
- The duplicate string platform maps in
  `YcodeIDEShell/Managers/InfrastructureAndVirtualizationManagers.swift:300`
  and `YcodeXcodebuild/Destinations.swift:233` were out of scope and remain.
- The separate `ycode-ide` `SimulatorCreationView.swift` (different target)
  was deliberately left alone; it is apparently also unreferenced, but it is
  outside the hub scope.
- The repo's `AGENTS.md` still contains the stale legacy-migration directive
  (SwiftCode-Legacy was deleted wholesale by Dylan in `3cdd82f4`). It was not
  followed; this wave touched only the Device Hub scope.
