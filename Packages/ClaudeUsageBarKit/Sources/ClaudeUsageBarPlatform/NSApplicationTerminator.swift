import AppKit
import ClaudeUsageBarCore

/// The AppKit adapter for ``ClaudeUsageBarCore/ApplicationTerminating``: the menu's Quit
/// item ends up here, because a menu-bar agent has no app menu and no ⌘Q of its own.
public struct NSApplicationTerminator: ApplicationTerminating {
    public init() {
        // Stateless: NSApplication.shared is the whole dependency.
    }

    public func terminate() {
        NSApplication.shared.terminate(nil)
    }
}
