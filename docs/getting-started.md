# Getting Started

## Prerequisites

- [Xcode 26.5+](https://developer.apple.com/xcode/) (`xcode-select --install` alone is not enough — the app target needs the full IDE toolchain; CI pins the exact version in `.xcode-version`)
- [mise](https://mise.jdx.dev/) — installs the pinned CLI tools from `mise.toml`
- [Just](https://just.systems/man/en/installation.html) (optional — every recipe's underlying commands are plain shell; see CONTRIBUTING.md)

## Setup

```bash
mise trust     # approve this repo's mise.toml (asked once per clone)
just install
```

mise refuses to read config files it has not been told to trust, so a fresh
clone needs `mise trust` first (interactively it prompts; non-interactive
runs fail without it). `just install` then runs `mise install` (SwiftLint,
SwiftFormat, XcodeGen, xcbeautify, actionlint, ShellCheck, typos — all pinned), points
`core.hooksPath` at `.githooks/` for the fast pre-commit lint, and generates
`ClaudeUsageBar.xcodeproj`.

## Everyday Commands

```bash
just check     # the full local gate: verify-hooks → fmt → lint → test-scripts → check-harness → test → build
just test      # Swift Testing suite + 80% line / 75% function coverage floors on ClaudeUsageBarCore
just uitest    # XCUITest launch test (first local run may prompt for Accessibility)
just smoke     # Release build + "does it actually launch" assertion
```

## Keeping Permission Grants Across Rebuilds

Skip this unless your app asks for a permission macOS records — Accessibility,
Input Monitoring, Screen Recording, and the rest of TCC. Until then the template's
default ad-hoc signing is fine.

A Debug build is signed ad hoc (`CODE_SIGN_IDENTITY = -`), which gives it no stable
identity: macOS tells one such build from the next by its code hash, so **every
rebuild is a new app**. The grant you gave a minute ago no longer applies, the API
reports you are not trusted again, and System Settings shows a checked entry for the
old build that has to be removed and re-added — on every iteration.

Signing with a real certificate fixes it: the app then has a designated requirement
that a rebuild does not change, so the grant survives. The certificate is yours and
your machine's, so it is never committed — put it in `Config/Local.xcconfig`, which
is gitignored and which the pre-commit guard refuses even if you force it into the
index:

```bash
security find-identity -v -p codesigning   # confirm you have an Apple Development cert
cat > Config/Local.xcconfig <<'EOF'
DEVELOPMENT_TEAM = ABCDE12345
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = Apple Development
EOF
just build
codesign -d -r- build/dev-derived-data/Build/Products/Debug/ClaudeUsageBar.app
```

Two details cost time if you guess them:

- Keep `CODE_SIGN_IDENTITY` as the generic `Apple Development`, and let
  `DEVELOPMENT_TEAM` pick the certificate. A full common name
  (`Apple Development: You (XXXXXXXXXX)`) is rejected with *"No certificate for
  team … matching …"*, because the parenthesised id in that name is not your Team
  ID. Your Team ID is the certificate's `OU`:
  `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject`
- The first build that signs with a keychain identity opens a *"wants to sign using
  key … in your keychain"* dialog and waits for it. Click **Always Allow** once; an
  unattended build (an agent's, or a `just check` you walked away from) simply hangs
  until someone does.

`Config/Debug.xcconfig` ends with `#include? "Local.xcconfig"`, so the file is picked
up when it exists and silently skipped when it does not — a fresh clone and CI keep
signing ad hoc, and nothing about Release or the release workflow changes either way
(Release reads no xcconfig at all). Run `codesign -d -r-` after two consecutive
builds: the designated requirement printed should be identical, and that is what TCC
matches on.

Switching a build between ad-hoc and real signing leaves macOS holding decisions for
what it considers a different app. Clear them for this app — and only this app,
whose bundle identifier is read from `project.yml` — with:

```bash
just reset-permissions   # tccutil reset All <this app's bundle id>
```

That drops your own grants for it, so the next launch prompts from scratch.

## Removing the example code

The template's two examples — a counter screen and a ports-and-adapters example that
read the frontmost app — were removed when this app was started. What replaced them is
the pattern to copy now:

- the menu-bar agent in `App/ClaudeUsageBarApp.swift`, rendering `UsageMenu` and
  `UsageBadgeLabel` over Core's `UsageMenuViewModel`
  (`docs/architecture/adr/0001-app-shape.md`);
- the ports `OAuthTokenProviding` and `UsageFetching`, with their adapters
  `SecurityCLITokenProvider` and `URLSessionUsageFetcher`, their fakes and contract
  suites in `ClaudeUsageBarTestSupport`, and their local-machine tests
  (`docs/architecture.md` › Ports and adapters);
- `LaunchUITests/LaunchTests.swift`, which asserts the status item and its Quit menu
  item rather than a window.

Example code in a skill or a doc is a sketch of the pattern, never something the app
must keep.

## Open in Xcode

```bash
just generate
open ClaudeUsageBar.xcodeproj
```

Remember: `ClaudeUsageBar.xcodeproj` is generated from `project.yml` and gitignored.
Change targets/settings in `project.yml`, then `just generate`.

## App Icon

The template ships `App/Assets.xcassets/AppIcon.appiconset` with empty slots —
the app builds and runs without icon artwork. To add yours, open the project in
Xcode and drop PNG sizes onto the AppIcon set (App target → Assets), or edit
`AppIcon.appiconset/Contents.json` directly, then rebuild. `project.yml` already
wires the catalog via `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.
