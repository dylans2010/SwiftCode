# Networking Architecture for macOS Apps

<!-- system-index-depends: SSLPinningAndNetworkSecurity.md -->

Networking in a Mac app is a small set of decisions made once and reused
everywhere: one session, one decoding strategy, one error model, one retry
policy. Scatter `URLSession.shared` data tasks across view code and every
screen invents its own failure behavior.

## One session, owned by the app

- Build a single `URLSession` with an explicit `URLSessionConfiguration`
  (`.default` for foreground work, `.background` for large downloads).
- Set sensible timeouts: a short `timeoutIntervalForRequest` so a hung
  server fails fast, and a longer `timeoutIntervalForResource` for big
  transfers.
- Keep the session in a service object owned by the app, not in a view
  model. Views ask the service; they never own sockets.
- Use `URLSession.shared` only for one-off fire-and-forget fetches. The
  moment you need headers, auth, or caching, move to the owned session.

## Requests as values

- Model each endpoint as a value: method, path, query, headers, body.
- Build the `URLRequest` from that value in one place so auth headers,
  user-agent, and content types are applied uniformly.
- Never string-concatenate URLs. Use `URLComponents` so query values are
  percent-encoded correctly.
- Keep secrets out of URLs. Tokens and keys belong in headers, never in a
  query string that lands in logs.

## Decoding and errors

- Decode with `Codable` and a single shared `JSONDecoder` configured once
  (key strategy, date strategy). Do not configure a decoder per call site.
- Model failure as one error enum: transport failure, HTTP status failure,
  decoding failure, cancelled. Map `URLError` codes into it at the boundary.
- Treat non-2xx as an error, not as empty data. Read the response body on
  failure; servers usually explain themselves there.
- Surface errors to the user in plain language with one recovery action
  (retry, check connection, sign in again). Never show a raw `URLError`
  description in the UI.

## Async and cancellation

- Prefer `async`/`await` (`data(for:delegate:)`) over completion handlers.
  Structured concurrency gives you cancellation for free.
- Cancel in-flight requests when the view that asked for them disappears.
  A stale response writing into a reused view is a classic bug.
- Debounce user-driven requests (search-as-you-type) so a keystroke storm
  does not become a request storm.

## Retries, caching, and offline

- Retry only idempotent requests, only on transient errors (timeout, 429,
  5xx), with exponential backoff and a cap. Never retry a POST blindly.
- Honor `Cache-Control` and ETags through `URLCache` instead of building a
  second cache by hand.
- Design for offline: show the last good data with a stale marker, queue
  mutations where safe, and say clearly when the app is offline.
- Background downloads use a background session with a delegate; the app
  must handle `application(_:handleEventsForBackgroundURLSession:)` and
  call the stored completion handler when done.

## Verification

- Test against a local server with latency and failure injection.
- Confirm cancellation actually stops work and never writes stale data.
- Confirm a 401 triggers re-authentication once, not a retry loop.
- Confirm airplane mode shows cached data plus an honest offline state.
