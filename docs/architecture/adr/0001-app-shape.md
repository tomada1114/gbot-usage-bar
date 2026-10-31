# ADR-0001: A menu-bar agent with a native menu

- **Status:** Proposed
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

ClaudeUsageBar exists to keep one number — the Claude Code weekly usage percentage — in
view at all times (`AGENTS.md` › Product). The template ships a windowed app: a
`WindowGroup` scene, a Dock tile, and a launch test that waits for a window. A window the
user must open to read one number defeats the point, so the shape is decided before any
feature is built on it.

The decision touches three places at once: `project.yml`'s `INFOPLIST_KEY_LSUIElement`,
the scene in `App/ClaudeUsageBarApp.swift`, and the assertion in
`LaunchUITests/LaunchTests.swift`. It also adds one Core port, `ApplicationTerminating`,
because an agent app has no app menu and therefore no built-in way to quit.

## Decision drivers

- The number is visible without any action, at the size of the menu bar's own text.
- The app stays out of the way: no Dock tile, no ⌘Tab entry, no window.
- The menu reads like the system's own status menus, with no custom chrome.
- The launch test can still prove the assembled app's wiring.

## Considered options

1. **A menu-bar agent with `MenuBarExtra` in the `.menu` style** — `LSUIElement` on, the
   label is the badge, and the content is a native pull-down menu of text lines, dividers,
   and Quit.
2. **A menu-bar agent with the `.window` style** — the same, with a SwiftUI panel instead
   of a menu.
3. **A menu-bar agent built on `NSStatusItem`** — an AppKit delegate in
   `ClaudeUsageBarPlatform` owning the status item.
4. **A windowed app** (the template's shape) — a small always-on-top window or a Dock
   badge.

## Decision

Option 1. `INFOPLIST_KEY_LSUIElement: YES` in `project.yml`; `App/` declares one
`MenuBarExtra` whose label is `UsageBadgeLabel` and whose content is `UsageMenu`, with
`.menuBarExtraStyle(.menu)`. The badge is the rounded weekly percentage — or the five-hour one, chosen
from the menu for the current run — inside a thin
outline of Clawd, Claude Code's pixel mascot, rendered into a template image so the menu
bar tints it for light, dark, and highlighted states. Quit goes through the
`ApplicationTerminating` port, answered by `NSApplicationTerminator` in
`ClaudeUsageBarPlatform`, so `ClaudeUsageBarUI` never calls AppKit to end the process.

- It beats option 2 because the menu holds only read-only lines and one command, which is
  what a native menu is for, and because XCUITest can see a `.menu` style's items (by
  title) but not a `.window` panel's contents — so the launch test can assert the Quit
  item and prove the content is wired.
- It beats option 3 because `MenuBarExtra` is a pure SwiftUI scene needing no delegate;
  nothing here needs a custom status-item view, a drop target, or a separate right-click
  menu, which are what would justify `NSStatusItem`.
- It beats option 4 because a window or a Dock badge competes for space the user does not
  want to give up for one number, and a Dock badge cannot show three digits legibly.

## Consequences

### Positive

- The number is always visible and costs one status item's width (1–3 digits).
- The launch test asserts both the status item and the Quit menu item.
- Everything the menu says is a `UsagePresentation` value in Core, under the coverage floor.

### Negative

- No Dock tile, app menu, or ⌘, — settings would need a `Settings` scene opened from the
  menu if the app ever grows one (none is planned).
- A `MenuBarExtra` label renders only `Text` or `Image`, so the outlined badge is drawn
  with `ImageRenderer`; its size is tuned by eye, not by a gate.
- On a crowded menu bar, macOS may hide the item behind the camera housing; the app
  cannot prevent that.

### Follow-ups

- None tracked yet: the repository has no remote or issue tracker.

## Open questions

- Unverified: whether VoiceOver reads the badge's `accessibilityDescription` (set on the
  template image) or the SwiftUI `accessibilityLabel` for the status item; checking needs a
  VoiceOver pass on the running app.

## Sources

- <https://developer.apple.com/documentation/swiftui/menubarextra> — "A scene that renders
  itself as a persistent control in the system menu bar", macOS 13.0+ — checked 2026-09-29
- <https://developer.apple.com/documentation/swiftui/menubarextrastyle/menu> — the style
  that renders the contents as a menu pulling down from the menu bar icon — checked
  2026-09-29
- <https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement>
  — an agent app that runs in the background and does not appear in the Dock — checked
  2026-09-29

## Related

- [ADR-0002](0002-sandbox-posture.md) — the sandbox posture this shape runs under.
- [ADR-0003](0003-usage-data-source.md) — where the number in the badge comes from.
