# claude-usage-bar

[![CI](https://github.com/tomada1114/claude-usage-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/tomada1114/claude-usage-bar/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/tomada1114/claude-usage-bar/badge)](https://scorecard.dev/viewer/?uri=github.com/tomada1114/claude-usage-bar)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

ClaudeUsageBar is a macOS menu-bar app that shows your Claude Code **weekly usage
limit** as a number in the menu bar — `76` means 76% of this week's limit is used.
The menu can switch the number to the five-hour limit instead. Click it for the details:

```text
Weekly: 76%
Resets Wed 21:00
─────────────
5-hour: 19%
Resets 22:00
─────────────
Show in Menu Bar
  ✓ Weekly
    5-hour
─────────────
Updated 14:05
Quit ClaudeUsageBar   ⌘Q
```

The number sits inside the outline of Clawd, Claude Code's pixel mascot, which follows
the menu bar's light, dark, and tinted appearance; it reads `--` until the first refresh
succeeds. The weekly/five-hour choice lasts until the app quits; every launch starts on
the weekly limit. The app refreshes at launch and every minute. When a refresh fails, the
menu keeps the last good numbers and adds one line saying why: not signed in to Claude
Code, sign-in expired (open Claude Code to renew it), the server could not be reached,
or it answered with something unexpected.

## Requirements

- macOS 14 or later.
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) signed in on this Mac
  with a Claude subscription, so its `Claude Code-credentials` item is in your login
  keychain.
- To build: Xcode 26.5+, [mise](https://mise.jdx.dev/), and [Just](https://just.systems)
  (`brew install mise just`).

## Build and run

```bash
git clone https://github.com/tomada1114/claude-usage-bar.git
cd claude-usage-bar
mise trust     # approve mise.toml once — mise refuses untrusted configs
just install   # pinned tools via mise + git hooks + xcodegen generate
just run       # build (Debug) and launch; the badge appears in the menu bar
```

`just logs` streams the app's log (the `usage` category says whether each refresh
succeeded, and why not). Quit from the menu, or `pkill -x ClaudeUsageBar`.

The app runs without the App Sandbox, so it can run `/usr/bin/security` and reach
the usage endpoint; [ADR-0002](docs/architecture/adr/0002-sandbox-posture.md) records
why.

## How it gets the numbers — and the caveat

1. It runs `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`
   and reads `claudeAiOauth.accessToken` from the JSON Claude Code keeps there.
2. It sends `GET https://api.anthropic.com/api/oauth/usage` with that token and shows
   the `seven_day` and `five_hour` utilization and reset times.

**That endpoint is undocumented.** It is the one Claude Code itself uses; Anthropic does
not publish it, and it can change or disappear without notice — the app would then show
"Unexpected response from the usage server". The app never refreshes the token: when it
expires, running Claude Code renews it. Details and alternatives:
[ADR-0003](docs/architecture/adr/0003-usage-data-source.md).

## Privacy

- The token is read from your keychain on this Mac at each refresh and is sent only to
  `api.anthropic.com`, in that one request. It is never written to disk, cached, or
  logged; the type that carries it prints as `<redacted>`.
- The app reads nothing else from the keychain item (the refresh token included), sends
  no analytics, and keeps no state between launches.

## Non-goals

No colors or thresholds, notifications, other limits or model breakdowns, token refresh,
manual refresh item, Windows or Linux build, or Mac App Store release. The full list, and
where each decision is recorded, is `AGENTS.md` › Product.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and the pull request process, and
[AGENTS.md](AGENTS.md) for the architecture and the checks each change needs.

```bash
just check        # verify-hooks → fmt → lint → test-scripts → check-harness → test → build
just test-local   # the adapter tests against the real keychain and endpoint (needs Claude Code signed in)
just uitest       # the launch test: the status item and its Quit item
just smoke        # Release build launches and stays alive
```

The first local `just uitest` run may ask to enable UI automation (an administrator
authentication prompt) or for Accessibility permission; CI runners are pre-provisioned.

## Using This Template

This repository was created from
[macos-app-template](https://github.com/tomada1114/macos-app-template) with
`scripts/bootstrap.sh`; `.template-origin` records the template commit. The rename, the
`## Product` section, the roadmap, and removing the template's example code are done.
What remains belongs to the owner once the repository has a GitHub remote: create the
labels (`just labels`), apply the branch ruleset (`just ruleset`), prune the workflows a
private repository cannot run (`.agents/skills/starting-an-app/references/private-repository.md`),
and add signing secrets for releases (`docs/distribution.md`).

### Keeping up with template updates

A repository generated from a GitHub template has no upstream link — the files
are copied once. The bootstrap script therefore writes `.template-origin`: the
template commit your app was created from on line 1, the template repository on
line 2. To pull later template improvements (CI hardening, lint-rule bumps,
workflow fixes) into your app:

```bash
git remote add template https://github.com/tomada1114/macos-app-template.git
git fetch template
git log --oneline "$(sed -n 1p .template-origin)"..template/main   # what you don't have yet
git cherry-pick <sha>    # or: git merge template/main --allow-unrelated-histories
```

Both lines read `unknown` when the script could not know them honestly: it records
`HEAD` only when the history's root commit is the template's own first commit.
GitHub's "Use this template" gives the new repository a fresh root instead, so its
`HEAD` is not a template commit and its `origin` is your app rather than the template.
The file then names the file tree to look for, so one `git log --format='%H %T'`
over `template/main` finds the commit — fill the two lines in and the command
above works from then on. Update line 1 yourself whenever you adopt template
changes; the script never rewrites an existing file.

Cherry-picking narrowly scoped commits is usually cleaner than a full merge:
the bootstrap rename means most template commits touch files whose names and
contents differ in your repository. Treat the template as a starting point,
not a dependency — adopt the changes that earn their place.

## Design Philosophy

This app is built on [macos-app-template](https://github.com/tomada1114/macos-app-template),
and the repository keeps the template's reasoning here: every choice below has a
reason, so a disagreement names exactly what to change. The app's own decisions —
its shape, its sandbox posture, and its data source — are ADRs under
[`docs/architecture/`](docs/architecture/README.md).

### Why XcodeGen with a gitignored `.xcodeproj`?

`project.yml` is declarative, diffable, and safely editable by both humans and
AI agents; a raw `pbxproj` is a UUID graph that merge conflicts and agents can
silently corrupt. The generated project is treated like a lockfile-derived
artifact: regenerate, never hand-edit. Trade-off: XcodeGen is a third-party
tool with its own bus factor — but the manifest is simple enough to migrate
away from if that ever matters.

### Why a thin app shell + local Swift package?

`App/` contains only the `@main` entry point and resources. Everything real
lives in `Packages/ClaudeUsageBarKit`, so tests run with plain `swift test` — no
simulator, no signing, no Xcode project required. Precedent: pointfreeco's
isowords.

### Why the Core/UI/Platform split and a coverage floor on Core only?

`ClaudeUsageBarCore` holds all logic and never imports a UI or OS-integration framework
(SwiftUI, AppKit, UIKit, Cocoa, ApplicationServices, Carbon, ServiceManagement —
a lint rule and a test both enforce it); `ClaudeUsageBarUI` holds thin
views; `ClaudeUsageBarPlatform` holds the adapters that do talk to the OS, each behind a
protocol Core declares, so a test can substitute a fake and `App/` decides which
implementation the app gets (`docs/architecture.md`). The 80% line-coverage and 75%
function-coverage floors apply to Core only — that is what makes a
strict numeric gate *honest* for a GUI app instead of an invitation to write
meaningless view tests. Note: Swift's llvm-cov has no dependable branch
metric, so the gate uses line coverage, plus function coverage so a Core function
no test calls cannot hide under the line floor.

### Why one String Catalog in Core, and English only?

User-facing wording is a decision like any other, so it lives where the
coverage floor sees it: Core view models return `LocalizedStringResource`
(Foundation, not a UI framework), and the one `Localizable.xcstrings` sits in
`ClaudeUsageBarCore` beside them. Views render those resources and carry no literal of
their own, because a SwiftUI literal is looked up in the app's main bundle, not
the package's. The template ships English alone — `defaultLocalization: "en"`
and one catalog — since a second language makes every later string owe a
translation and a reviewer; an app that wants one records it as an ADR. The
`localizing-the-app` skill holds the rules, including one that shapes the
tests: `swift test` copies the catalog uncompiled (only `xcodebuild` compiles
it), so `LocalizationTests` scans Core's sources for `LocalizedStringResource`
calls and checks their keys and English against the catalog's source.

### Why Swift Testing?

`@Test`, `#expect`, and parameterized `@Test(arguments:)` are the modern
default shipped with the toolchain. XCTest appears exactly once — in the
XCUITest launch target, because Apple has not ported UI automation to Swift
Testing.

### Why zero dependencies?

An app template should not impose opinions about networking, persistence, or
update frameworks. This app still needs none: `URLSession`, `Process`, and
Foundation's formatters cover it. docs/architecture.md lists vetted suggestions
(ViewInspector, swift-snapshot-testing, Sparkle) and when they earn their place.

### Why Just?

One command — `just check` — runs the same gate locally that CI runs. Just has
cleaner syntax than Make and is a task runner, not a build system, which is
exactly what an Xcode project needs. Every recipe also works without Just (see
CONTRIBUTING.md).

### Why AGENTS.md and .claude/rules/?

AI-assisted development is the norm, not the exception. `AGENTS.md` and
path-scoped rules give LLMs the project's standards, architecture, and hard
prohibitions (never lower the coverage floor, never disable safety lint
rules) — reducing review cycles.

### Why an ADR tree that ships empty?

The template's own decisions are the ones above, and this section is where
they live. An app cut from the template makes decisions of a different kind —
its shape, its sandbox posture, where it keeps state, how it ships, which
permissions it asks for — and records each as an Architecture Decision Record
under `docs/architecture/`, whose index the template ships empty. `AGENTS.md`'s
"Before changing the architecture" names the changes that owe one. An accepted
ADR takes small corrections in place, dated; a replaced decision gets a new
ADR rather than a rewrite, so the reasoning that held at the time stays
readable.

### Why secret-gated notarization?

The release workflow always produces a DMG; when Developer ID secrets are
configured it signs, notarizes, and staples, otherwise it ad-hoc signs and
says so loudly. The template works on day one without an Apple Developer
Program membership, and upgrades to fully trusted distribution by adding
secrets — no workflow edits. See docs/distribution.md.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Architecture Decisions](docs/architecture/README.md)
- [Roadmap](docs/architecture/roadmap.md)
- [Distribution & Signing](docs/distribution.md)
- [Adding iOS Later](docs/adding-ios.md)

## License

[MIT](LICENSE)
