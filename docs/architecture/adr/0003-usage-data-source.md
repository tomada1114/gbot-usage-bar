# ADR-0003: Usage from Claude Code's keychain token and the OAuth usage endpoint

- **Status:** Proposed
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The app shows the Claude Code weekly and five-hour usage limits. Anthropic publishes no
API for a subscriber's own usage limits. Claude Code itself reads them from
`GET https://api.anthropic.com/api/oauth/usage`, authenticated with the OAuth access token
it keeps in the login keychain, and the owner's existing status-line script does the same.
This ADR records that choice, the two Core ports it adds (`OAuthTokenProviding`,
`UsageFetching`), and the polling interval.

## Decision drivers

- Show the same numbers Claude Code shows, for the account Claude Code is signed in to,
  with no extra sign-in.
- Never store, log, or send the token anywhere but `api.anthropic.com`.
- Keep every decision (what a status or a body means, what the menu says) in
  `ClaudeUsageBarCore`, where a test with a fake reaches it.
- Put light, predictable load on an endpoint the app does not own.

## Considered options

1. **Keychain token via `/usr/bin/security`, plus the OAuth usage endpoint** — mirror the
   owner's status-line script.
2. **Keychain token via `SecItemCopyMatching`** — the same endpoint, with the Security
   framework reading the item.
3. **Parse Claude Code's local session logs** — estimate usage from token counts in
   `~/.claude`.
4. **A separate sign-in** — have the app run its own OAuth flow and keep its own token.

## Decision

Option 1.

- **Token.** `SecurityCLITokenProvider` runs
  `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w` and Core's
  `ClaudeCodeCredentials.accessToken(from:)` reads `claudeAiOauth.accessToken` from the
  JSON. Exit status 44 (item not found) means not signed in; any other failure means the
  item could not be read. The token is read afresh on every refresh and never cached,
  because Claude Code replaces it when it renews its sign-in. It travels as
  `OAuthAccessToken`, whose description and mirror are redacted.
- **Request.** `URLSessionUsageFetcher` sends `GET /api/oauth/usage` with
  `Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`
  (`UsageEndpoint`), and hands the status and body to Core. `UsageResponse.snapshot()`
  decides: 2xx decodes, 401 and 403 mean the token expired, anything else is an
  unexpected response. Decoding reads only `five_hour` and `seven_day`
  (`utilization`, `resets_at`) and is lenient: a missing, `null`, or wrongly typed field
  empties only itself. `resets_at` is parsed by Core's own `UsageTimestamp`, because it
  arrives with six fractional digits or none.
- **No token refresh.** The app never uses the refresh token. A 401 or 403 shows
  "Sign-in expired — open Claude Code to refresh it"; running Claude Code renews the
  token, and the next poll succeeds.
- **Polling.** At launch and then every `Tuning.refreshInterval` (one minute), with a
  30-second `Tuning.requestTimeout`. A failure keeps the last good numbers on screen beside
  one line naming the failure.
- **Ports.** `OAuthTokenProviding` and `UsageFetching` in Core, each with a fake and a
  contract in `ClaudeUsageBarTestSupport`, checked against the real adapters by
  `just test-local`.

Option 2 lost because the app is not on the keychain item's access list, so the Security
framework prompts, and an ad-hoc-signed build loses the grant on every rebuild;
`/usr/bin/security` was observed to read the item without a prompt on the owner's Mac.
Option 3 lost because local logs cover only this Mac's sessions and cannot see the
account-wide limit or its reset time. Option 4 lost because it adds a sign-in flow and a
stored credential for numbers Claude Code already has.

## Consequences

### Positive

- The numbers match Claude Code's for the signed-in account, with no setup beyond
  signing in to Claude Code.
- The token stays on the Mac except for the one request to `api.anthropic.com`.

### Negative

- **The endpoint is undocumented.** Its path, its beta header, and its JSON shape can
  change or disappear without notice; the app would then show "Unexpected response from
  the usage server" until it is updated. This is the largest risk the app carries.
- Running a subprocess requires the sandbox posture in [ADR-0002](0002-sandbox-posture.md).
- The app depends on the keychain item's name and JSON layout, which belong to Claude
  Code and can also change.
- About 1,440 requests a day while the app runs.

### Follow-ups

- None tracked yet: the repository has no remote or issue tracker.

## Open questions

- Unverified: whether Anthropic rate-limits this endpoint per token in a way one-minute
  polling alongside Claude Code's own calls could hit.
- Unverified: why `/usr/bin/security` reads the item without a prompt — the item's access
  list was not inspected, only the behavior observed.

## Sources

- Observed 2026-09-29 on the owner's Mac: `security find-generic-password -s
  "Claude Code-credentials" -w` exits 0 and prints JSON with a `claudeAiOauth` object
  holding `accessToken` (among other keys); a missing service exits 44.
- Observed 2026-09-29: `GET https://api.anthropic.com/api/oauth/usage` with that token
  and `anthropic-beta: oauth-2025-04-20` answers 200 with `five_hour` and `seven_day`
  objects (`utilization` 0–100, `resets_at` such as `2026-09-30T12:00:00.264575+00:00`)
  among many other keys; an invalid bearer token answers 401. No public Anthropic
  documentation for this endpoint was found.

## Related

- [ADR-0002](0002-sandbox-posture.md) — the posture that lets this data source work.
- [ADR-0001](0001-app-shape.md) — the badge and menu this data fills.
