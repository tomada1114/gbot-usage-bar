---
name: designing-errors
description: >
  Covers how errors are designed in this Swift 6 repository: error enums declared in
  ClaudeUsageBarCore, typed throws(SomeError) versus plain throws, what an error payload and an
  AppLog (os.Logger) message may carry, propagating CancellationError instead of
  swallowing it, and how a ClaudeUsageBarPlatform adapter maps OSStatus, NSError, or AXError into
  a Core error. Use when adding or changing an Error type, a throwing function or port,
  a do/catch, a Task that can be cancelled, or an adapter that calls a failing OS API.
---

# Designing Errors

**Owns:** the shape of an error type, the choice between typed and untyped `throws`,
what an error and its log line may contain, cancellation, and the OS-to-Core error
mapping at the adapter boundary. **Does not own:** writing the failing test first
(`tdd`); the C-callback, refcon, and TCC mechanics of calling a system API
(`integrating-system-apis`); the `os.Logger` basics (`.claude/rules/swift.md` ›
Logging); the error-path test rule (`.claude/rules/testing.md` › What to Test).

## Where an error type lives

- Declare every error a caller can observe in `ClaudeUsageBarCore`, next to the port or model
  that throws it — `UsageError.swift` holds the one error every usage port throws.
  `ClaudeUsageBarUI` and `App/` switch on it, and a Core test's fake throws it, so it cannot
  live in `ClaudeUsageBarPlatform` (Core never imports Platform).
- One `enum` per failure domain, `Error, Equatable, Sendable`. Cases name what went
  wrong for the caller (`.notSignedIn`, `.tokenExpired`), not which API failed.
- Payloads carry only what a caller needs to decide, and are `Sendable` values:
  `Int32` codes, small enums, durations. Never an `NSError`, a `CFTypeRef`, or an
  underlying `any Error` — those are not `Equatable`, often not `Sendable`, and leak
  the adapter's mechanism into Core.

`UsageError` (`Packages/ClaudeUsageBarKit/Sources/ClaudeUsageBarCore/UsageError.swift`) is the
worked example; abridged:

```swift
/// Why the usage numbers could not be refreshed — the menu shows a different line for
/// each case, which is why this is an enum and not a message string.
public enum UsageError: Error, Equatable, Sendable {
    case cancelled
    /// `status` is the `security` tool's exit status, or `nil` when it never started;
    /// it is for logs only.
    case credentialsUnreadable(status: Int32?)
    case notSignedIn
    case tokenExpired
    case unexpectedResponse(statusCode: Int?)
    case unreachable
}
```

## Typed throws or plain throws

Typed throws (`throws(UsageError)`, SE-0413) needs Swift 6; this package is
`swift-tools-version: 6.2` in Swift 6 language mode, so it is available everywhere.

- **Use `throws(E)`** when the caller switches over `E`'s cases: a port method, a
  view-model action whose UI shows per-case recovery. The `catch` then binds `error`
  as `E`, the `switch` is exhaustive, and adding a case breaks every caller that must
  handle it — which is the point.
- **Use plain `throws`** when the caller only propagates or reports failure, or when
  the body calls several throwing APIs of unrelated types. Forcing a typed throw there
  means wrapping every inner error for no decision anyone makes.
- Never `throws(any Error)` (it is plain `throws`) and never a catch-all case such as
  `.unknown(any Error)` to make a typed throw compile — map to a real case instead.

```swift
public protocol OAuthTokenProviding: Sendable {
    func accessToken() async throws(UsageError) -> OAuthAccessToken
}

// UsageMenuViewModel.refresh(): `do throws(UsageError)` keeps `error` typed.
do throws(UsageError) {
    let token = try await ports.tokenProvider.accessToken()
    let snapshot = try await ports.usageFetcher.fetchUsage(with: token).snapshot()
    state = UsageState(snapshot: snapshot, failure: nil, lastUpdated: now())
} catch .cancelled {
    return
} catch {
    state.failure = error
    AppLog.usage.error("refresh failed: \(String(describing: error), privacy: .public)")
}
```

The per-case decision — which menu line each case shows — is the exhaustive `switch` in
`UsagePresentation.line(for:)`, so a new case fails to compile until it has one.

`nil` stays the answer for "there is none" (a window the endpoint did not report is a
`nil` `UsageSnapshot.sevenDay`, not a throw); an error is for "could not find out". Do
not turn an expected absence into a throw.

## No user data in errors or logs

