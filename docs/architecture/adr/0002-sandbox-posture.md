# ADR-0002: Run without the App Sandbox

- **Status:** Accepted (by the owner, 2026-09-29)
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The template ships `App/ClaudeUsageBar.entitlements` with `com.apple.security.app-sandbox`
on and nothing else. [ADR-0003](0003-usage-data-source.md) makes the app do two things
that sandbox does not allow as shipped:

- **Read another application's keychain item.** The OAuth token lives in the
  `Claude Code-credentials` generic-password item, which Claude Code owns. The app reads
  it by running `/usr/bin/security find-generic-password` as a child process
  (`SecurityCLITokenProvider`).
- **Open an outgoing network connection** to `api.anthropic.com`
  (`URLSessionUsageFetcher`). A sandboxed app needs the
  `com.apple.security.network.client` entitlement for that, and the shipped file does not
  grant it.

The owner chose to turn the sandbox off, and signed off on the entitlements change
(`AGENTS.md` › Security and human approval).

## Decision drivers

- The app must be able to read Claude Code's token without a keychain prompt, and reach
  the usage endpoint.
- Rely on documented behavior where possible; the data source is already undocumented
  (ADR-0003), so the posture should not add a second undocumented dependency.
- Keep the attack surface small: the app runs one fixed command and sends one request.
- Distribution is to the owner's own Mac; the Mac App Store is a non-goal.

## Considered options

1. **Sandbox off** — remove `com.apple.security.app-sandbox`, leaving the entitlements
   dictionary empty. Hardened Runtime stays on (`ENABLE_HARDENED_RUNTIME` in
   `project.yml`).
2. **Sandbox on, plus `com.apple.security.network.client`** — keep the sandbox and grant
   outgoing connections only.
3. **Sandbox on, token via `SecItemCopyMatching`** — read the item through the Security
   framework instead of the `security` tool, with a keychain access prompt.
4. **Do nothing** — the app launches, reads the token, and fails every request as
   unreachable (observed; see below). The badge shows `--` forever.

## Decision

Option 1, as the owner chose: the App Sandbox off, so the process that spawns
`/usr/bin/security` and reads Claude Code's keychain item runs with the same keychain and
network access as the owner's own shell tools, which is the access this app is built on.
The change replaced the file's dictionary with an empty one:

```xml
<dict>
</dict>
```

**Option 2 was observed to work, and was still not chosen.** On 2026-09-29, a local Debug
build signed with option 2's entitlements (built with a `CODE_SIGN_ENTITLEMENTS` override
pointing at a scratch file; the repository's file was not touched) read the token through
`/usr/bin/security` and fetched the usage successfully, and the shipped entitlements
(sandbox on, no network entitlement) read the token and failed only at the network. So on
this Mac, the sandbox blocks the request, not the keychain read. The owner chose
option 1 with that result in hand, because the sandboxed keychain read is observed
behavior only: no Apple documentation found for this
ADR says a sandboxed app's child `security` process may read another application's
keychain item, so a macOS update could withdraw it.

Option 3 lost in either posture: the app is not on the item's access list, so the Security
framework would prompt, and with an ad-hoc-signed Debug build the grant does not survive a
rebuild. Option 4 is not a working app.

## Consequences

### Positive

- The token read and the request both rest on the same access the owner's existing
  status-line script already uses.
- No keychain prompt at launch or after a rebuild.

### Negative

- An unsandboxed app can never ship on the Mac App Store (App Review Guideline 2.4.5(i)),
  already a non-goal.
- The process runs with the user's full file and network access; a compromise of it is
  not contained by a sandbox. The app mitigates this only by doing little: one fixed
  command and one fixed request, and no file access of its own.
- Revisit if option 2 is confirmed reliable, or if the app is ever distributed beyond the
  owner's Mac.

## Open questions

- Unverified: whether a sandboxed app's child `/usr/bin/security` process reading another
  application's keychain item is supported behavior or an accident of the legacy login
  keychain's access-list model. It decides whether option 2 is safe to rely on.

## Sources

- <https://developer.apple.com/documentation/security/app-sandbox> — the App Sandbox
  restricts access to system resources and user data — checked 2026-09-29
- <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client>
  — whether an app may open outgoing network connections — checked 2026-09-29
- <https://developer.apple.com/app-store/review/guidelines/> — 2.4.5(i): Mac App Store
  apps "must be appropriately sandboxed" — checked 2026-09-29
- Observed 2026-09-29 on the owner's Mac (macOS 27, Debug builds, `/usr/bin/log` output of
  the `usage` category): sandbox on without a network entitlement → `refresh failed:
  unreachable`; sandbox on with `network.client` → `refresh succeeded`; sandbox off →
  `refresh succeeded`.

## Related

- [ADR-0003](0003-usage-data-source.md) — the data source whose access this posture
  grants.
- [ADR-0001](0001-app-shape.md) — the app shape; shape-independent, recorded together.
