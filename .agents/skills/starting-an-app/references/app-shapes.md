# App shapes: windowed and menu-bar agent

Two shapes cover most macOS apps started from this template. Choose one before writing
features. The difference is only three files — `project.yml`, `App/ClaudeUsageBarApp.swift`, and
`LaunchUITests/LaunchTests.swift` — but it decides what the launch guarantee *is*, and
therefore what `just uitest` is able to assert at all.

| | Windowed (what the template ships) | Menu-bar agent (this app) |
|---|---|---|
| Dock tile, app switcher, ⌘Tab | yes | no |
| Main menu, ⌘Q, ⌘, | yes | no — the status item is the whole surface |
| `project.yml` key | none | `INFOPLIST_KEY_LSUIElement: YES` |
| Scene | `WindowGroup` | `MenuBarExtra` |
| Launch guarantee | a window appears | a status item appears |
| `XCUIApplication().state` after `launch()` | `.runningForeground` | `.runningBackground` |
| `just smoke` | unchanged | unchanged — it asserts the process stays alive, never a window |

Everything else is identical: the three targets and the one-way dependency direction,
ports and adapters, the coverage floor, signing, and every gate.

## Windowed: read the template's files, not a copy

The template this app was cut from (the repository `.template-origin` names) **is** the
windowed reference, so it is not duplicated here — a copy would be the first thing to go
stale. Its `App/` entry point is a `WindowGroup` holding its first screen, and its
`LaunchUITests/LaunchTests.swift` waits for `app.windows.firstMatch`. The app target
needs no shape-specific `project.yml` key: `GENERATE_INFOPLIST_FILE: YES` with no
`LSUIElement` entry *is* the regular shape.

## Menu-bar agent: read this app's files

This app is a menu-bar agent (`docs/architecture/adr/0001-app-shape.md`), so its shipped
files are the reference, for the same reason the windowed shape is not copied here. They
are held by every gate — CI's `app` job builds them, runs `just uitest`, and runs
`just smoke`. The `NSStatusItem` variant further down was proven on a clone of the
template by `just build` and `just lint` only.

### 1. `project.yml` — one key