- An error payload never holds user content or a secret: no app names, window titles,
  file paths, typed text, URLs, tokens, response bodies, or identifiers of the user's
  documents. Errors travel — into logs, crash reports, test output, and
  `String(describing:)` in a view. `UsageError`'s payloads are at most a status code,
  which is why `refresh()` may log the whole error `.public`.
- Log lines follow `.claude/rules/swift.md` › Logging: `AppLog`'s `os.Logger` only.
  Interpolate an OS status code or an enum case with `privacy: .public`; anything that
  came from the user or another app with `privacy: .private` — or leave it out.
  `os.Logger` redacts dynamic strings by default; do not mark one `.public` to make a
  log easier to read.
- Log once, where the error is handled, not at every layer it passes through.

## Cancellation propagates

`CancellationError` means the caller no longer wants the result. It is not a failure
to report.

- Do not catch it into a Core error case, a log line, or an error state. A plain
  `catch` in an `async throws` function must rethrow it:

```swift
do {
    try await Task.sleep(for: .seconds(1))
    try await refresh()
} catch let error as CancellationError {
    throw error  // cancellation is not a failure: never log or map it
} catch {
    AppLog.usage.error("refresh failed")
}
```

- A long loop calls `try Task.checkCancellation()` rather than polling
  `Task.isCancelled` and returning a half result silently.
- Typed throws and cancellation: a function that awaits cancellable work and declares
  `throws(E)` cannot throw `CancellationError`. Keep such functions on plain `throws`,
  or give `E` an explicit `.cancelled` case the caller treats as a no-op — never drop
  the cancellation on the floor. `UsageError.cancelled` is this app's: the
  `URLSessionUsageFetcher` adapter maps `URLError.cancelled` and `CancellationError`
  into it, and `refresh()` returns on it without recording or logging a failure.
- A test asserts cancellation with `#expect(throws: CancellationError.self)`.

## Mapping OS errors in an adapter

The adapter translates, never decides (`AGENTS.md` › Architecture). Mapping an OS
error to a Core case is translation; choosing what the app does about it is Core's.

- Convert at the call site, inside `ClaudeUsageBarPlatform`, into the Core enum the port
  declares. Nothing OS-typed crosses the port.
- An exit status or `OSStatus` (an `Int32`): compare against the named constants you
  handle; pass any other status through in a code-carrying case — never success as an
  error. `SecurityCLITokenProvider` is the worked example (below).
- `AXError`: an adapter over the Accessibility API would switch the known cases
  (`.apiDisabled`, `.notImplemented`, …) into Core cases, and carry everything else's
  `result.rawValue` in a code-carrying case, the same way.
- `NSError` / a thrown Foundation error: match on `domain` and `code` (for example
  `NSCocoaErrorDomain` with `NSFileReadNoPermissionError`); carry only the `Int32`
  code, never `localizedDescription` or `userInfo`, which can hold paths and names.
- Log the raw code in the adapter only if Core cannot, and with `privacy: .public`.

`SecurityCLITokenProvider.accessToken()`
(`Packages/ClaudeUsageBarKit/Sources/ClaudeUsageBarPlatform/SecurityCLITokenProvider.swift`)
maps the `security` tool's exit status — `errSecItemNotFound` truncated to its low byte,
44 — and nothing else:

```swift
switch outcome {
case .launchFailed:
    throw .credentialsUnreadable(status: nil)
case let .exited(status, _) where status == Self.itemNotFoundStatus:
    throw .notSignedIn
case let .exited(status, _) where status != 0:
    throw .credentialsUnreadable(status: status)
case let .exited(_, output):
    return try ClaudeCodeCredentials.accessToken(from: output)
}
```

What an HTTP status means is not an OS error at all, so `URLSessionUsageFetcher` hands
any status back untouched and `UsageResponse.snapshot()` decides in Core that 401 and 403
are `.tokenExpired`.

A test in `Tests/ClaudeUsageBarPlatformTests` checks this mapping against the real OS under
`.requiresLocalMachine`; a Core test checks the decision with a fake that throws each
Core case.

## Checklist

- The error enum is in `ClaudeUsageBarCore`, `Error, Equatable, Sendable`, with value payloads.
- `throws(E)` only where a caller switches on `E`; plain `throws` otherwise.
- No user content in a payload; logs use `AppLog` with explicit privacy.
- `CancellationError` is rethrown, never logged or mapped to a failure.
- The adapter maps every OS error to a Core case; nothing OS-typed crosses the port.
- Each case has an error-path test asserting the case and payload.
