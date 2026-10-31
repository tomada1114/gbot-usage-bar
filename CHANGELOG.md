# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)
- A menu-bar agent that shows the Claude Code weekly usage limit as a rounded
  percentage inside a template-tinted outline of Clawd, Claude Code's mascot (`--`
  until the first refresh)
- A menu with the weekly and five-hour usage, their local reset times, the time of the
  last update, a line naming why the last refresh failed, and Quit (⌘Q)
- Refresh at launch and every minute, reading Claude Code's OAuth token from the
  login keychain with `/usr/bin/security` and querying Anthropic's undocumented OAuth
  usage endpoint
- A "Show in Menu Bar" choice in the menu that switches the badge between the weekly
  and the five-hour usage, starting on weekly at every launch

### Removed

- The template's example counter screen and frontmost-application example

[Unreleased]: https://github.com/tomada1114/claude-usage-bar/commits/main