One line in the `ClaudeUsageBar` target's `settings.base`, beside `GENERATE_INFOPLIST_FILE`
(leave the UI-test target's copy of that key alone):

```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.github.tomada1114.ClaudeUsageBar
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_LSUIElement: YES
```

`INFOPLIST_KEY_LSUIElement` is how a generated Info.plist gets `LSUIElement`; there is
no Info.plist file to edit, and adding one would fight `GENERATE_INFOPLIST_FILE`.
Regenerate with `just generate` — `ClaudeUsageBar.xcodeproj` is generated output, never edited.

### 2. `App/ClaudeUsageBarApp.swift` — the entry point

The scene is `MenuBarExtra { UsageMenu(model:) } label: { UsageBadgeLabel(model:) }`
with `.menuBarExtraStyle(.menu)`, and the initializer is the composition root: it builds
the `ClaudeUsageBarPlatform` adapters, hands them to `UsageMenuViewModel`, and calls
`startPolling()` so the badge fills in at launch rather than on the first click. The
shell still only wires; the menu's content is `ClaudeUsageBarUI` views, and every decision
they render stays in `ClaudeUsageBarCore`.

Choose the style deliberately. The `.menu` style renders the content as an `NSMenu` and
accepts only menu-shaped content (`Button`, `Divider`, `Text`); `.menuBarExtraStyle(.window)`
renders it as a panel that can hold any view, at the cost the XCUITest notes below
measure.

### 3. `LaunchUITests/LaunchTests.swift` — the replacement assertion

It waits for `app.menuBars.statusItems.firstMatch` instead of a window, clicks it, and
waits for `app.menuItems["Quit ClaudeUsageBar"]` — matched by title, because the `.menu`
style drops accessibility identifiers — then closes the menu. Quit is the one entry
present in every state, so it proves the scene's content is wired. With the `.window`
style the test would stop at the status item's existence.

## What XCUITest can and cannot see

Measured on the template, not recalled — re-measure before trusting any of it on a
newer SDK:

- **`app.launch()` works.** It does not hang or fail on an accessory app, even though
  the app never becomes frontmost. `app.state` is `.runningBackground` and
  `app.windows.count` is `0`; neither is worth asserting on.
- **The status item is in the app's own tree**, as
  `app.menuBars.statusItems.firstMatch` — `menuBars` holds two elements, the main menu
  the agent never shows and a second one holding the status item. Its `title` is not
  the `MenuBarExtra` label: with `MenuBarExtra(_:systemImage:)` it read as the symbol's
  name (`number.circle`).
- **`isHittable` is `false`** until something activates the app, so an `isHittable`
  assertion fails right after launch. `click()` activates the app itself and works.
- **`.menuBarExtraStyle(.window)` content is invisible to XCUITest.** After clicking
  the status item, `windows`, `popovers`, `sheets`, `groups`, `otherElements`, and
  `staticTexts` are all empty — the panel is not exposed through the app's accessibility
  tree. The launch test therefore stops at "the item exists"; the behavior inside the
  panel is covered by `ClaudeUsageBarCore` view-model tests, which is where it belongs anyway.
- **The default `.menu` style *is* reachable**: after `click()`, its entries appear as
  `app.menuItems[…]`. They are matched **by title**
  (`app.menuItems["Quit ClaudeUsageBar"]`, as this app's launch test does) — a SwiftUI
  `.accessibilityIdentifier` on a menu `Button` is dropped, and the element's identifier
  reads `menuAction:`. A launch test that asserts more than the item's existence
  therefore depends on the English titles.

## When `MenuBarExtra` is not enough: `NSStatusItem`

Reach for `MenuBarExtra` first — it is a pure SwiftUI scene and needs no delegate. An
`NSStatusItem` only earns its place when the scene cannot express the requirement: a
custom status-item view, a drag destination, or a right-click menu distinct from the
left-click behavior.

**Where the delegate lives: `ClaudeUsageBarPlatform`, not `App/`.** It imports AppKit, owns
state, and runs at a lifecycle moment — all three make it OS-integration code, which
`docs/architecture.md` ("Ports and adapters") puts in `ClaudeUsageBarPlatform`. `App/` keeps the
one wiring line that names it, and nothing more; anything the delegate has to *decide*
moves into `ClaudeUsageBarCore` behind a port, like every other adapter. (`ClaudeUsageBarUI` is the wrong
home for the same reason it cannot see `ClaudeUsageBarPlatform`: it is the view layer, not the
OS layer.)

`Packages/ClaudeUsageBarKit/Sources/ClaudeUsageBarPlatform/StatusItemAppDelegate.swift`:

```swift
import AppKit

/// Owns an `NSStatusItem` for the cases `MenuBarExtra` cannot express: a custom button
/// view, a drag destination, or a right-click menu distinct from the left-click one.
///
/// It lives in `ClaudeUsageBarPlatform` because it imports AppKit and holds state — the app
/// shell stays wiring only (`docs/architecture.md` › Layers) and declares it with a
/// single `@NSApplicationDelegateAdaptor` line. Anything it has to decide belongs in
/// `ClaudeUsageBarCore` behind a port, the same as any other adapter.
@MainActor
public final class StatusItemAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    /// Required: `NSApplicationDelegateAdaptor` instantiates the type itself.
    override public init() {
        super.init()
    }

    /// Creates the status item once AppKit is running — `NSStatusBar` has no menu bar
    /// to add to before this. The item is retained here; releasing it removes it.
    public func applicationDidFinishLaunching(_: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "number.circle",
            accessibilityDescription: "ClaudeUsageBar",
        )
        statusItem = item
    }
}
```

`applicationDidFinishLaunching(_:)` takes an unnamed parameter on purpose: SwiftLint's
`unused_parameter` rejects a named one it never reads, and the protocol conformance does
not care about the name. In `ClaudeUsageBarApp`, the whole wiring is:

```swift
    @NSApplicationDelegateAdaptor(StatusItemAppDelegate.self)
    private var appDelegate
```

## What an agent app loses, and what to do about it

- **Quitting.** There is no ⌘Q and no app menu, so a locally run agent app has no way
  out until you give it one: `pkill -x ClaudeUsageBar` is the stopgap (verified), a Quit control
  in the menu content is the fix. `NSApplication.shared.terminate(nil)` is AppKit, so it
  goes behind a Core port with a `ClaudeUsageBarPlatform` adapter like any other OS call — do not
  import AppKit into `ClaudeUsageBarUI` for it. This app's is `ApplicationTerminating` /
  `NSApplicationTerminator`, reached through `UsageMenuViewModel.quit()`.
- **Settings.** ⌘, is gone with the app menu. Add a `Settings { SettingsView() }` scene
  beside the `MenuBarExtra` in the same `body` (a `Scene` builder takes both), put
  `SettingsView` in `ClaudeUsageBarUI`, and open it from the menu content with
  `SettingsLink { … }` (macOS 14+, which this template already targets). This app has
  neither — add them when it has something to configure.
- **Being noticed at all.** An agent app that launches and shows nothing is
  indistinguishable from one that crashed. Keep `just smoke` in the loop: it is the only
  gate that says the Release build stays alive, and it needs no change for this shape.

## What does not change

`scripts/smoke_launch.sh`, `App/ClaudeUsageBar.entitlements`, signing and notarization, the
coverage floor, and the layer rules are all shape-independent. An agent app is still an
ordinary signed app bundle — `LSUIElement` only tells the Dock and the app switcher to
ignore it.
