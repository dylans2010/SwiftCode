<!-- system-index-depends: XcodeBuildSettingsReference.md -->
# Binary Size Optimization & Dead Code Stripping

Techniques for analyzing binary footprint, stripping unused symbols, optimizing asset catalogs, and minimizing app distribution size.

---

## 1. Optimization Strategies
- **Link-Time Optimization (LTO):** Enable `LLVM_LTO = YES` to allow cross-module optimization and inlining.
- **Dead Code Stripping:** Ensure `DEAD_CODE_STRIPPING = YES` is enabled for all Release configurations.
- **Asset Thinning:** Use vector PDFs with "Preserve Vector Data" disabled unless dynamic runtime resizing is required.
- **Inspect Binary Bloat:** Analyze Mach-O section sizes using `size -m` or `bloaty`.
