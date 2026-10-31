/// A port: "quit this app."
///
/// A menu-bar agent has no app menu and no ⌘Q of its own, so the menu's Quit item is
/// the way out, and quitting is AppKit (`NSApplication.terminate(_:)`), which Core may
/// not import. `ClaudeUsageBarPlatform`'s `NSApplicationTerminator` answers it; tests
/// substitute `FakeApplicationTerminator`, which counts instead of quitting.
///
/// Unlike this app's other ports it has no contract suite and no local-machine test: its
/// one promise is that the process ends, which no test can observe from inside the
/// process it ends. The running app is where it is checked (`running-the-app`).
public protocol ApplicationTerminating: Sendable {
    /// Asks the app to quit. Main-actor bound, as AppKit's application object is.
    @MainActor
    func terminate()
}
