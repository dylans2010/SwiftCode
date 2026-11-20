<!-- system-index-depends: SwiftUIArchitecture.md -->
# Accessibility (A11y) Auditing & WCAG Remediation

Guidelines for ensuring Apple platform applications adhere to WCAG accessibility guidelines, VoiceOver navigation, and Dynamic Type scaling.

---

## 1. Core Principles of Apple Accessibility
- **Semantic Labels:** Provide concise, informative labels using `.accessibilityLabel("...")`.
- **Dynamic Type Scaling:** Support text resizing via `@ScaledMetric` or relative typography styles (`.font(.body)`).
- **Accessible Touch & Click Targets:** Interactive elements must have a minimum clickable area of 44x44 pt.
- **Color Contrast:** Maintain a minimum contrast ratio of 4.5:1 for standard text and 3:1 for large text.
