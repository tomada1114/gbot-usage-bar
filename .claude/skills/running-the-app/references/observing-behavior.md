# Observing behavior with no human at the keyboard

Three ways to watch a running build: a screenshot, a throwaway UI test that drives a
flow, and a launch that starts the app in a known state. The commands were verified on a
windowed build; this app is a menu-bar agent (`LSUIElement`,
`docs/architecture/adr/0001-app-shape.md`), and each section says where that changes
things. Write every artifact to a scratch directory outside the checkout — nothing below
belongs in a commit.

## Screenshot

The whole screen, silently:

```bash
screencapture -x /tmp/shot.png
```

One window, without the drop shadow, which needs the window's CGWindowID:

```bash
screencapture -x -o -l "$window_id" /tmp/window.png
```

macOS ships no command that prints that id, so ask CoreGraphics for it. This snippet
prints the id of every on-screen, layer-0 (ordinary, non-panel) window owned by a
process name — save it to your scratch directory, not into the repository:

```swift
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.dropFirst().first ?? ""
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
for window in list {
    guard window[kCGWindowOwnerName as String] as? String == owner,
          let number = window[kCGWindowNumber as String] as? Int,
          let layer = window[kCGWindowLayer as String] as? Int, layer == 0
    else { continue }
    print(number)
}
```

```bash
swift /tmp/windowid.swift ClaudeUsageBar     # prints one id per window
```

Reading the window list needs no permission; **capturing pixels does**. Screen Recording
is granted to the application that runs `screencapture` — your terminal, or whatever
launched the agent — not to this app, and it is a first-run TCC prompt like any other,
so it belongs in the single up-front ask. A denied grant is worse than an error: the
capture still succeeds and still writes a PNG, showing the desktop where the windows
should be. Look at the file you wrote before believing it.

This app is menu-bar-only (`LSUIElement`, `MenuBarExtra` — **BACKGROUND:**
`starting-an-app`), so the snippet above prints nothing for it: it has no ordinary window
to capture until its menu is open, and opening that menu is a click only a human or an
accessibility grant can make. Prefer a log line, a `#Preview`, or a Core test, and fall
back to a full-screen capture with the menu already open.

## Drive a flow with a throwaway XCUITest

`LaunchUITests/` is the only XCTest target (`project.yml`'s `ClaudeUsageBarLaunchUITests`, whose
`sources: [LaunchUITests]` takes the whole directory), so a probe is one file plus
`just generate`. This app's menu is `.menuBarExtraStyle(.menu)`, which drops a SwiftUI
accessibility identifier on its entries: a probe finds the status item as
`app.menuBars.statusItems.firstMatch` and each menu entry by its title, exactly as
`LaunchUITests/LaunchTests.swift` does. A windowed screen would instead give each control
an accessibility identifier before it can be driven at all.

```swift
// LaunchUITests/ScratchProbeTests.swift — throwaway, never committed
import XCTest

final class ScratchProbeTests: XCTestCase {
    @MainActor
    func testProbe() {
        let app = XCUIApplication()
        app.launch()
        let statusItem = app.menuBars.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))
        statusItem.click()
        XCTAssertTrue(app.menuItems["Quit ClaudeUsageBar"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "menu-open"
        shot.lifetime = .keepAlways
        add(shot)
        app.typeKey(.escape, modifierFlags: [])
    }
}
```

The probe captures the whole screen (`XCUIScreen.main.screenshot()`), because what there
is to see is the open menu, not a window. Its queries are the ones `LaunchTests.swift`
runs; the screenshot step has not been run against this app, so look at the attachment
before believing it, as with `screencapture`.

Run that one test, keeping the result bundle out of the way of `just uitest`'s own:

```bash
mise exec -- xcodegen generate
xcodebuild test -project ClaudeUsageBar.xcodeproj -scheme ClaudeUsageBar -destination 'platform=macOS' \
  -derivedDataPath build/dev-derived-data -resultBundlePath build/Probe.xcresult \
  -only-testing:ClaudeUsageBarLaunchUITests/ScratchProbeTests
xcrun xcresulttool export attachments --path build/Probe.xcresult --output-path /tmp/att
```

The export writes each attachment under a UUID file name plus a `manifest.json` that
maps it back to `suggestedHumanReadableName` ("menu-open_0_….png") and the
test it came from — read the manifest, then look at the PNG. `just uitest` runs the whole
scheme (the launch guarantee included) and writes `build/LaunchUITests.xcresult`; use it
when you want both, `-only-testing:` while iterating.

Two rules about the probe:

- **It is deleted before the pull request**, along with a re-run of `just generate`.
  `LaunchUITests/` holds the launch guarantee and nothing else; a behavior worth keeping
  is a `ClaudeUsageBarCore` test against a fake, not a UI test (`.claude/rules/testing.md` ›
  Where a Test Goes). An XCUITest is slow, needs a GUI session, and asserts through the
  accessibility layer — everything a decision test should not be.
- **The first local XCUITest run may prompt for Accessibility** for whatever launched
  `xcodebuild`, exactly as the `just uitest` recipe warns. Same single up-front ask.

## Start the app in a known state

Nothing in this app reads a launch argument or an environment variable today:
`UsageMenuViewModel` starts from an empty `UsageState`, and no `App/` or
`ClaudeUsageBarCore` code consults `UserDefaults` or `ProcessInfo`. The snippet below
passes `-probeState` and `PROBE_STATE` to prove the plumbing, not because the app answers
them. **Do not add such a hook to the app just to observe it** — a state you only need to
*look at* is a state a preview or a Core test can construct directly, by building a
`UsageState`, exactly as `UsageMenu.swift`'s `#Preview("Stale numbers after a failure")`
and `#Preview("Not signed in")` do.

When a hook is genuinely warranted — a state that is expensive or impossible to reach by
hand, wanted from both a UI probe and by hand — this is the mechanism, verified against a
running build:

```bash
open --env PROBE_STATE=known-state -n \
  build/dev-derived-data/Build/Products/Debug/ClaudeUsageBar.app --args -probeState known-state
ps -o command= -p "$(pgrep -f 'Debug/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar' | head -1)"
```

- `--args` puts everything after it in the process's `argv`, which is also what fills
  `UserDefaults`' argument domain: a `-key value` pair there is what `UserDefaults
  .standard.string(forKey: "key")` reads, ahead of any stored value, for that launch
  only. `--env KEY=value` adds an environment variable, which `ProcessInfo` reads.
  `XCUIApplication.launchArguments` and `.launchEnvironment` are the same two channels
  from a UI test.
- `-n` opens a *new* instance even though one is running, which is how you end up
  watching two builds at once. Quit the verified pid first (`kill -TERM "$pid"`) unless you meant it.
- The hook itself belongs in `ClaudeUsageBarCore`, behind one value a view model reads, so the
  same state stays reachable from a Core test. `App/` — the composition root — is where
  the argument is read and turned into that value, and Core never learns where it came
  from.
