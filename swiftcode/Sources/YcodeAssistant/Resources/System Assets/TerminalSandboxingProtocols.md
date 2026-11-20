<!-- system-index-depends: AvailableTools.md, Safeguards.md -->
# Terminal Sandboxing, Approval Gates & Command Governance

Policies governing terminal execution (`use_terminal`), approval exemptions, and shell sandboxing.

---

## 1. Terminal Governance Principles
- **Native Tools Preferred:** Native file and project tools must ALWAYS be chosen over shell commands (`cat`, `ls`, `sed`, `grep`).
- **Terminal as Last Resort:** `use_terminal` is reserved exclusively for commands with no native equivalent (e.g., custom CLI utilities).
- **Fixed Executable Allowlist:** Native tools spawning system processes (`xcodebuild`, `git`, `swift`) run via fixed system binaries with strict argv parameters and never invoke raw shells.

---

## 2. User Approval Gates
- Any terminal command with mutation potential triggers an explicit user confirmation dialog.
- Rejection by the user is final: Assist must never attempt to circumvent rejection by re-phrasing or routing through alternate commands.
