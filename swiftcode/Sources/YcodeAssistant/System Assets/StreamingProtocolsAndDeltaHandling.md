<!-- system-index-depends: Streaming.md -->
# Streaming Protocols, SSE Parsing & Token Delta Buffering

Engineering specifications for Server-Sent Events (SSE), real-time token rendering, and backpressure management.

---

## 1. Stream Processing Architecture
- Parse SSE streams chunk-by-chunk using `AsyncThrowingStream`.
- Buffer partial UTF-8 bytes across chunk boundaries.
- Render markdown deltas smoothly to the UI while tracking request latency metrics.
