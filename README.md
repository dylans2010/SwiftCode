<h1 align="center">SwiftCode</h1>

<p align="center">
  <strong>An independent IDE for Apple-platform projects, on macOS and Linux.</strong><br>
  It opens real projects, builds them, and writes files that stay compatible.
</p>

<p align="center">
  <a href="https://github.com/dylans2010/SwiftCode/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/dylans2010/SwiftCode?include_prereleases&label=release"></a>
  <img alt="Platforms: macOS, Linux x86-64 and arm64" src="https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20x86--64%20%7C%20Linux%20arm64-lightgrey">
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#update-channels">Update Channels</a> ·
  <a href="#what-is-swiftcode">What is SwiftCode</a> ·
  <a href="Release-Notes.md">Release Notes</a> ·
  <a href="https://github.com/dylans2010/SwiftCode/issues/new/choose">Report an Issue</a>
</p>

---

## Repositories

- **Public Releases & Issues (this repository):** [`https://github.com/dylans2010/SwiftCode`](https://github.com/dylans2010/SwiftCode) — hosts `.dmg` builds, [Release Notes](Release-Notes.md), and community bug reports / feature requests.
- **Internal Codebase:** [`https://github.com/dylans2010/SwiftCode-Internal`](https://github.com/dylans2010/SwiftCode-Internal) — active development and internal source repository.

---

## What is SwiftCode?

SwiftCode is a desktop IDE for projects that target Apple platforms. It reads and writes the same files as Apple's Xcode (`.xcodeproj`, `.xcworkspace`, `.xcscheme`, `.xcconfig`, Swift packages), so you can move a project between tools and keep your diffs clean.

It is written from scratch in Swift under a clean-room protocol — **it contains no Apple code.** It builds with the compilers and SDKs you have installed on your system.

---

## Install

Download the latest `.dmg` from the [Releases page](https://github.com/dylans2010/SwiftCode/releases), open it, and drag **SwiftCode.app** into `/Applications`.

### macOS Requirements
- macOS 15 or later on Apple Silicon (Liquid Glass UI effects require macOS 26 or later).
- Xcode installed on your Mac to provide the Apple compilers and SDKs.

---

## Update Channels

SwiftCode includes a built-in **Updates** pane in **Settings** that pulls `.dmg` builds directly from [Releases](https://github.com/dylans2010/SwiftCode/releases) using tag-based channel filtering:

| Channel | Tag Format | Intended Audience |
|---|---|---|
| **Production** | `3.3.1` | Stable releases for everyone. |
| **Beta** | `3.3.1-beta-4` | Users who want to test upcoming features and help find bugs. |
| **Nightly** | `3.3.1-nightly-4` | Developers and advanced users who want bleeding-edge, potentially unstable builds. |
| **Developer** | `3.3.1-dev-4` | Internal SwiftCode developers only (requires internal hash verification). |

---

## Feedback & Bug Reports

You can submit bug reports, improvement suggestions, or feature requests directly from **Help → Send Feedback…** inside SwiftCode, or open an issue on [GitHub Issues](https://github.com/dylans2010/SwiftCode/issues/new/choose).
